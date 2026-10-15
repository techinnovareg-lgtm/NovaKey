import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/security/auto_lock_wrapper.dart';

void main() {
  testWidgets('AutoLockWrapper triggers onTimeout after inactivity period', (tester) async {
    bool didTimeout = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AutoLockWrapper(
          timeout: const Duration(seconds: 2),
          onTimeout: () {
            didTimeout = true;
          },
          child: const Scaffold(
            body: Text('Contenido Protegido'),
          ),
        ),
      ),
    );

    expect(find.text('Contenido Protegido'), findsOneWidget);
    expect(didTimeout, isFalse);

    // Avanzar 1 segundo: no debe bloquearse aún
    await tester.pump(const Duration(seconds: 1));
    expect(didTimeout, isFalse);

    // Avanzar más allá del timeout (2 segundos totales)
    await tester.pump(const Duration(seconds: 2));
    expect(didTimeout, isTrue);
  });

  testWidgets('User pointer interaction resets the inactivity timer', (tester) async {
    bool didTimeout = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AutoLockWrapper(
          timeout: const Duration(seconds: 3),
          onTimeout: () {
            didTimeout = true;
          },
          child: const Scaffold(
            body: Center(child: Text('Zona Interactiva')),
          ),
        ),
      ),
    );

    // Avanzar 2 segundos (cerca de vencer)
    await tester.pump(const Duration(seconds: 2));
    expect(didTimeout, isFalse);

    // Simular interacción de usuario
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.up();
    await tester.pump();

    // Avanzar 2 segundos más (en total 4s desde el inicio, pero solo 2s desde la interacción)
    await tester.pump(const Duration(seconds: 2));
    expect(didTimeout, isFalse);

    // Avanzar hasta completar los 3s después de la interacción
    await tester.pump(const Duration(seconds: 2));
    expect(didTimeout, isTrue);
  });
}
