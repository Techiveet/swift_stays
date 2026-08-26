/// App-wide configuration for the Swift Stays host app.
class Environment {
  static const String appName = 'Swift Stays';
  static const String version = '1.1.1';

  /// Backend base host. Override at build time with:
  ///   flutter run --dart-define=RIDE_API_URL=https://your-host
  static const String domainUrl = String.fromEnvironment(
    'RIDE_API_URL',
    defaultValue: 'https://swift.techiveet.com',
  );

  /// Shared dev token the API expects on every request (parity with the
  /// rider/driver apps; harmless if the backend does not enforce it).
  static const String devToken =
      r'$2y$12$mEVBW3QASB5HMBv8igls3ejh6zw2A0Xb480HWAmYq6BY9xEifyBjG';

  /// How often the orders list re-polls as a fallback to the live socket.
  static const Duration pollInterval = Duration(seconds: 12);
}
