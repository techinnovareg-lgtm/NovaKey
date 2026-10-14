import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/vault/utils/txt_credentials_parser.dart';

void main() {
  group('TxtCredentialsParser Tests', () {
    test('Parses exact user example format with inherited titles and multiple spaces', () {
      const input = '''
Gmail         car123@gmail.com / password123
Hotmail     hafgt1122@hotmail.com  / passwordhot123
                  kjkjk23@hotmail.com / password5566
''';

      final results = TxtCredentialsParser.parse(input);

      expect(results.length, equals(3));

      // Primer elemento: Gmail
      expect(results[0].title, equals('Gmail'));
      expect(results[0].username, equals('car123@gmail.com'));
      expect(results[0].password, equals('password123'));
      expect(results[0].websiteUrl, equals('https://mail.google.com'));

      // Segundo elemento: Hotmail
      expect(results[1].title, equals('Hotmail'));
      expect(results[1].username, equals('hafgt1122@hotmail.com'));
      expect(results[1].password, equals('passwordhot123'));
      expect(results[1].websiteUrl, equals('https://outlook.live.com'));

      // Tercer elemento: Línea identada sin título -> Hereda 'Hotmail'
      expect(results[2].title, equals('Hotmail'));
      expect(results[2].username, equals('kjkjk23@hotmail.com'));
      expect(results[2].password, equals('password5566'));
      expect(results[2].websiteUrl, equals('https://outlook.live.com'));
    });

    test('Parses lines without title deducing from domain', () {
      const input = 'soporte@github.com / mySecureToken123!';
      final results = TxtCredentialsParser.parse(input);

      expect(results.length, equals(1));
      expect(results[0].title, equals('GitHub'));
      expect(results[0].username, equals('soporte@github.com'));
      expect(results[0].password, equals('mySecureToken123!'));
      expect(results[0].websiteUrl, equals('https://github.com'));
    });
  });
}
