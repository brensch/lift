import 'package:grpc/grpc.dart';
import 'dart:async';
import '../gen/workout/v1/workout.pbgrpc.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import '../gen/workout/v1/auth.pbgrpc.dart';
import '../gen/workout/v1/settings.pbgrpc.dart';
import 'app_logger.dart';

class AuthInterceptor extends ClientInterceptor {
  String? _token;

  void setToken(String? token) => _token = token;

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final metadata = Map<String, String>.from(options.metadata);
    if (_token != null) {
      metadata['x-session-token'] = _token!;
    }
    return invoker(
      method,
      request,
      options.mergedWith(CallOptions(metadata: metadata)),
    );
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    final metadata = Map<String, String>.from(options.metadata);
    if (_token != null) {
      metadata['x-session-token'] = _token!;
    }
    return invoker(
      method,
      requests,
      options.mergedWith(CallOptions(metadata: metadata)),
    );
  }
}

/// Logs every unary gRPC call with timing and error info.
class LoggingInterceptor extends ClientInterceptor {
  static const _tag = 'gRPC';
  // High-frequency polling calls — log at debug to avoid noise.
  static const _debugOnlyMethods = {
    '/workout.v1.MultiplayerService/GetCurrentSession',
  };

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final methodName = method.path;
    final shortName = methodName.split('/').last;
    final isDebugOnly = _debugOnlyMethods.contains(methodName);
    final stopwatch = Stopwatch()..start();

    if (!isDebugOnly) {
      AppLogger.instance.info(_tag, shortName, {'phase': 'start'});
    }

    final response = invoker(method, request, options);

    // Attach completion logging.
    unawaited(response.then((_) {
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      if (isDebugOnly) {
        AppLogger.instance.debug(_tag, shortName, {'ms': ms});
      } else {
        AppLogger.instance.info(_tag, shortName, {'phase': 'done', 'ms': ms});
      }
    }).catchError((Object e) {
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      final errorMsg = e is GrpcError
          ? '${e.codeName}: ${e.message}'
          : e.toString();
      AppLogger.instance.error(_tag, shortName, {
        'ms': ms,
        'error': errorMsg,
      });
    }));

    return response;
  }
}

class GrpcClient {
  final String host;
  final int port;
  late final AuthInterceptor authInterceptor;
  late final LoggingInterceptor _loggingInterceptor;
  late ClientChannel channel;
  late WorkoutServiceClient workoutService;
  late UserServiceClient userService;
  late MultiplayerServiceClient multiplayerService;
  late AuthServiceClient authService;
  late SettingsServiceClient settingsService;

  GrpcClient({required this.host, required this.port}) {
    authInterceptor = AuthInterceptor();
    _loggingInterceptor = LoggingInterceptor();
    _buildChannel();
  }

  List<ClientInterceptor> get _interceptors =>
      [authInterceptor, _loggingInterceptor];

  void _buildChannel() {
    // Use secure credentials for production (port 443)
    final credentials = port == 443
        ? const ChannelCredentials.secure()
        : const ChannelCredentials.insecure();

    channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: credentials,
        idleTimeout: const Duration(minutes: 1),
        connectionTimeout: const Duration(minutes: 10),
        connectTimeout: const Duration(seconds: 10),
        keepAlive: const ClientKeepAliveOptions(
          pingInterval: Duration(seconds: 30),
          timeout: Duration(seconds: 10),
          permitWithoutCalls: true,
        ),
      ),
    );
    workoutService = WorkoutServiceClient(
      channel,
      interceptors: _interceptors,
    );
    userService = UserServiceClient(channel, interceptors: _interceptors);
    multiplayerService = MultiplayerServiceClient(
      channel,
      interceptors: _interceptors,
    );
    authService = AuthServiceClient(channel, interceptors: _interceptors);
    settingsService = SettingsServiceClient(
      channel,
      interceptors: _interceptors,
    );
  }

  /// Tear down the current channel and create a fresh one.
  /// Call this on app resume to recover from stale HTTP/2 connections.
  /// Builds the new channel synchronously first, then shuts down the old one
  /// in the background so that callers immediately get a working channel.
  void resetChannel() {
    AppLogger.instance.info('gRPC', 'resetChannel', {'host': host});
    final oldChannel = channel;
    _buildChannel();
    // Shut down the old channel in the background. Any in-flight calls on it
    // will fail, but new calls already go through the fresh channel.
    unawaited(oldChannel.shutdown().catchError((_) {}));
  }

  void setToken(String? token) {
    authInterceptor.setToken(token);
  }

  Future<void> shutdown() async {
    await channel.shutdown();
  }
}
