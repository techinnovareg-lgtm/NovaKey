import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo generador de contraseñas de alta entropía
class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({super.key});

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  int _length = 20;
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSymbols = true;

  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    String pool = '';
    if (_useUppercase) pool += uppercase;
    if (_useLowercase) pool += lowercase;
    if (_useNumbers) pool += numbers;
    if (_useSymbols) pool += symbols;

    if (pool.isEmpty) {
      setState(() => _generatedPassword = '');
      return;
    }

    final random = Random.secure();
    final chars = List.generate(_length, (index) => pool[random.nextInt(pool.length)]);
    setState(() {
      _generatedPassword = chars.join();
    });
  }

  double _calculateEntropy() {
    int poolSize = 0;
    if (_useUppercase) poolSize += 26;
    if (_useLowercase) poolSize += 26;
    if (_useNumbers) poolSize += 10;
    if (_useSymbols) poolSize += 28;

    if (poolSize == 0 || _generatedPassword.isEmpty) return 0.0;
    return _length * (log(poolSize) / log(2));
  }

  Color _getStrengthColor(double entropy) {
    if (entropy < 40) return Colors.red;
    if (entropy < 70) return Colors.orange;
    if (entropy < 90) return Colors.blue;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final entropy = _calculateEntropy();
    final strengthColor = _getStrengthColor(entropy);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key_rounded, color: Colors.blueAccent),
          SizedBox(width: 8),
          Text('Generador Criptográfico'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: strengthColor, width: 1.5),
              ),
              child: SelectableText(
                _generatedPassword,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (entropy / 128).clamp(0.0, 1.0),
                    color: strengthColor,
                    backgroundColor: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${entropy.toStringAsFixed(0)} bits',
                  style: TextStyle(color: strengthColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Longitud: $_length caracteres'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Regenerar',
                  onPressed: _generate,
                ),
              ],
            ),
            Slider(
              value: _length.toDouble(),
              min: 12,
              max: 64,
              divisions: 52,
              label: '$_length',
              onChanged: (val) {
                _length = val.round();
                _generate();
              },
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Mayúsculas (A-Z)'),
              value: _useUppercase,
              onChanged: (v) {
                setState(() => _useUppercase = v ?? true);
                _generate();
              },
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Minúsculas (a-z)'),
              value: _useLowercase,
              onChanged: (v) {
                setState(() => _useLowercase = v ?? true);
                _generate();
              },
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Números (0-9)'),
              value: _useNumbers,
              onChanged: (v) {
                setState(() => _useNumbers = v ?? true);
                _generate();
              },
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Símbolos (!@#\$)'),
              value: _useSymbols,
              onChanged: (v) {
                setState(() => _useSymbols = v ?? true);
                _generate();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar y Usar'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _generatedPassword));
            Navigator.of(context).pop(_generatedPassword);
          },
        ),
      ],
    );
  }
}
