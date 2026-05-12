import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL']?.trim().replaceFirst(RegExp(r'/$'), '') ??
        'http://10.0.2.2:3000';
  }

  static String get apiSocketUrl {
    final explicit = dotenv.env['API_SOCKET_URL']?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.replaceFirst(RegExp(r'/$'), '');
    }

    final uri = Uri.parse(apiBaseUrl);
    final socketPort = int.tryParse(dotenv.env['SOCKET_PORT'] ?? '');
    return uri
        .replace(port: socketPort ?? (uri.hasPort ? uri.port : 4001))
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }
}
