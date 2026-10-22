import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/email_pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/novakey_logo.dart';
import '../../vault/widgets/tech_innova_credits.dart';
import '../widgets/pin_verification_dialog.dart';

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
        // Correo predeterminado para el acceso del Superadmin (Tech Innova)
        _emailController.text = 'tech.innova.reg@gmail.com';
      }
      setState(() {
        _isLogin = true;
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
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo para restablecer la contraseña')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Enviando código PIN de recuperación a tu correo...';
    });

    try {
      final demoPin = await _pinService.sendSecurityPin(
        email: email,
        purpose: PinVerificationPurpose.forgotPassword,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

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

        final newSalt = CryptoEngine.generateRandomSalt();
        final newKeys = await CryptoEngine.deriveKeys(
          masterPassword: newPassController.text,
          salt: newSalt,
        );

        await _secureStorage.saveUserSalt(email, base64Encode(newSalt));
        await _secureStorage.savePasswordVerifier(email, newKeys.authHashHex);
        await _secureStorage.saveUserEmail(email);

        final rawKeyBytes = await newKeys.masterEncryptionKey.extractBytes();
        await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
        await _pinService.authorizeCurrentDevice(email);

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
      // 1. Verificar si requiere verificación de PIN por correo
      final isDeviceAuth = await _pinService.isDeviceAuthorized(email);
      final hasRegisteredBefore = (await _secureStorage.getUserSalt(email)) != null;

      final bool requiresPin = !_isLogin // Caso 1: Registro por primera vez
          || (!isDeviceAuth && hasRegisteredBefore); // Caso 2: Nuevo dispositivo detectado

      if (requiresPin) {
        setState(() => _statusMessage = 'Enviando código de seguridad PIN a tu correo...');
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
            _statusMessage = 'Derivando clave con Argon2id (Zero-Knowledge)...';
          });
        }
      } else {
        setState(() => _statusMessage = 'Derivando clave con Argon2id (Zero-Knowledge)...');
      }

      // 2. Obtener sal y verificador existente
      String? saltBase64 = await _secureStorage.getUserSalt(email);
      String? savedVerifier = await _secureStorage.getPasswordVerifier(email);
      Uint8List salt;

      if (saltBase64 == null) {
        // Primera vez que se registra esta cuenta
        salt = CryptoEngine.generateRandomSalt();
        saltBase64 = base64Encode(salt);
        await _secureStorage.saveUserSalt(email, saltBase64);
      } else {
        salt = base64Decode(saltBase64);
      }

      // 3. Derivar la clave criptográfica mediante Argon2id
      final derivedKeys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: salt,
      );

      // 4. Verificación de seguridad de la contraseña maestra (Zero-Knowledge Verifier)
      if (savedVerifier != null) {
        if (derivedKeys.authHashHex != savedVerifier) {
          throw Exception('Contraseña maestra incorrecta. Por favor verifica mayúsculas/minúsculas y caracteres.');
        }
      } else {
        // Migración o registro nuevo: si existían datos cifrados previos en local, verificar que descifren
        final existingVaultJson = await _secureStorage.getLocalEncryptedVault(email);
        if (existingVaultJson != null && existingVaultJson.trim().length > 10) {
          try {
            final List<dynamic> list = jsonDecode(existingVaultJson);
            if (list.isNotEmpty && list[0]['encrypted'] != null) {
              final payload = EncryptedPayload.fromMap(list[0]['encrypted'] as Map<dynamic, dynamic>);
              await CryptoEngine.decrypt(
                payload: payload,
                key: derivedKeys.masterEncryptionKey,
              );
            }
          } catch (_) {
            throw Exception('Contraseña maestra incorrecta. No coincide con los datos guardados en esta bóveda.');
          }
        }
        // Guardar verificador para futuras validaciones
        await _secureStorage.savePasswordVerifier(email, derivedKeys.authHashHex);
      }

      // 5. Autorizar dispositivo y guardar credenciales para acceso biométrico futuro
      await _pinService.authorizeCurrentDevice(email);
      await _secureStorage.saveUserEmail(email);
      final rawKeyBytes = await derivedKeys.masterEncryptionKey.extractBytes();
      await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
      await _secureStorage.setBiometricsEnabled(true);

      // 6. Conceder acceso inmediato a la Bóveda en memoria
      widget.onUnlockSuccess(derivedKeys.masterEncryptionKey, email);
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
                      'Cifrado de Extremo a Extremo (Zero-Knowledge)',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(height: 24),

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
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico de Registro',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña Maestra',
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submitAuth,
                        child: Text(
                          _isLogin ? 'Desbloquear Bóveda' : 'Inicializar Bóveda Cifrada',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          setState(() => _isLogin = !_isLogin);
                        },
                        child: Text(
                          _isLogin
                              ? '¿No tienes cuenta? Inicializa una bóveda'
                              : '¿Ya tienes una bóveda? Inicia sesión',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      if (_isLogin) ...[
                        TextButton(
                          onPressed: _handleForgotPassword,
                          child: const Text(
                            '¿Olvidaste tu contraseña? (PIN al correo)',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
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
