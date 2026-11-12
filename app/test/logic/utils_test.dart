import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import 'package:passkeys/exceptions.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/logic/utils.dart';
import 'package:schlift/providers/auth_provider.dart' show formatAuthError;

void main() {
  test('formatPasskeyError includes native passkey code', () {
    final message = formatPasskeyError(
      DomainNotAssociatedException(
        'The app is not associated with the requested domain.',
      ),
    );

    expect(message, contains('Passkey error (domain-not-associated)'));
    expect(message, contains('not associated'));
  });

  test('a refused sign-in is said in the app\'s words where it knows why', () {
    final e = copy.passkeyErrors;
    // The passkey is no account's; the passkey manager didn't verify.
    expect(
      formatAuthError(const GrpcError.notFound('server words')),
      e.unknown,
    );
    expect(
      formatAuthError(const GrpcError.failedPrecondition('server words')),
      e.notVerified,
    );
    // The passkey manager already holds one of the account's passkeys.
    expect(
      formatAuthError(ExcludeCredentialsCanNotBeRegisteredException()),
      e.alreadyHeld,
    );
    // A replacement passkey nobody has approved yet.
    expect(
      formatAuthError(
        const GrpcError.custom(
          StatusCode.permissionDenied,
          'server words',
          null,
          null,
          {'x-recovery-request': 'r1'},
        ),
      ),
      e.notApproved,
    );
    // A refusal of that kind for any other reason keeps the server's words.
    expect(
      formatAuthError(const GrpcError.permissionDenied('not for you')),
      contains('not for you'),
    );
    // Anything else is the server's own sentence.
    expect(
      formatAuthError(const GrpcError.unauthenticated('Try again.')),
      contains('Try again.'),
    );
  });

  group('calendarDaysBetween', () {
    test('counts dates, not elapsed time', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1, 23, 59), DateTime(2026, 3, 2)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 2, 8), DateTime(2026, 3, 2, 20)),
        0,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 9), DateTime(2026, 3, 2)),
        -7,
      );
    });
    // Across a daylight-saving change: dst_test.dart.
  });

  test('shortMonth and monthYear', () {
    expect(shortMonth(DateTime(2026, 9, 3)), 'Sep');
    expect(monthYear(DateTime(2026, 9, 3)), 'September 2026');
  });
}
