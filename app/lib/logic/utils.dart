import 'package:flutter/services.dart';
import 'package:passkeys/exceptions.dart';

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

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Oct": a month, short.
String shortMonth(DateTime d) => _months[d.month - 1];

/// Whole calendar days from [a]'s date to [b]'s, ignoring the time of day.
/// Counted on UTC dates, so a daylight-saving change (a 23- or 25-hour
/// day) never makes it one short.
int calendarDaysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// "Oct 3": a day as the charts and plan reasons show it.
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// "Oct 3", or "Oct 3, 2024" outside this year.
String dayDate(DateTime d) =>
    d.year == DateTime.now().year ? shortDate(d) : '${shortDate(d)}, ${d.year}';

/// "October 2026": a month heading.
String monthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// A chart's date label: "Oct 3", or "Oct '25" on an axis spanning a year.
String axisDate(DateTime d, {required bool withYear}) => withYear
    ? "${_months[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}"
    : shortDate(d);

/// The spans a progress chart can show, longest first; null days is all
/// of it.
const chartWindows = <({String label, int? days})>[
  (label: 'All', days: null),
  (label: '1Y', days: 365),
  (label: '6M', days: 183),
  (label: '3M', days: 92),
  (label: '1M', days: 31),
];

/// The span a chart covers for `window` (an index into [chartWindows]):
/// that long before now, or for all time from `first`. Never under a day.
({DateTime from, DateTime to}) chartSpan(int window, DateTime? first) {
  final to = DateTime.now();
  final days = chartWindows[window].days;
  var from = days != null ? to.subtract(Duration(days: days)) : (first ?? to);
  if (to.difference(from) < const Duration(days: 1)) {
    from = to.subtract(const Duration(days: 1));
  }
  return (from: from, to: to);
}
