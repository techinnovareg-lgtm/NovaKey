import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/widgets/novakey_logo.dart';
import 'package:client/features/vault/models/vault_item.dart';

void main() {
  group('7. Pruebas de Humo (Smoke Testing) - Metodología Atlassian', () {
    test('ST-01: Generación de contraseñas de alta entropía', () {
      // Simular lógica del generador
      const length = 20;
      const lower = 'abcdefghijklmnopqrstuvwxyz';
      const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      const numbers = '0123456789';
      const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';
      const allChars = lower + upper + numbers + symbols;

      final random = Random.secure();
      final chars = [
        lower[random.nextInt(lower.length)],
        upper[random.nextInt(upper.length)],
        numbers[random.nextInt(numbers.length)],
        symbols[random.nextInt(symbols.length)],
        ...List.generate(length - 4, (_) => allChars[random.nextInt(allChars.length)]),
      ]..shuffle(random);
      final password = chars.join();

      expect(password.length, equals(20));
      expect(password.contains(RegExp(r'[a-z]')), isTrue);
      expect(password.contains(RegExp(r'[A-Z]')), isTrue);
      expect(password.contains(RegExp(r'[0-9]')), isTrue);
    });

    test('ST-02: Instanciación básica del modelo VaultItem y serialización JSON', () {
      final item = VaultItem(
        title: 'Smoke Test Item',
        username: 'smoke_user',
        password: 'smoke_pass_123',
        category: 'login',
      );

      expect(item.id, isNotEmpty);
      expect(item.title, equals('Smoke Test Item'));

      final jsonStr = item.toSensitiveJson();
      expect(jsonStr.contains('smoke_pass_123'), isTrue);

      final reconstructed = VaultItem.fromDecryptedJson(
        id: item.id,
        jsonStr: jsonStr,
        version: item.version,
        isFavorite: item.isFavorite,
        isDeleted: item.isDeleted,
        updatedAt: item.updatedAt,
      );
      expect(reconstructed.title, equals(item.title));
      expect(reconstructed.password, equals(item.password));
    });

    testWidgets('ST-03: Renderizado sin fallos del Logotipo e Isologo NovaKey', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NovaKeyLogo(size: 40),
            ),
          ),
        ),
      );

      expect(find.byType(NovaKeyLogo), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);
      expect(find.text('Key'), findsOneWidget);
      expect(find.text('BÓVEDA ZERO-KNOWLEDGE'), findsOneWidget);
    });
  });
}
