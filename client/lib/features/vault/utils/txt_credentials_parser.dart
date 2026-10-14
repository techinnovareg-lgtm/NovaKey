import '../models/vault_item.dart';

/// Representación temporal de una credencial extraída para previsualización y edición
class ParsedCredential {
  String title;
  String username;
  String password;
  String websiteUrl;
  String notes;
  bool isSelected;

  ParsedCredential({
    required this.title,
    required this.username,
    required this.password,
    this.websiteUrl = '',
    this.notes = '',
    this.isSelected = true,
  });

  VaultItem toVaultItem() {
    return VaultItem(
      title: title.trim().isEmpty ? 'Cuenta Importada' : title.trim(),
      username: username.trim(),
      password: password,
      websiteUrl: websiteUrl.trim(),
      notes: notes.trim(),
      category: 'login',
    );
  }
}

/// Analizador inteligente de archivos .txt y texto plano de cuentas y contraseñas
class TxtCredentialsParser {
  /// Mapeo de dominios conocidos a nombres de servicio y URLs
  static final Map<String, Map<String, String>> _knownDomains = {
    'gmail.com': {'title': 'Gmail', 'url': 'https://mail.google.com'},
    'google.com': {'title': 'Google', 'url': 'https://accounts.google.com'},
    'hotmail.com': {'title': 'Hotmail', 'url': 'https://outlook.live.com'},
    'outlook.com': {'title': 'Outlook', 'url': 'https://outlook.live.com'},
    'live.com': {'title': 'Microsoft Live', 'url': 'https://login.live.com'},
    'yahoo.com': {'title': 'Yahoo', 'url': 'https://mail.yahoo.com'},
    'icloud.com': {'title': 'Apple iCloud', 'url': 'https://www.icloud.com'},
    'github.com': {'title': 'GitHub', 'url': 'https://github.com'},
    'facebook.com': {'title': 'Facebook', 'url': 'https://facebook.com'},
    'instagram.com': {'title': 'Instagram', 'url': 'https://instagram.com'},
    'twitter.com': {'title': 'X / Twitter', 'url': 'https://x.com'},
    'x.com': {'title': 'X / Twitter', 'url': 'https://x.com'},
    'linkedin.com': {'title': 'LinkedIn', 'url': 'https://linkedin.com'},
    'netflix.com': {'title': 'Netflix', 'url': 'https://netflix.com'},
    'spotify.com': {'title': 'Spotify', 'url': 'https://spotify.com'},
  };

  /// Expresión regular para detectar correos electrónicos
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// Parsea el contenido completo de un archivo .txt
  static List<ParsedCredential> parse(String content) {
    final List<ParsedCredential> results = [];
    final lines = content.split(RegExp(r'\r?\n'));

    String currentInheritedTitle = '';
    String currentInheritedUrl = '';

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      if (rawLine.trim().isEmpty) continue;

      // 1. Detección de identación o prefijo de título
      final isIndented = rawLine.startsWith(' ') || rawLine.startsWith('\t');
      final trimmedLine = rawLine.trim();

      // 2. Extraer usuario y contraseña buscando separadores comunes (/ , : , | , ;)
      final parsed = _parseLine(
        trimmedLine,
        isIndented: isIndented,
        fallbackTitle: currentInheritedTitle,
        fallbackUrl: currentInheritedUrl,
      );

      if (parsed != null) {
        if (parsed.title.isNotEmpty && !isIndented) {
          currentInheritedTitle = parsed.title;
          currentInheritedUrl = parsed.websiteUrl;
        }
        results.add(parsed);
      }
    }

    return results;
  }

  static ParsedCredential? _parseLine(
    String line, {
    required bool isIndented,
    required String fallbackTitle,
    required String fallbackUrl,
  }) {
    // Caso 1: Separador estándar " / " o "/" entre usuario y contraseña
    // Ej: "Gmail  car123@gmail.com / password123"
    // Ej: "kjkjk23@hotmail.com / password5566"
    String? title;
    String? username;
    String? password;
    String? url;

    // Buscar si existe un email en la línea
    final emailMatch = _emailRegex.firstMatch(line);

    if (emailMatch != null) {
      username = emailMatch.group(0)!;
      final emailStart = emailMatch.start;
      final emailEnd = emailMatch.end;

      // Texto previo al email (puede ser el título como "Gmail", "Hotmail")
      final preEmail = line.substring(0, emailStart).trim();
      // Texto posterior al email (contiene el separador y la contraseña)
      final postEmail = line.substring(emailEnd).trim();

      // Extraer contraseña de la parte posterior
      password = _extractPasswordFromPostSegment(postEmail);

      // Determinar título
      if (preEmail.isNotEmpty && !isIndented) {
        title = _cleanTitle(preEmail);
      } else if (isIndented && fallbackTitle.isNotEmpty) {
        title = fallbackTitle;
        url = fallbackUrl;
      } else {
        // Deducir del dominio del correo
        final domain = username.split('@').last.toLowerCase();
        if (_knownDomains.containsKey(domain)) {
          title = _knownDomains[domain]!['title'];
          url = _knownDomains[domain]!['url'];
        } else {
          // Capitalizar el nombre del dominio
          final baseName = domain.split('.').first;
          title = baseName.isNotEmpty
              ? '${baseName[0].toUpperCase()}${baseName.substring(1)}'
              : 'Cuenta Personal';
        }
      }

      // Si aún no tenemos URL pero conocemos el dominio
      if (url == null || url.isEmpty) {
        final domain = username.split('@').last.toLowerCase();
        if (_knownDomains.containsKey(domain)) {
          url = _knownDomains[domain]!['url'];
        }
      }
    } else {
      // Caso 2: No tiene formato de correo explícito, buscar separadores: " / ", ":", "|"
      final parts = line.split(RegExp(r'\s*/\s*|\s*\|\s*|:\s+'));
      if (parts.length >= 2) {
        final firstPart = parts[0].trim();
        password = parts[1].trim();

        // Si la primera parte contiene múltiples palabras, ej: "Banco Santander usuario123"
        final subTokens = firstPart.split(RegExp(r'\s+'));
        if (subTokens.length > 1 && !isIndented) {
          title = subTokens.sublist(0, subTokens.length - 1).join(' ');
          username = subTokens.last;
        } else {
          username = firstPart;
          title = isIndented && fallbackTitle.isNotEmpty ? fallbackTitle : 'Cuenta Importada';
        }
      }
    }

    if (username != null && password != null) {
      return ParsedCredential(
        title: title ?? (fallbackTitle.isNotEmpty ? fallbackTitle : 'Cuenta Importada'),
        username: username,
        password: password,
        websiteUrl: url ?? fallbackUrl,
        notes: 'Importado automáticamente desde archivo .txt',
      );
    }

    return null;
  }

  static String _extractPasswordFromPostSegment(String segment) {
    // Remover separadores iniciales: " / ", "/", ":", "|", "-"
    var clean = segment.replaceFirst(RegExp(r'^[\s/:|\-]+'), '').trim();
    // Si viene con notas o campos adicionales
    return clean;
  }

  static String _cleanTitle(String text) {
    // Quita dos puntos finales o separadores al final del título
    return text.replaceAll(RegExp(r'[:\-–—]+$'), '').trim();
  }
}
