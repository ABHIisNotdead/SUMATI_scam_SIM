class AppConfig {
  /// Base API URL configurable at compile time:
  /// flutter run --dart-define=API_URL=https://api.sumati.org
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://sumati-scam-sim.onrender.com',
  );

  /// WebSocket base URL derived dynamically from apiBaseUrl
  static String get wsBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$wsScheme://$host$portPart';
  }
}

