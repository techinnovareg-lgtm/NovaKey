import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/security/recovery_kit_service.dart';

/// Diálogo modal interactivo para visualizar y descargar el Kit de Rescate de Emergencia
class RecoveryKitDialog extends StatefulWidget {
  final String email;
  final String recoveryKey;
  final bool isInitialSetup;

  const RecoveryKitDialog({
    super.key,
    required this.email,
    required this.recoveryKey,
    this.isInitialSetup = false,
  });

  static Future<void> show({
    required BuildContext context,
    required String email,
    required String recoveryKey,
    bool isInitialSetup = false,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !isInitialSetup,
      builder: (_) => RecoveryKitDialog(
        email: email,
        recoveryKey: recoveryKey,
        isInitialSetup: isInitialSetup,
      ),
    );
  }

  @override
  State<RecoveryKitDialog> createState() => _RecoveryKitDialogState();
}

class _RecoveryKitDialogState extends State<RecoveryKitDialog> {
  bool _copied = false;
  bool _confirmedSaved = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.recoveryKey));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Clave de Rescate copiada al portapapeles.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F141C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF38BDF8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isInitialSetup
                              ? '¡Bóveda Creada! Kit de Rescate'
                              : 'Kit de Rescate de Emergencia',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Cero-Conocimiento • Llave Maestra de Recuperación',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Explicación
              const Text(
                'NovaKey utiliza cifrado de grado militar. Si alguna vez olvidas tu contraseña maestra, esta clave es la **única llave matemática** que podrá desbloquear tus contraseñas.',
                style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1), height: 1.45),
              ),
              const SizedBox(height: 16),

              // Caja de la Clave de Rescate
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.08),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'CLAVE DE RESCATE DE EMERGENCIA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.recoveryKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(_copied ? Icons.check_circle_rounded : Icons.copy_rounded, size: 16),
                          label: Text(_copied ? '¡Copiada!' : 'Copiar Clave'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _copied ? const Color(0xFF34D399) : Colors.white,
                            side: BorderSide(
                              color: _copied ? const Color(0xFF10B981) : const Color(0xFF334155),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: _copyToClipboard,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Descargar / Imprimir Kit Oficial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            RecoveryKitService.openPrintableDocument(
                              email: widget.email,
                              recoveryKey: widget.recoveryKey,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Advertencia de Seguridad
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guarda este Kit fuera de línea (impreso o en USB seguro). Ni Tech Innova ni nadie puede ayudarte a descifrar tus datos si pierdes tu contraseña y no tienes este Kit.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFFDE68A), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Checkbox de confirmación si es configuración inicial
              if (widget.isInitialSetup) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmedSaved,
                  activeColor: const Color(0xFF1D4ED8),
                  title: const Text(
                    'He copiado o descargado mi Clave de Rescate y la guardaré en un lugar físico seguro.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                  ),
                  onChanged: (val) => setState(() => _confirmedSaved = val ?? false),
                ),
                const SizedBox(height: 12),
              ],

              // Botón de cierre / continuar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: (!widget.isInitialSetup || _confirmedSaved)
                      ? const Color(0xFF059669)
                      : Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (!widget.isInitialSetup || _confirmedSaved)
                    ? () => Navigator.of(context).pop()
                    : null,
                child: Text(
                  widget.isInitialSetup ? 'Entrar a mi Bóveda Segura' : 'Entendido y Cerrar',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
