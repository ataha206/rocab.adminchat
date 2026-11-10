// ============================================================================
//  TLS trust store — bundled Mozilla CA roots, same approach as the driver app.
//
//  Devices and emulators with stale system trust stores fail the handshake to
//  our API hosts with CERTIFICATE_VERIFY_FAILED ("unable to get local issuer
//  certificate") even though the network is fine. Shipping the full root bundle
//  and installing it on every dart:io HttpClient (which package:http uses)
//  makes the app independent of the device store and of the server's CA.
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _trustedRootsAsset = 'assets/certs/trusted_roots.pem';

/// Shared security context with the bundled roots; null until [initTlsTrustStore]
/// succeeds, in which case clients fall back to system trust.
SecurityContext? appTlsContext;

/// Loads the bundled roots. Safe to call more than once; failures are logged only.
Future<void> initTlsTrustStore() async {
  try {
    final pem = await rootBundle.load(_trustedRootsAsset);
    appTlsContext = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(pem.buffer.asUint8List());
  } catch (e) {
    if (kDebugMode) debugPrint('Bundled CA roots not installed: $e');
  }
}

/// Installs [appTlsContext] on every HttpClient the app creates (package:http
/// included). Set once in main(): `HttpOverrides.global = AppHttpOverrides();`
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context ?? appTlsContext);
}
