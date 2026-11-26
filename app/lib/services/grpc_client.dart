import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:grpc/grpc.dart';
import '../gen/workout/v1/account.pbgrpc.dart';
import '../gen/workout/v1/workout.pbgrpc.dart'
    show UserServiceClient, WorkoutServiceClient;
import '../gen/workout/v1/group.pbgrpc.dart';
import '../gen/workout/v1/auth.pbgrpc.dart';
import '../gen/workout/v1/analytics.pbgrpc.dart';
import '../gen/workout/v1/assistant.pbgrpc.dart';
import 'app_logger.dart';

class AuthInterceptor extends ClientInterceptor {
  String? _token;

  /// The running app's version, sent on every call as `x-app-version`. The
  /// server's MIN_APP_VERSION gate reads it and rejects apps that predate a
  /// breaking change with FAILED_PRECONDITION "app_update_required".
  static String appVersion = '';

  void setToken(String? token) => _token = token;

  Map<String, String> _decorated(Map<String, String> base) {
    final metadata = Map<String, String>.from(base);
    if (_token != null) {
      metadata['x-session-token'] = _token!;
    }
    if (appVersion.isNotEmpty) {
      metadata['x-app-version'] = appVersion;
    }
    // An analytics label only (page views, sign-in attempts by platform).
    metadata['x-platform'] = kIsWeb
        ? 'web'
        : defaultTargetPlatform.name.toLowerCase();
    return metadata;
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    return invoker(
      method,
      request,
      options.mergedWith(CallOptions(metadata: _decorated(options.metadata))),
    );
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    return invoker(
      method,
      requests,
      options.mergedWith(CallOptions(metadata: _decorated(options.metadata))),
    );
  }
}

/// An error as the user reads it: a server error's own message.
String cleanErrorMessage(Object error) {
  if (error is GrpcError) return error.message ?? error.codeName;
  return error.toString().trim();
}

String formatGrpcError(Object error) {
  if (error is GrpcError) {
    return '${error.codeName}: ${error.message}';
  }
  return error.toString();
}

bool isTransientReadConnectionError(Object error) {
  if (error is GrpcError) {
    return error.code == StatusCode.deadlineExceeded ||
        error.code == StatusCode.unavailable;
  }
  return false;
}

/// grpc-dart reconnects when the transport is known to be broken, but a
/// per-RPC deadline can fire while the channel still believes the connection is
/// ready. For short idempotent reads, force a fresh channel and retry once.
Future<T> retryReadAfterReconnect<T>({
  required String operation,
  required Future<T> Function() rpc,
  required void Function() resetChannel,
}) async {
  try {
    return await rpc();
  } catch (error) {
    if (!isTransientReadConnectionError(error)) rethrow;
    AppLogger.instance.warn('gRPC', '$operation timed out, resetting channel', {
      'error': formatGrpcError(error),
    });
    resetChannel();
    return await rpc();
  }
}

/// Logs every unary gRPC call with timing and error info.
class LoggingInterceptor extends ClientInterceptor {
  static const _tag = 'gRPC';
  // Frequent calls — log at debug to avoid noise.
  static const _debugOnlyMethods = {
    '/workout.v1.AnalyticsService/RecordPageViews',
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
    unawaited(
      response
          .then((_) {
            stopwatch.stop();
            final ms = stopwatch.elapsedMilliseconds;
            if (isDebugOnly) {
              AppLogger.instance.debug(_tag, shortName, {'ms': ms});
            } else {
              AppLogger.instance.info(_tag, shortName, {
                'phase': 'done',
                'ms': ms,
              });
            }
          })
          .catchError((Object e) {
            stopwatch.stop();
            final ms = stopwatch.elapsedMilliseconds;
            final errorMsg = e is GrpcError
                ? '${e.codeName}: ${e.message}'
                : e.toString();
            AppLogger.instance.error(_tag, shortName, {
              'ms': ms,
              'error': errorMsg,
            });
          }),
    );

    return response;
  }
}

class GrpcClient {
  final String host;
  final int port;
  late final AuthInterceptor authInterceptor;
  late final LoggingInterceptor _loggingInterceptor;
  late ClientChannel channel;
  late SyncServiceClient syncService;
  late UserServiceClient userService;
  late WorkoutServiceClient workoutService;
  late MultiplayerServiceClient multiplayerService;
  late AuthServiceClient authService;
  late AnalyticsServiceClient analyticsService;
  late AssistantServiceClient assistantService;

  GrpcClient({required this.host, required this.port}) {
    authInterceptor = AuthInterceptor();
    _loggingInterceptor = LoggingInterceptor();
    _buildChannel();
  }

  List<ClientInterceptor> get _interceptors => [
    authInterceptor,
    _loggingInterceptor,
  ];

  void _buildChannel() {
    // TLS to a deployed server (its own listener, or 443 for an old build
    // pointed at Caddy); plain to a local backend.
    final credentials = const {443, 8443, 8444}.contains(port)
        ? const ChannelCredentials.secure()
        : const ChannelCredentials.insecure();

    channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: credentials,
        idleTimeout: const Duration(minutes: 5),
        // How long a connection takes new calls (not how long one may take
        // to connect: that's connectTimeout). One that still works is kept:
        // each new one is a handshake, and the old one lingers as long as
        // the Sync stream on it does. A closed one is replaced regardless.
        connectionTimeout: const Duration(days: 1),
        connectTimeout: const Duration(seconds: 10),
        // The Sync stream is open for a whole workout; pings keep NATs
        // from idling it out. Its heartbeat notices a dead link, so these
        // are sparse: every phone sends them, and the server answers each.
        keepAlive: const ClientKeepAliveOptions(
          pingInterval: Duration(seconds: 60),
          timeout: Duration(seconds: 20),
          permitWithoutCalls: true,
        ),
      ),
    );
    syncService = SyncServiceClient(channel, interceptors: _interceptors);
    userService = UserServiceClient(channel, interceptors: _interceptors);
    workoutService = WorkoutServiceClient(channel, interceptors: _interceptors);
    multiplayerService = MultiplayerServiceClient(
      channel,
      interceptors: _interceptors,
    );
    authService = AuthServiceClient(channel, interceptors: _interceptors);
    analyticsService = AnalyticsServiceClient(
      channel,
      interceptors: _interceptors,
    );
    assistantService = AssistantServiceClient(
      channel,
      interceptors: _interceptors,
    );
  }

  /// Tear down the current channel and create a fresh one: for a connection
  /// that stopped answering (a network that dropped it without a word).
  /// Builds the new channel synchronously first, so callers immediately get
  /// a working one. Calls in flight on the old one finish on it, unless it's
  /// known [dead], when they fail at once (`UNAVAILABLE`) rather than wait on
  /// a socket that will never answer.
  void resetChannel({bool dead = false}) {
    AppLogger.instance.info('gRPC', 'resetChannel', {
      'host': host,
      'dead': dead,
    });
    final oldChannel = channel;
    _buildChannel();
    unawaited(
      (dead ? oldChannel.terminate() : oldChannel.shutdown()).catchError(
        (_) {},
      ),
    );
  }

  void setToken(String? token) {
    authInterceptor.setToken(token);
  }

  Future<void> shutdown() async {
    await channel.shutdown();
  }
}
