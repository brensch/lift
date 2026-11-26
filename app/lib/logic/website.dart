/// Pages on the website of the server this build signs in to.
library;

import 'package:flutter/foundation.dart';

/// The server this build talks to (as main.dart reads it).
const _serverHost = String.fromEnvironment('SERVER_HOST');

/// [path] on the website of the server this build signs in to, so a
/// passkey made or used there is that server's. A build on a local backend
/// has no website of its own; it uses dev.schlift.com's.
Uri websiteUri(String path) => Uri.https(switch (_serverHost) {
  '' => kReleaseMode ? 'schlift.com' : 'dev.schlift.com',
  'localhost' || '127.0.0.1' || '10.0.2.2' => 'dev.schlift.com',
  final host => host,
}, path);
