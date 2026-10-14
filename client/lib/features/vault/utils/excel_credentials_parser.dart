import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'txt_credentials_parser.dart';

/// Analizador inteligente de hojas de cálculo Excel (.xlsx) con credenciales
class ExcelCredentialsParser {
  /// Parsea los bytes de un archivo Excel y retorna la lista de credenciales identificadas
  static List<ParsedCredential> parseBytes(Uint8List bytes) {
    final List<ParsedCredential> results = [];
    final excel = Excel.decodeBytes(bytes);

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;

      int headerRowIndex = -1;
      int titleCol = -1;
      int userCol = -1;
      int passCol = -1;
      int urlCol = -1;
      int notesCol = -1;

      // 1. Escanear las primeras 5 filas para detectar cabeceras
      for (int r = 0; r < sheet.rows.length && r < 5; r++) {
        final row = sheet.rows[r];
        for (int c = 0; c < row.length; c++) {
          final cellText = _cellToString(row[c]?.value).toLowerCase().trim();
          if (cellText.isEmpty) continue;

          if (_isTitleHeader(cellText) && titleCol == -1) {
            titleCol = c;
          } else if (_isUserHeader(cellText) && userCol == -1) {
            userCol = c;
          } else if (_isPassHeader(cellText) && passCol == -1) {
            passCol = c;
          } else if (_isUrlHeader(cellText) && urlCol == -1) {
            urlCol = c;
          } else if (_isNotesHeader(cellText) && notesCol == -1) {
            notesCol = c;
          }
        }

        // Si encontramos al menos usuario y contraseña o título y contraseña en esta fila
        if ((userCol != -1 && passCol != -1) || (titleCol != -1 && passCol != -1)) {
          headerRowIndex = r;
          break;
        }
      }

      final startRow = headerRowIndex >= 0 ? headerRowIndex + 1 : 0;
      String lastInheritedTitle = '';

      // 2. Procesar filas de datos
      for (int r = startRow; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        String title = '';
        String username = '';
        String password = '';
        String url = '';
        String notes = '';

        if (headerRowIndex >= 0) {
          // Si hubo cabecera identificada
          if (titleCol >= 0 && titleCol < row.length) {
            title = _cellToString(row[titleCol]?.value).trim();
          }
          if (userCol >= 0 && userCol < row.length) {
            username = _cellToString(row[userCol]?.value).trim();
          }
          if (passCol >= 0 && passCol < row.length) {
            password = _cellToString(row[passCol]?.value).trim();
          }
          if (urlCol >= 0 && urlCol < row.length) {
            url = _cellToString(row[urlCol]?.value).trim();
          }
          if (notesCol >= 0 && notesCol < row.length) {
            notes = _cellToString(row[notesCol]?.value).trim();
          }
        } else {
          // Detección posicional automática cuando no hay cabeceras
          final nonNullValues = row
              .map((c) => _cellToString(c?.value).trim())
              .where((s) => s.isNotEmpty)
              .toList();

          if (nonNullValues.length >= 3) {
            title = nonNullValues[0];
            username = nonNullValues[1];
            password = nonNullValues[2];
            if (nonNullValues.length >= 4) url = nonNullValues[3];
          } else if (nonNullValues.length == 2) {
            username = nonNullValues[0];
            password = nonNullValues[1];
          }
        }

        // Si el título está vacío, heredar del anterior o deducir del email
        if (title.isEmpty) {
          if (lastInheritedTitle.isNotEmpty) {
            title = lastInheritedTitle;
          } else if (username.contains('@')) {
            final domain = username.split('@').last.toLowerCase().split('.').first;
            title = domain.isNotEmpty
                ? '${domain[0].toUpperCase()}${domain.substring(1)}'
                : 'Cuenta Excel';
          } else {
            title = 'Cuenta Excel';
          }
        } else {
          lastInheritedTitle = title;
        }

        // Si la fila tiene al menos usuario y contraseña válidos
        if (username.isNotEmpty && password.isNotEmpty) {
          results.add(
            ParsedCredential(
              title: title,
              username: username,
              password: password,
              websiteUrl: url,
              notes: notes.isNotEmpty ? notes : 'Importado desde Excel ($table)',
            ),
          );
        }
      }
    }

    return results;
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is DateCellValue) return value.asDateTimeLocal().toIso8601String();
    if (value is DateTimeCellValue) return value.asDateTimeLocal().toIso8601String();
    if (value is BoolCellValue) return value.value.toString();
    return value.toString();
  }

  static bool _isTitleHeader(String text) {
    return text.contains('servicio') ||
        text.contains('sitio') ||
        text.contains('plataforma') ||
        text.contains('title') ||
        text.contains('service') ||
        text.contains('aplicacion') ||
        text.contains('app') ||
        text.contains('sistema');
  }

  static bool _isUserHeader(String text) {
    return text.contains('usuario') ||
        text.contains('user') ||
        text.contains('correo') ||
        text.contains('email') ||
        text.contains('mail') ||
        text.contains('login') ||
        text.contains('cuenta');
  }

  static bool _isPassHeader(String text) {
    return text.contains('contrase') ||
        text.contains('password') ||
        text.contains('pass') ||
        text.contains('clave') ||
        text.contains('pwd') ||
        text.contains('pin');
  }

  static bool _isUrlHeader(String text) {
    return text.contains('url') ||
        text.contains('link') ||
        text.contains('web') ||
        text.contains('enlace') ||
        text.contains('direccion');
  }

  static bool _isNotesHeader(String text) {
    return text.contains('nota') ||
        text.contains('comentario') ||
        text.contains('obs') ||
        text.contains('detalle') ||
        text.contains('descrip');
  }
}
