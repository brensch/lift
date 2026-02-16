import 'package:grpc/grpc.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import '../gen/workout/v1/auth.pbgrpc.dart';

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
}

class GrpcClient {
  late final ClientChannel channel;
  late final AuthInterceptor authInterceptor;
  late final WorkoutServiceClient workoutService;
  late final UserServiceClient userService;
  late final MultiplayerServiceClient multiplayerService;
  late final AuthServiceClient authService;

  GrpcClient({required String host, required int port}) {
    authInterceptor = AuthInterceptor();

    // Use secure credentials for production (port 443)
    final credentials = port == 443
        ? const ChannelCredentials.secure()
        : const ChannelCredentials.insecure();

    channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(credentials: credentials),
    );
    workoutService = WorkoutServiceClient(
      channel,
      interceptors: [authInterceptor],
    );
    userService = UserServiceClient(channel, interceptors: [authInterceptor]);
    multiplayerService = MultiplayerServiceClient(
      channel,
      interceptors: [authInterceptor],
    );
    authService = AuthServiceClient(channel, interceptors: [authInterceptor]);
  }

  void setToken(String? token) {
    authInterceptor.setToken(token);
  }

  Future<void> shutdown() async {
    await channel.shutdown();
  }
}
