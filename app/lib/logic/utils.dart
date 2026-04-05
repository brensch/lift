import 'package:grpc/grpc.dart';

String cleanErrorMessage(dynamic error) {
  final errorStr = error.toString();
  // Handles gRPC Errors like: gRPC Error (code: 9, codeName: FAILED_PRECONDITION, message: Error Message Here, ...)
  return errorStr
      .replaceAll(
        RegExp(r'gRPC Error \(code: \d+, codeName: [^,]+, message: '),
        '',
      )
      .replaceAll(RegExp(r'\)$'), '') // Remove trailing paren from gRPC Error
      .replaceAll(
        RegExp(r', details:.*$'),
        '',
      ) // Remove trailing details if any
      .trim();
}

bool isUnauthenticatedError(Object error) {
  return error is GrpcError && error.code == StatusCode.unauthenticated;
}
