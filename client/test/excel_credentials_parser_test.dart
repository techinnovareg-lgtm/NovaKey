import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/vault/utils/excel_credentials_parser.dart';

void main() {
  group('ExcelCredentialsParser Tests', () {
    test('Parses in-memory Excel workbook with headers', () {
      final excel = Excel.createExcel();
      final sheet = excel['Credenciales'];

      // Fila 1: Cabeceras
      sheet.appendRow([
        TextCellValue('Servicio'),
        TextCellValue('Correo / Usuario'),
        TextCellValue('Contraseña'),
        TextCellValue('Sitio Web'),
      ]);

      // Fila 2: Cuenta 1
      sheet.appendRow([
        TextCellValue('Google Workspace'),
        TextCellValue('admin@empresa.com'),
        TextCellValue('PassEmpresa2026!'),
        TextCellValue('https://workspace.google.com'),
      ]);

      // Fila 3: Cuenta 2
      sheet.appendRow([
        TextCellValue('AWS Console'),
        TextCellValue('devops@cloud.pe'),
        TextCellValue('AWS#DevOps_998'),
        TextCellValue('https://aws.amazon.com'),
      ]);

      final bytes = Uint8List.fromList(excel.encode()!);
      final parsed = ExcelCredentialsParser.parseBytes(bytes);

      expect(parsed.length, equals(2));

      expect(parsed[0].title, equals('Google Workspace'));
      expect(parsed[0].username, equals('admin@empresa.com'));
      expect(parsed[0].password, equals('PassEmpresa2026!'));
      expect(parsed[0].websiteUrl, equals('https://workspace.google.com'));

      expect(parsed[1].title, equals('AWS Console'));
      expect(parsed[1].username, equals('devops@cloud.pe'));
      expect(parsed[1].password, equals('AWS#DevOps_998'));
      expect(parsed[1].websiteUrl, equals('https://aws.amazon.com'));
    });
  });
}
