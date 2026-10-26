import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/email_pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/recovery_kit_service.dart';
import '../../../core/widgets/novakey_logo.dart';
import '../../vault/widgets/tech_innova_credits.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/recovery_kit_dialog.dart';
import '../../subscription/services/subscription_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(SecretKey masterEncryptionKey, String email) onUnlockSuccess;

  const AuthScreen({super.key, required this.onUnlockSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _biometricService = BiometricService();
  final _secureStorage = SecureStorageService();
  final _pinService = EmailPinService();

  bool _isLogin = true;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _canUseBiometrics = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSavedEmail();
  }

  Future<void> _checkBiometrics() async {
    final supported = await _biometricService.isBiometricsSupported();
    final enabled = await _secureStorage.isBiometricsEnabled();
    final savedMek = await _secureStorage.getEncryptedMek();

    if (mounted) {
      setState(() {
        _canUseBiometrics = supported && enabled && savedMek != null;
      });
    }
  }

  Future<void> _loadSavedEmail() async {
    final email = await _secureStorage.getUserEmail();
    if (mounted) {
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      } else {
        _emailController.text = '';
      }
      setState(() {
        _isLogin = true; // Siempre iniciar en modo Iniciar Sesión por defecto
      });
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Desbloqueando bóveda con clave de hardware seguro...';
    });

    try {
      final savedMekBase64 = await _secureStorage.getEncryptedMek();
      if (savedMekBase64 == null) {
        throw Exception('No hay clave biométrica registrada.');
      }

      final email = await _secureStorage.getUserEmail() ?? '';
      final keyBytes = base64Decode(savedMekBase64);
      final secretKey = SecretKey(keyBytes);

      // Asegurar que la sesión de Supabase Auth esté activa para sincronización en la nube
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser == null && email.isNotEmpty) {
          final savedAuthPassword = await _secureStorage.getSavedAuthPassword(email);
          if (savedAuthPassword != null && savedAuthPassword.isNotEmpty) {
            await client.auth.signInWithPassword(
              email: email,
              password: savedAuthPassword,
            );
            debugPrint('✅ Sesión de Supabase reconectada en biometría para: $email');
          }
        }
      } catch (authErr) {
        debugPrint('Aviso al reconectar sesión en biometría: $authErr');
      }

      widget.onUnlockSuccess(secretKey, email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al desbloquear: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    String email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      final emailInputCtrl = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131722),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937)),
          ),
          title: const Row(
            children: [
              Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text('Recuperar Acceso', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el correo electrónico con el que registraste tu bóveda NovaKey:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailInputCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
              onPressed: () {
                final e = emailInputCtrl.text.trim().toLowerCase();
                if (e.isNotEmpty && e.contains('@')) {
                  Navigator.of(ctx).pop(e);
                }
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (entered == null || entered.isEmpty) return;
      email = entered;
      _emailController.text = entered;
    }

    // Ofrecer selección de método: Kit de Rescate de Emergencia (Autoservicio) vs Superadmin
    final selectedMethod = await showDialog<String>(
      context: context,
      builder: (choiceCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Recuperar Acceso a la Bóveda', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecciona el método de recuperación que deseas utilizar:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(choiceCtx).pop('kit'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, color: Color(0xFF38BDF8), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kit de Rescate de Emergencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white)),
                          SizedBox(height: 3),
                          Text('Autoservicio Cero-Conocimiento instantáneo usando tu Clave de Rescate.', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF38BDF8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(choiceCtx).pop('superadmin'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: Color(0xFFF59E0B), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Soporte y Superadmin Tech Innova', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white)),
                          SizedBox(height: 3),
                          Text('Validación de titularidad por WhatsApp con PIN al correo y teléfono.', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(choiceCtx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selectedMethod == null || !mounted) return;

    // MÉTODO 1: KIT DE RESCATE DE EMERGENCIA
    if (selectedMethod == 'kit') {
      final keyCtrl = TextEditingController();
      final enteredKey = await showDialog<String>(
        context: context,
        builder: (kCtx) => AlertDialog(
          backgroundColor: const Color(0xFF0F141C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2563EB)),
          ),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text('Ingresa tu Clave de Rescate', style: TextStyle(fontSize: 15, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa la clave de 24 caracteres de tu Kit de Emergencia (ej. NK-REC-XXXX-XXXX-...):',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
                decoration: const InputDecoration(
                  labelText: 'Clave de Rescate de Emergencia',
                  hintText: 'NK-REC-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                  prefixIcon: Icon(Icons.key_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(kCtx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
              onPressed: () {
                final k = keyCtrl.text.trim().toUpperCase();
                if (k.isNotEmpty) Navigator.of(kCtx).pop(k);
              },
              child: const Text('Verificar Clave'),
            ),
          ],
        ),
      );

      if (enteredKey == null || !mounted) return;

      setState(() {
        _isLoading = true;
        _statusMessage = 'Descifrando bóveda con Kit de Rescate Zero-Knowledge...';
      });

      try {
        final salt = await CryptoEngine.deriveDeterministicSalt(email);
        final recoveryPayload = await RecoveryKitService.getRecoveryPayload(email);

        SecretKey? recoveredMek;
        if (recoveryPayload != null) {
          recoveredMek = await RecoveryKitService.decryptMekFromRecovery(
            recoveryPayload: recoveryPayload,
            recoveryKey: enteredKey,
            salt: salt,
          );
        } else {
          if (RecoveryKitService.isValidKeyFormat(enteredKey)) {
            final derived = await CryptoEngine.deriveKeys(masterPassword: enteredKey, salt: salt);
            recoveredMek = derived.masterEncryptionKey;
          }
        }

        if (recoveredMek == null) {
          throw Exception('La Clave de Rescate ingresada no es válida o no coincide con esta cuenta.');
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        // Pedir nueva contraseña maestra
        final newPassController = TextEditingController();
        final confirmPassController = TextEditingController();

        final resetSuccess = await showDialog<bool>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            backgroundColor: const Color(0xFF131722),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F2937)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 10),
                Text('Clave de Rescate Válida', style: TextStyle(fontSize: 16, color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡Identidad criptográfica confirmada! Ingresa tu nueva contraseña maestra para proteger tu bóveda de aquí en adelante:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva Contraseña Maestra', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dlgCtx).pop(false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
                onPressed: () {
                  final compErr = validatePasswordComplexity(newPassController.text);
                  if (compErr != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(compErr), backgroundColor: Colors.red));
                    return;
                  }
                  if (newPassController.text != confirmPassController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
                    return;
                  }
                  Navigator.of(dlgCtx).pop(true);
                },
                child: const Text('Guardar y Entrar'),
              ),
            ],
          ),
        );

        if (resetSuccess == true && mounted) {
          setState(() {
            _isLoading = true;
            _statusMessage = 'Aplicando nueva clave y re-encriptando bóveda...';
          });

          final newSalt = await CryptoEngine.deriveDeterministicSalt(email);
          final newKeys = await CryptoEngine.deriveKeys(
            masterPassword: newPassController.text,
            salt: newSalt,
          );
          final newAuthPassword = 'NK_' + newKeys.authHashHex.substring(0, 32) + '!Aa1';

          await _secureStorage.saveUserSalt(email, base64Encode(newSalt));
          await _secureStorage.savePasswordVerifier(email, newKeys.authHashHex);
          await _secureStorage.saveUserEmail(email);

          final rawKeyBytes = await recoveredMek.extractBytes();
          await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
          await _pinService.authorizeCurrentDevice(email);

          // Actualizar payload de recuperación
          final updatedPayload = await RecoveryKitService.encryptMekForRecovery(
            masterEncryptionKey: recoveredMek,
            recoveryKey: enteredKey,
            salt: newSalt,
          );
          await RecoveryKitService.saveRecoveryData(
            email: email,
            payload: updatedPayload,
            recoveryKey: enteredKey,
          );

          try {
            final client = Supabase.instance.client;
            if (client.auth.currentUser != null) {
              await client.auth.updateUser(UserAttributes(password: newAuthPassword));
            }
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Bóveda recuperada y contraseña maestra reconfigurada con éxito.'),
                backgroundColor: Colors.green,
              ),
            );
          }

          widget.onUnlockSuccess(recoveredMek, email);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar Kit de Rescate: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // MÉTODO 2: PROTOCOLO CON SUPERADMIN
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generando y despachando código PIN a tu correo...';
    });

    try {
      final demoPin = await _pinService.sendSecurityPin(
        email: email,
        purpose: PinVerificationPurpose.forgotPassword,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Mostrar el diálogo con el protocolo oficial de comprobación de titularidad por Superadmin
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: const Color(0xFF0F141C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937)),
          ),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Protocolo de Seguridad: Olvido de Contraseña', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bajo el estándar Zero-Knowledge, tus contraseñas están cifradas y ni Tech Innova ni nadie puede conocerlas.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🛡️ Comprobación de Titularidad (Superadmin):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF38BDF8)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'El Superadmin tiene la posibilidad de resetear tu clave únicamente si comprueba fehacientemente que eres el dueño de esa cuenta.\n\nPara ello, deberás enviar al número de soporte oficial de Tech Innova (+51 947 515 529):',
                        style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text('1. Tu correo registrado: $email', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      const Text('2. Tu número de teléfono registrado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      const Text('3. El PIN de seguridad recibido en tu correo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '✅ Hemos despachado un PIN de 6 dígitos a tu bandeja de correo (expira en 5 minutos).',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF10B981), size: 16),
              label: const Text('Contactar Soporte WhatsApp', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final waMsg = 'Hola Tech Innova Soporte, solicito verificar mi titularidad para resetear mi contraseña de NovaKey.\nCorreo: $email\nTeléfono: [mi número]\nPIN recibido: [código de 6 dígitos]';
                final uri = Uri.parse('https://wa.me/51947515529?text=${Uri.encodeComponent(waMsg)}');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
              onPressed: () => Navigator.of(dlgCtx).pop(true),
              child: const Text('Ingresar PIN y Restablecer'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;

      final verified = await PinVerificationDialog.show(
        context: context,
        email: email,
        purpose: PinVerificationPurpose.forgotPassword,
        pinService: _pinService,
        initialDemoPin: demoPin,
      );

      if (!verified || !mounted) return;

      // Diálogo para ingresar la nueva contraseña maestra
      final newPassController = TextEditingController();
      final confirmPassController = TextEditingController();

      final resetSuccess = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            backgroundColor: const Color(0xFF131722),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F2937)),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF38BDF8)),
                SizedBox(width: 10),
                Text('Nueva Contraseña Maestra', style: TextStyle(fontSize: 16, color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'El PIN ha sido verificado con éxito. Ingresa tu nueva contraseña para reconfigurar el acceso a tu bóveda:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final compErr = validatePasswordComplexity(newPassController.text);
                  if (compErr != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(compErr), backgroundColor: const Color(0xFFDC2626)),
                    );
                    return;
                  }
                  if (newPassController.text != confirmPassController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Las contraseñas no coinciden')),
                    );
                    return;
                  }
                  Navigator.of(dlgCtx).pop(true);
                },
                child: const Text('Restablecer'),
              ),
            ],
          ),
        ),
      );

      if (resetSuccess == true && mounted) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Aplicando nueva clave y protegiendo bóveda...';
        });

        final newSalt = await CryptoEngine.deriveDeterministicSalt(email);
        final newKeys = await CryptoEngine.deriveKeys(
          masterPassword: newPassController.text,
          salt: newSalt,
        );
        final newAuthPassword = 'NK_' + newKeys.authHashHex.substring(0, 32) + '!Aa1';

        await _secureStorage.saveUserSalt(email, base64Encode(newSalt));
        await _secureStorage.savePasswordVerifier(email, newKeys.authHashHex);
        await _secureStorage.saveUserEmail(email);

        final rawKeyBytes = await newKeys.masterEncryptionKey.extractBytes();
        await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
        await _pinService.authorizeCurrentDevice(email);

        try {
          final client = Supabase.instance.client;
          if (client.auth.currentUser != null) {
            await client.auth.updateUser(UserAttributes(password: newAuthPassword));
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contraseña restablecida con éxito. Puedes ingresar ahora.'),
              backgroundColor: Colors.green,
            ),
          );
          _passwordController.text = newPassController.text;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String? validatePasswordComplexity(String password) {
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Debe incluir al menos una letra mayúscula (A-Z).';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Debe incluir al menos una letra minúscula (a-z).';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Debe incluir al menos un número (0-9).';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\\/\[\]~`]').hasMatch(password)) {
      return 'Debe incluir al menos un carácter especial (!@#\$%&*...).';
    }
    return null;
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Validación estricta de robustez en registro de nueva bóveda
    if (!_isLogin) {
      final validationError = validatePasswordComplexity(password);
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    validationError,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626), // Rojo seguridad
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Comprobando seguridad y autorización del dispositivo...';
    });

    try {
      // 1. Derivar la sal determinista garantizada para sincronización multi-dispositivo
      final deterministicSalt = await CryptoEngine.deriveDeterministicSalt(email);
      final deterministicSaltBase64 = base64Encode(deterministicSalt);
      final deterministicKeys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: deterministicSalt,
      );
      final deterministicAuthPassword = 'NK_' + deterministicKeys.authHashHex.substring(0, 32) + '!Aa1';

      // 2. Verificar sal y verifier locales existentes
      final savedSaltBase64 = await _secureStorage.getUserSalt(email);
      final savedVerifier = await _secureStorage.getPasswordVerifier(email);

      DerivedKeys activeKeys = deterministicKeys;
      String activeAuthPassword = deterministicAuthPassword;

      // 3. PASO CRÍTICO DE SEGURIDAD: VERIFICAR CONTRASEÑA ANTES DE ENVIAR PIN O CONCEDER ACCESO
      if (_isLogin) {
        if (savedVerifier != null) {
          // Caso A: Dispositivo conocido con verifier previo
          if (savedVerifier == deterministicKeys.authHashHex) {
            // Ya alineado con la sal determinista
            activeKeys = deterministicKeys;
            activeAuthPassword = deterministicAuthPassword;
          } else if (savedSaltBase64 != null && savedSaltBase64 != deterministicSaltBase64) {
            // Posible dispositivo con sal legacy previa generada aleatoriamente
            final legacySalt = base64Decode(savedSaltBase64);
            final legacyKeys = await CryptoEngine.deriveKeys(
              masterPassword: password,
              salt: legacySalt,
            );
            if (legacyKeys.authHashHex == savedVerifier) {
              // La contraseña ingresada es correcta bajo la sal legacy.
              // Migración transparente a sal determinista para habilitar sincronización total con otros dispositivos:
              debugPrint('🔄 Migrando bóveda local de sal legacy a sal determinista multi-dispositivo...');
              final legacyLocalVault = await _secureStorage.getLocalEncryptedVault(email);
              if (legacyLocalVault != null && legacyLocalVault.isNotEmpty) {
                try {
                  final List<dynamic> localList = jsonDecode(legacyLocalVault);
                  final List<Map<String, dynamic>> migratedList = [];
                  for (final dynamic rawRow in localList) {
                    try {
                      final Map<dynamic, dynamic> row = rawRow as Map<dynamic, dynamic>;
                      final dynamic rawEnc = row['encrypted'];
                      if (rawEnc == null) continue;
                      final payload = EncryptedPayload.fromMap(rawEnc as Map<dynamic, dynamic>);
                      final decryptedJson = await CryptoEngine.decrypt(
                        payload: payload,
                        key: legacyKeys.masterEncryptionKey,
                      );
                      // Re-encriptar con la nueva clave determinista
                      final newEncrypted = await CryptoEngine.encrypt(
                        plainText: decryptedJson,
                        key: deterministicKeys.masterEncryptionKey,
                      );
                      migratedList.add({
                        'id': row['id'],
                        'version': row['version'] ?? 1,
                        'is_favorite': row['is_favorite'] == true,
                        'is_deleted': row['is_deleted'] == true,
                        'updated_at': row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
                        'encrypted': newEncrypted.toMap(),
                      });
                    } catch (_) {}
                  }
                  if (migratedList.isNotEmpty) {
                    await _secureStorage.saveLocalEncryptedVault(email, jsonEncode(migratedList));
                  }
                } catch (migErr) {
                  debugPrint('Aviso en migración de bóveda local: $migErr');
                }
              }

              // Actualizar sal, verifier y MEK para biometría a la versión determinista
              await _secureStorage.saveUserSalt(email, deterministicSaltBase64);
              await _secureStorage.savePasswordVerifier(email, deterministicKeys.authHashHex);
              final newMekBytes = await deterministicKeys.masterEncryptionKey.extractBytes();
              await _secureStorage.saveEncryptedMek(base64Encode(newMekBytes));

              activeKeys = deterministicKeys;
              activeAuthPassword = deterministicAuthPassword;
            } else {
              throw Exception('Contraseña maestra incorrecta. Por favor verifica mayúsculas/minúsculas y caracteres.');
            }
          } else {
            throw Exception('Contraseña maestra incorrecta. Por favor verifica mayúsculas/minúsculas y caracteres.');
          }
        } else {
          // Caso B: Dispositivo nuevo / ventana incógnito / otro navegador (sin verifier local).
          final cleanEmail = email.trim().toLowerCase();
          final isKnownAccount = SubscriptionService.accounts.any(
            (a) => a.email.toLowerCase() == cleanEmail,
          );

          bool cloudPasswordVerified = false;
          try {
            final client = Supabase.instance.client;
            final authRes = await client.auth.signInWithPassword(
              email: cleanEmail,
              password: deterministicAuthPassword,
            );
            if (authRes.user != null) {
              cloudPasswordVerified = true;
            }
          } on AuthException catch (authErr) {
            debugPrint('Aviso en signInWithPassword en nuevo dispositivo: ${authErr.message} (código: ${authErr.code})');
          } catch (e) {
            debugPrint('Aviso general en autenticación previa con Supabase: $e');
          }

          // Si Supabase no pudo validar la contraseña directamente (ej: email no confirmado o clave no sincronizada en nube),
          // comprobar que la cuenta exista antes de despachar el PIN de seguridad.
          if (!cloudPasswordVerified) {
            bool accountExists = isKnownAccount;
            if (!accountExists) {
              try {
                final client = Supabase.instance.client;
                await client.auth.signInWithOtp(email: cleanEmail, shouldCreateUser: false);
                accountExists = true;
              } catch (otpErr) {
                if (otpErr is AuthException &&
                    (otpErr.statusCode == '422' ||
                     otpErr.message.toLowerCase().contains('signup') ||
                     otpErr.message.toLowerCase().contains('disabled') ||
                     otpErr.code == 'otp_disabled')) {
                  accountExists = false;
                } else {
                  accountExists = true;
                }
              }
            }

            if (!accountExists) {
              throw Exception('No existe una cuenta registrada con el correo $cleanEmail. Por favor verifica tu correo o selecciona "Crear Bóveda".');
            }
          }

          activeKeys = deterministicKeys;
          activeAuthPassword = deterministicAuthPassword;
        }
      } else {
        // Modo Registro: Prevenir sobreescritura accidental o reseteo si la cuenta ya existe
        final localVerifier = await _secureStorage.getPasswordVerifier(email);
        if (localVerifier != null) {
          if (mounted) setState(() => _isLogin = true);
          throw Exception('Ya existe una bóveda registrada con el correo $email en este dispositivo. Por favor inicia sesión.');
        }

        try {
          final client = Supabase.instance.client;
          final signUpRes = await client.auth.signUp(
            email: email,
            password: deterministicAuthPassword,
          );
          if (signUpRes.user?.identities == null || signUpRes.user!.identities!.isEmpty) {
            if (mounted) setState(() => _isLogin = true);
            throw Exception('Ya existe una cuenta registrada con el correo $email. Selecciona "Iniciar Sesión" para acceder.');
          }
        } on AuthException catch (e) {
          if (e.message.toLowerCase().contains('already') ||
              e.message.toLowerCase().contains('exists')) {
            if (mounted) setState(() => _isLogin = true);
            throw Exception('Ya existe una cuenta registrada con el correo $email. Selecciona "Iniciar Sesión" para acceder.');
          }
        } catch (_) {}
        activeKeys = deterministicKeys;
        activeAuthPassword = deterministicAuthPassword;
      }

      // 4. SOLO SI LA CONTRASEÑA ES 100% CORRECTA O CUENTA VÁLIDA: Verificar 2FA para nuevo dispositivo o registro
      final isDeviceAuth = await _pinService.isDeviceAuthorized(email);
      final bool requiresPin = !_isLogin || !isDeviceAuth;

      if (requiresPin) {
        setState(() => _statusMessage = !_isLogin
            ? 'Enviando código de verificación a tu correo...'
            : 'Nuevo dispositivo detectado. Enviando PIN de seguridad a tu correo...');
        final purpose = !_isLogin
            ? PinVerificationPurpose.registration
            : PinVerificationPurpose.newDevice;

        final demoPin = await _pinService.sendSecurityPin(
          email: email,
          purpose: purpose,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        final pinVerified = await PinVerificationDialog.show(
          context: context,
          email: email,
          purpose: purpose,
          pinService: _pinService,
          initialDemoPin: demoPin,
        );

        if (!pinVerified) {
          throw Exception('No se completó la verificación del código PIN enviado a tu correo.');
        }

        if (mounted) {
          setState(() {
            _isLoading = true;
            _statusMessage = 'Autorizando dispositivo y preparando bóveda...';
          });
        }

        // VALIDACIÓN CRÍTICA ZERO-KNOWLEDGE POST-PIN EN NUEVO DISPOSITIVO:
        // Si el usuario ya tiene elementos en la nube (vault_items), verificar que la
        // clave maestra derivada pueda descifrarlos exitosamente mediante AES-256-GCM.
        // Si falla la verificación del MAC (SecretBoxAuthenticationError), la clave maestra es errónea.
        if (_isLogin && savedVerifier == null) {
          try {
            final client = Supabase.instance.client;
            if (client.auth.currentUser != null) {
              final dynamic remoteRows = await client
                  .from('vault_items')
                  .select('payload_ciphertext, nonce, auth_tag, is_deleted')
                  .eq('user_id', client.auth.currentUser!.id)
                  .eq('is_deleted', false)
                  .limit(5);

              final List<dynamic> rowsList = (remoteRows is List) ? remoteRows : [];
              if (rowsList.isNotEmpty) {
                bool anyDecrypted = false;
                for (final dynamic row in rowsList) {
                  try {
                    final payload = EncryptedPayload(
                      ciphertextBase64: row['payload_ciphertext'] as String,
                      nonceBase64: row['nonce'] as String,
                      authTagBase64: row['auth_tag'] as String,
                    );
                    await CryptoEngine.decrypt(
                      payload: payload,
                      key: activeKeys.masterEncryptionKey,
                    );
                    anyDecrypted = true;
                    break;
                  } catch (_) {}
                }
                if (!anyDecrypted) {
                  await client.auth.signOut();
                  throw Exception('Contraseña maestra incorrecta. No coincide con las credenciales cifradas de tu bóveda.');
                }
              }
            }
          } catch (e) {
            if (e.toString().contains('Contraseña maestra incorrecta')) rethrow;
            debugPrint('Aviso en validación Zero-Knowledge post-PIN: $e');
          }
        }
      } else {
        setState(() => _statusMessage = 'Verificando seguridad de acceso Zero-Knowledge...');
      }

      // 5. Asegurar sincronización de sesión y contraseña en Supabase Auth
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser != null) {
          await client.auth.updateUser(UserAttributes(password: activeAuthPassword));
        } else {
          try {
            await client.auth.signInWithPassword(
              email: email,
              password: activeAuthPassword,
            );
          } on AuthException catch (authErr) {
            if (authErr.message.toLowerCase().contains('invalid') || authErr.code == 'invalid_credentials') {
              try {
                await client.auth.signUp(
                  email: email,
                  password: activeAuthPassword,
                );
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('Aviso al sincronizar sesión de Supabase: $e');
      }

      // Guardar la contraseña derivada para biometría y reconexiones en segundo plano
      await _secureStorage.saveSavedAuthPassword(email, activeAuthPassword);

      // 6. Autorizar dispositivo y guardar credenciales
      await _pinService.authorizeCurrentDevice(email);
      await _secureStorage.savePasswordVerifier(email, activeKeys.authHashHex);
      await _secureStorage.saveUserEmail(email);
      await _secureStorage.saveUserSalt(email, deterministicSaltBase64);
      final rawKeyBytes = await activeKeys.masterEncryptionKey.extractBytes();
      await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
      await _secureStorage.setBiometricsEnabled(true);

      // Si es registro nuevo (! _isLogin), generamos y presentamos el Kit de Rescate de Emergencia
      if (!_isLogin) {
        final recoveryKey = RecoveryKitService.generateRecoveryKey();
        final recoveryPayload = await RecoveryKitService.encryptMekForRecovery(
          masterEncryptionKey: activeKeys.masterEncryptionKey,
          recoveryKey: recoveryKey,
          salt: deterministicSalt,
        );
        await RecoveryKitService.saveRecoveryData(
          email: email,
          payload: recoveryPayload,
          recoveryKey: recoveryKey,
        );
        if (mounted) {
          await RecoveryKitDialog.show(
            context: context,
            email: email,
            recoveryKey: recoveryKey,
            isInitialSetup: true,
          );
        }
      }

      // 7. Acceder a la Bóveda en memoria
      widget.onUnlockSuccess(activeKeys.masterEncryptionKey, email);
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(errText, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricTitle = _biometricService.getBiometricTitle();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              color: const Color(0xFF131722),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF1F2937)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Isologo y Logo NovaKey
                    const NovaKeyLogo(size: 54),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Acceso a la Bóveda' : 'Crear Nueva Bóveda',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLogin
                          ? 'Cifrado de Extremo a Extremo (Zero-Knowledge)'
                          : 'Configura tu bóveda con cifrado Zero-Knowledge',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // Selector de Modo: Iniciar Sesión vs Nueva Bóveda
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      if (!_isLogin) setState(() => _isLogin = true);
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _isLogin ? const Color(0xFF1D4ED8) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 16,
                                      color: _isLogin ? Colors.white : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _isLogin ? FontWeight.bold : FontWeight.w500,
                                        color: _isLogin ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      if (_isLogin) setState(() => _isLogin = false);
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: !_isLogin ? const Color(0xFF1D4ED8) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 16,
                                      color: !_isLogin ? Colors.white : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Nueva Bóveda',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_isLogin ? FontWeight.bold : FontWeight.w500,
                                        color: !_isLogin ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Desbloqueo Rápido Biométrico si está disponible
                    if (_canUseBiometrics && _isLogin) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          foregroundColor: const Color(0xFF38BDF8),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8)),
                        label: Text(biometricTitle),
                        onPressed: _isLoading ? null : _unlockWithBiometrics,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFF1E293B))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('o ingresa con contraseña', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ),
                          const Expanded(child: Divider(color: Color(0xFF1E293B))),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _isLogin ? 'Correo Electrónico' : 'Correo Electrónico para la Nueva Bóveda',
                        hintText: 'ejemplo@correo.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoading) {
                          _submitAuth();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: _isLogin ? 'Contraseña Maestra' : 'Definir Contraseña Maestra',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        border: const OutlineInputBorder(),
                        helperText: !_isLogin
                            ? 'Mínimo 8 caracteres: mayúscula, minúscula, número y símbolo (!@#\$%...)'
                            : null,
                        helperMaxLines: 2,
                        helperStyle: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF38BDF8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    if (_isLoading) ...[
                      const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(_isLogin ? Icons.lock_open_rounded : Icons.shield_rounded, size: 18),
                        label: Text(
                          _isLogin ? 'Desbloquear Bóveda' : 'Crear Bóveda Segura',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _submitAuth,
                      ),
                      const SizedBox(height: 12),
                      if (_isLogin) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF38BDF8)),
                          label: const Text(
                            '¿Olvidaste tu contraseña maestra?',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _handleForgotPassword,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se generará un Kit de Rescate de Emergencia oficial descargable.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF1E293B)),
                    const SizedBox(height: 12),

                    // Tarjeta Oficial de Créditos Tech Innova con enlace directo a tech-innova.online
                    const TechInnovaCredits(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
