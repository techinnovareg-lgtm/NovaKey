import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/core/security/email_pin_service.dart';
import 'package:client/core/security/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas de Seguridad 2FA: EmailPinService (Verificación de PIN al Correo)', () {
    late SecureStorageService storage;
    late EmailPinService pinService;
    const testEmail = 'seguridad.otp@novakey.security';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = SecureStorageService();
      pinService = EmailPinService(secureStorage: storage);
    });

    test('Envío de PIN genera código de 6 dígitos con propósito específico', () async {
      final pin = await pinService.sendSecurityPin(
        email: testEmail,
        purpose: PinVerificationPurpose.registration,
      );

      expect(pin, isNotNull);
      expect(pin!.length, equals(6));
      expect(int.tryParse(pin), isNotNull);
    });

    test('Validación de PIN correcto autoriza el dispositivo con éxito', () async {
      final pin = await pinService.sendSecurityPin(
        email: testEmail,
        purpose: PinVerificationPurpose.newDevice,
      );

      // Antes de verificar, el dispositivo no está autorizado
      expect(await pinService.isDeviceAuthorized(testEmail), isFalse);

      // Verificación exitosa
      final result = await pinService.verifyPin(
        email: testEmail,
        enteredPin: pin!,
      );

      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);

      // Ahora el dispositivo queda autorizado
      expect(await pinService.isDeviceAuthorized(testEmail), isTrue);
    });

    test('Validación de PIN incorrecto o de longitud errónea falla adecuadamente', () async {
      await pinService.sendSecurityPin(
        email: testEmail,
        purpose: PinVerificationPurpose.changePassword,
      );

      // Longitud inválida
      final badLength = await pinService.verifyPin(
        email: testEmail,
        enteredPin: '123',
      );
      expect(badLength.success, isFalse);
      expect(badLength.errorMessage, contains('6 u 8 dígitos'));

      // Número incorrecto
      final badNumber = await pinService.verifyPin(
        email: testEmail,
        enteredPin: '000000',
      );
      expect(badNumber.success, isFalse);
      expect(badNumber.errorMessage, contains('incorrecto'));
    });

    test('Prevención de ataques de repetición (Replay Attack): el PIN expira tras un uso exitoso', () async {
      final pin = await pinService.sendSecurityPin(
        email: testEmail,
        purpose: PinVerificationPurpose.forgotPassword,
      );

      // Primer uso exitoso
      final firstAttempt = await pinService.verifyPin(
        email: testEmail,
        enteredPin: pin!,
      );
      expect(firstAttempt.success, isTrue);

      // Segundo intento con el mismo código debe fallar por seguridad
      final secondAttempt = await pinService.verifyPin(
        email: testEmail,
        enteredPin: pin,
      );
      expect(secondAttempt.success, isFalse);
      expect(secondAttempt.errorMessage, contains('expirado'));
    });
  });
}
