import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import 'package:passkeys/exceptions.dart';

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

String formatPlatformError(PlatformException error) {
  final message = error.message?.trim();
  if (message == null || message.isEmpty) {
    return 'Platform error ${error.code}';
  }
  return 'Platform error ${error.code}: $message';
}

String formatPasskeyError(AuthenticatorException error) {
  if (error is DomainNotAssociatedException) {
    return _passkeyError('domain-not-associated', error.message);
  }
  if (error is TimeoutException) {
    return _passkeyError('timeout', error.message);
  }
  if (error is UnhandledAuthenticatorException) {
    return _passkeyError(error.code, error.message, error.details);
  }
  if (error is PasskeyAuthCancelledException) {
    return _passkeyError('cancelled', 'Passkey operation cancelled.');
  }
  if (error is NoCredentialsAvailableException) {
    return _passkeyError('no-credentials-available', 'No passkey found.');
  }
  if (error is ExcludeCredentialsCanNotBeRegisteredException) {
    return _passkeyError(
      'exclude-credentials-match',
      'This passkey is already registered.',
    );
  }
  if (error is DeviceNotSupportedException) {
    return _passkeyError(
      'device-not-supported',
      'This device does not support passkeys.',
    );
  }
  if (error is MissingGoogleSignInException) {
    return _passkeyError(
      'android-missing-google-sign-in',
      'Sign in to Google first.',
    );
  }
  if (error is SyncAccountNotAvailableException) {
    return _passkeyError(
      'android-sync-account-not-available',
      'Passkey sync account unavailable.',
    );
  }
  if (error is NoCreateOptionException) {
    return _passkeyError('android-no-create-option', error.message);
  }
  if (error is MalformedBase64Url) {
    return _passkeyError('malformed-base64url', error.toString());
  }
  return _passkeyError(error.runtimeType.toString(), error.toString());
}

String _passkeyError(String code, String? message, [Object? details]) {
  final detailText = details == null ? '' : ' [$details]';
  final messageText = message == null || message.trim().isEmpty
      ? 'Passkey operation failed.'
      : message.trim();
  return 'Passkey error ($code): $messageText$detailText';
}
