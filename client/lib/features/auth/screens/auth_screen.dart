import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/secure_storage_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(SecretKey masterEncryptionKey) onUnlockSuccess;

  const AuthScreen({super.key, required this.onUnlockSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _biometricService = BiometricService();
  final _secureStorage = SecureStorageService();

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
    if (email != null && mounted) {
      _emailController.text = email;
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

      final keyBytes = base64Decode(savedMekBase64);
      final secretKey = SecretKey(keyBytes);
      widget.onUnlockSuccess(secretKey);
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

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Derivando clave con Argon2id (Zero-Knowledge)...';
    });

    try {
      // 1. Obtener o generar la sal del usuario
      String? saltBase64 = await _secureStorage.getUserSalt();
      Uint8List salt;

      if (saltBase64 == null || !_isLogin) {
        salt = CryptoEngine.generateRandomSalt();
        saltBase64 = base64Encode(salt);
        await _secureStorage.saveUserSalt(saltBase64);
      } else {
        salt = base64Decode(saltBase64);
      }

      // 2. Derivar la clave criptográfica mediante Argon2id
      final derivedKeys = await CryptoEngine.deriveKeys(
        masterPassword: password,
        salt: salt,
      );

      // 3. Guardar credenciales para acceso biométrico futuro
      await _secureStorage.saveUserEmail(email);
      final rawKeyBytes = await derivedKeys.masterEncryptionKey.extractBytes();
      await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));
      await _secureStorage.setBiometricsEnabled(true);

      // 4. Conceder acceso inmediato a la Bóveda en memoria
      widget.onUnlockSuccess(derivedKeys.masterEncryptionKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de autenticación: $e'), backgroundColor: Colors.red),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        size: 48,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Acceso a Bóveda' : 'Crear Nueva Bóveda',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cifrado de Extremo a Extremo (Zero-Knowledge)',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Desbloqueo Rápido Biométrico si está disponible
                    if (_canUseBiometrics && _isLogin) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.blueAccent),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, color: Colors.blueAccent),
                        label: Text(biometricTitle),
                        onPressed: _isLoading ? null : _unlockWithBiometrics,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('o ingresa con contraseña', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ),
                          const Expanded(child: Divider()),
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
                    const SizedBox(height: 20),

                    if (_isLoading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submitAuth,
                        child: Text(
                          _isLogin ? 'Desbloquear Bóveda' : 'Inicializar Bóveda Cifrada',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() => _isLogin = !_isLogin);
                        },
                        child: Text(
                          _isLogin
                              ? '¿No tienes cuenta? Inicializa una bóveda'
                              : '¿Ya tienes una bóveda? Inicia sesión',
                        ),
                      ),
                    ],
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
