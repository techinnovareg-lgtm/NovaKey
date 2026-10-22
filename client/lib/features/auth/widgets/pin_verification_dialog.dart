import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/security/email_pin_service.dart';

/// Modal interactivo para validación de PIN de 6 dígitos enviado al correo
class PinVerificationDialog extends StatefulWidget {
  final String email;
  final PinVerificationPurpose purpose;
  final EmailPinService pinService;
  final String? initialDemoPin;

  const PinVerificationDialog({
    super.key,
    required this.email,
    required this.purpose,
    required this.pinService,
    this.initialDemoPin,
  });

  static Future<bool> show({
    required BuildContext context,
    required String email,
    required PinVerificationPurpose purpose,
    required EmailPinService pinService,
    String? initialDemoPin,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinVerificationDialog(
        email: email,
        purpose: purpose,
        pinService: pinService,
        initialDemoPin: initialDemoPin,
      ),
    );
    return result ?? false;
  }

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  // Soporte adaptativo para códigos de 6 u 8 dígitos (por defecto 8 casillas con tamaño adaptable)
  final int _pinLength = 8;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_pinLength, (_) => TextEditingController());
    _focusNodes = List.generate(_pinLength, (_) => FocusNode());
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getPurposeTitle() {
    switch (widget.purpose) {
      case PinVerificationPurpose.registration:
        return 'Verificación de Cuenta Nueva';
      case PinVerificationPurpose.newDevice:
        return 'Nuevo Dispositivo Detectado';
      case PinVerificationPurpose.changePassword:
        return 'Autorización de Cambio de Contraseña';
      case PinVerificationPurpose.forgotPassword:
        return 'Restablecimiento de Acceso';
    }
  }

  String _getPurposeDescription() {
    switch (widget.purpose) {
      case PinVerificationPurpose.registration:
        return 'Por seguridad, ingresa el código PIN de verificación que enviamos a tu correo para activar tu bóveda.';
      case PinVerificationPurpose.newDevice:
        return 'Estás accediendo desde un dispositivo o navegador no registrado. Ingresa el PIN enviado a tu correo.';
      case PinVerificationPurpose.changePassword:
        return 'Para actualizar tu clave maestra, confirma el código de seguridad enviado a tu correo.';
      case PinVerificationPurpose.forgotPassword:
        return 'Ingresa el código PIN enviado a tu correo para autorizar el restablecimiento de tu contraseña.';
    }
  }

  String get _enteredPin =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _verify() async {
    final pin = _enteredPin;
    if (pin.length != 6 && pin.length != 8) {
      setState(() {
        _errorMessage = 'Por favor ingresa todos los dígitos del código PIN recibido.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.pinService.verifyPin(
        email: widget.email,
        enteredPin: pin,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Código PIN incorrecto.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al validar el código: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendPin() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await widget.pinService.sendSecurityPin(
        email: widget.email,
        purpose: widget.purpose,
      );
      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Se ha enviado un nuevo código PIN a tu correo.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1E40AF), // Azul marino oscuro
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al reenviar código: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
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
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono de Seguridad
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  size: 36,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _getPurposeTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _getPurposeDescription(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400, height: 1.4),
              ),
              const SizedBox(height: 6),

              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
              // Eliminado recuadro de demostración del PIN por seguridad

              // Casillas de entrada de PIN numérico (Adaptables a 8 dígitos con soporte de pegado)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_pinLength, (index) {
                  return SizedBox(
                    width: 38,
                    height: 50,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF0B1120),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        // Si el usuario pega un PIN completo (6 u 8 dígitos) en la primera casilla
                        if (val.length > 1) {
                          final clean = val.replaceAll(RegExp(r'\D'), '');
                          for (int i = 0; i < clean.length && i < _pinLength; i++) {
                            _controllers[i].text = clean[i];
                          }
                          final lastIndex = (clean.length - 1).clamp(0, _pinLength - 1);
                          _focusNodes[lastIndex].requestFocus();
                          if (clean.length == _pinLength || clean.length == 6) {
                            _verify();
                          }
                          return;
                        }

                        if (val.isNotEmpty) {
                          if (index < _pinLength - 1) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                            _verify();
                          }
                        } else if (index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 20),

              // Botón de Verificación
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isVerifying ? null : _verify,
                child: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Verificar Código PIN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
              const SizedBox(height: 12),

              // Reenviar código y Cancelar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade400)),
                  ),
                  TextButton(
                    onPressed: (_resendCountdown == 0 && !_isResending) ? _resendPin : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Reenviar en ${_resendCountdown}s'
                          : 'Reenviar código',
                      style: TextStyle(
                        color: _resendCountdown == 0 ? const Color(0xFF38BDF8) : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
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
