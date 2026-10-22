import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/email_pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../services/vault_sync_service.dart';
import '../../auth/widgets/pin_verification_dialog.dart';

/// Diálogo para cambiar la contraseña maestra de la bóveda con verificación previa por PIN
class ChangePasswordDialog extends StatefulWidget {
  final VaultSyncService syncService;

  const ChangePasswordDialog({super.key, required this.syncService});

  static Future<void> show(BuildContext context, VaultSyncService syncService) async {
    await showDialog(
      context: context,
      builder: (_) => ChangePasswordDialog(syncService: syncService),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _pinService = EmailPinService();
  final _secureStorage = SecureStorageService();

  bool _isProcessing = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChange() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final email = widget.syncService.userEmail;

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos.');
      return;
    }

    if (newPass.length < 8) {
      setState(() => _errorMessage = 'La nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(newPass)) {
      setState(() => _errorMessage = 'Debe incluir al menos una letra mayúscula (A-Z).');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(newPass)) {
      setState(() => _errorMessage = 'Debe incluir al menos una letra minúscula (a-z).');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPass)) {
      setState(() => _errorMessage = 'Debe incluir al menos un número (0-9).');
      return;
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\\/\[\]~`]').hasMatch(newPass)) {
      setState(() => _errorMessage = 'Debe incluir al menos un carácter especial (!@#\$%&*...).');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'La confirmación no coincide con la nueva contraseña.');
      return;
    }

    if (newPass == currentPass) {
      setState(() => _errorMessage = 'La nueva contraseña debe ser diferente a la actual.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Validar la contraseña actual con el verificador Zero-Knowledge
      final saltBase64 = await _secureStorage.getUserSalt(email);
      final savedVerifier = await _secureStorage.getPasswordVerifier(email);

      if (saltBase64 == null || savedVerifier == null) {
        throw Exception('No se encontró información criptográfica de la cuenta.');
      }

      final salt = base64Decode(saltBase64);
      final currentDerived = await CryptoEngine.deriveKeys(
        masterPassword: currentPass,
        salt: salt,
      );

      if (currentDerived.authHashHex != savedVerifier) {
        throw Exception('La contraseña actual es incorrecta.');
      }

      // 2. Solicitar y enviar PIN de 6 dígitos al correo registrado
      final demoPin = await _pinService.sendSecurityPin(
        email: email,
        purpose: PinVerificationPurpose.changePassword,
      );

      if (!mounted) return;

      // 3. Mostrar modal de verificación PIN
      final pinVerified = await PinVerificationDialog.show(
        context: context,
        email: email,
        purpose: PinVerificationPurpose.changePassword,
        pinService: _pinService,
        initialDemoPin: demoPin,
      );

      if (!pinVerified) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Operación cancelada: No se verificó el código PIN de seguridad.';
          });
        }
        return;
      }

      // 4. Generar nueva sal criptográfica y derivar nueva clave maestra
      final newSalt = CryptoEngine.generateRandomSalt();
      final newKeys = await CryptoEngine.deriveKeys(
        masterPassword: newPass,
        salt: newSalt,
      );

      // 5. Re-cifrar todos los elementos existentes de la bóveda con la nueva clave
      final currentItems = widget.syncService.currentItems;
      await _secureStorage.saveUserSalt(email, base64Encode(newSalt));
      await _secureStorage.savePasswordVerifier(email, newKeys.authHashHex);

      // Actualizar bóveda local cifrada con la nueva clave
      final serializedList = <Map<String, dynamic>>[];
      for (final item in currentItems) {
        final sensitiveJson = item.toSensitiveJson();
        final encrypted = await CryptoEngine.encrypt(
          plainText: sensitiveJson,
          key: newKeys.masterEncryptionKey,
        );
        serializedList.add({
          'id': item.id,
          'version': item.version,
          'is_favorite': item.isFavorite,
          'is_deleted': item.isDeleted,
          'updated_at': item.updatedAt.toIso8601String(),
          'encrypted': encrypted.toMap(),
        });
      }

      await _secureStorage.saveLocalEncryptedVault(email, jsonEncode(serializedList));

      // Actualizar MEK biométrico si está activo
      final rawKeyBytes = await newKeys.masterEncryptionKey.extractBytes();
      await _secureStorage.saveEncryptedMek(base64Encode(rawKeyBytes));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✅ Contraseña maestra actualizada y bóveda re-cifrada con éxito.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1F2937)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.password_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cambiar Contraseña Maestra',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Requiere validación de PIN por correo',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Contraseña Actual',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña Maestra',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar Nueva Contraseña',
                  prefixIcon: const Icon(Icons.check_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isProcessing ? null : _submitChange,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Continuar con PIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
