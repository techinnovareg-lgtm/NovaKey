import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/vault_category.dart';
import '../services/vault_sync_service.dart';
import '../utils/excel_credentials_parser.dart';
import '../utils/txt_credentials_parser.dart';

/// Pantalla para cargar e importar archivos .txt y Excel (.xlsx) de cuentas y contraseñas
class TxtImportScreen extends StatefulWidget {
  final VaultSyncService syncService;

  const TxtImportScreen({super.key, required this.syncService});

  @override
  State<TxtImportScreen> createState() => _TxtImportScreenState();
}

class _TxtImportScreenState extends State<TxtImportScreen> {
  final _textController = TextEditingController();
  List<ParsedCredential> _parsedItems = [];
  bool _isProcessing = false;
  bool _obscurePasswords = true;
  String? _loadedFileName;
  String _fileTypeDetected = ''; // 'txt' o 'excel'
  String _selectedTargetCategory = 'correo';

  List<VaultCategory> _getAllCategories() {
    final custom = widget.syncService.customCategories.map((name) {
      return VaultCategory(
        id: name,
        name: name,
        icon: VaultCategory.getIconForName(name),
        isSystem: false,
      );
    }).toList();
    return [...VaultCategory.defaultCategories, ...custom];
  }

  Future<String?> _promptNewCategoryName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Nueva Categoría', style: TextStyle(fontSize: 18, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el nombre de la categoría para las cuentas importadas:',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ej. Bancos, Redes Sociales, Tiendas por departamento',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  Navigator.of(dlgCtx).pop(val.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(dlgCtx).pop(controller.text.trim());
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.extension?.toLowerCase() ?? '';

        if (extension == 'xlsx' || extension == 'xls') {
          if (file.bytes != null) {
            final items = ExcelCredentialsParser.parseBytes(file.bytes!);
            setState(() {
              _loadedFileName = file.name;
              _fileTypeDetected = 'excel';
              _parsedItems = items;
              _textController.text =
                  'Libro Excel importado: ${file.name}\nSe identificaron ${items.length} cuentas con sus columnas de credenciales.';
            });
          }
        } else {
          // Archivo de texto .txt
          String content = '';
          if (file.bytes != null) {
            content = utf8.decode(file.bytes!);
          }

          setState(() {
            _loadedFileName = file.name;
            _fileTypeDetected = 'txt';
            _textController.text = content;
          });

          _parseContent(content);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar archivo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _parseContent(String text) {
    if (text.trim().isEmpty) {
      setState(() => _parsedItems = []);
      return;
    }

    final items = TxtCredentialsParser.parse(text);
    setState(() {
      _parsedItems = items;
    });
  }

  Future<void> _importSelectedItems() async {
    final selected = _parsedItems.where((item) => item.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una cuenta para importar')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      int importedCount = 0;
      for (final item in selected) {
        final vaultItem = item.toVaultItem().copyWith(
          category: _selectedTargetCategory,
        );
        await widget.syncService.saveItem(vaultItem);
        importedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ Se cifraron e importaron $importedCount cuentas a tu bóveda con éxito.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error durante la importación: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Cuentas (.txt / Excel)'),
        actions: [
          if (_parsedItems.isNotEmpty)
            IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              tooltip: _obscurePasswords ? 'Mostrar contraseñas' : 'Ocultar contraseñas',
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Botón de selección de archivo y descripción
            Card(
              elevation: 0,
              color: Colors.blueAccent.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_rounded, size: 36, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Icon(Icons.table_chart_rounded, size: 36, color: Colors.green.shade400),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cargar Archivo de Cuentas (.txt o Excel)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Soporta archivos de texto (.txt) y hojas de cálculo (.xlsx, .xls).\nReconoce encabezados como Servicio, Usuario, Correo, Contraseña, Clave, etc.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.file_open_rounded),
                      label: Text(_loadedFileName == null ? 'Seleccionar archivo (.txt / .xlsx)' : 'Archivo: $_loadedFileName'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Entrada de texto editable
            ExpansionTile(
              initiallyExpanded: _parsedItems.isEmpty,
              title: const Text('O pegar / editar texto directamente'),
              leading: const Icon(Icons.edit_note_rounded),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _textController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Pega aquí tus cuentas:\nGmail         car123@gmail.com / password123\nHotmail     hafgt1122@hotmail.com  / passwordhot123\n                  kjkjk23@hotmail.com / password5566',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) => _parseContent(text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Previsualización de resultados detectados
            if (_parsedItems.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Cuentas Detectadas (${_parsedItems.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_fileTypeDetected.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _fileTypeDetected == 'excel' ? Colors.green.shade900 : Colors.blue.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _fileTypeDetected == 'excel' ? 'EXCEL' : 'TXT',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton.icon(
                    icon: Icon(
                      _parsedItems.every((e) => e.isSelected)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                    ),
                    label: Text(_parsedItems.every((e) => e.isSelected) ? 'Deseleccionar' : 'Seleccionar todo'),
                    onPressed: () {
                      final allSelected = _parsedItems.every((e) => e.isSelected);
                      setState(() {
                        for (var item in _parsedItems) {
                          item.isSelected = !allSelected;
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _parsedItems.length,
                itemBuilder: (context, index) {
                  final item = _parsedItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Checkbox(
                        value: item.isSelected,
                        onChanged: (val) {
                          setState(() => item.isSelected = val ?? true);
                        },
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.username,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _obscurePasswords ? '••••••••••••' : item.password,
                          style: TextStyle(
                            fontFamily: _obscurePasswords ? null : 'monospace',
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Selector de categoría de destino
              Card(
                elevation: 0,
                color: const Color(0xFF1E2430),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_shared_rounded, color: Color(0xFF38BDF8), size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        'Asignar a Categoría:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final allCategories = _getAllCategories();
                            final catVal = allCategories.any((c) => c.id == _selectedTargetCategory)
                                ? _selectedTargetCategory
                                : allCategories.first.id;

                            return DropdownButtonFormField<String>(
                              value: catVal,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                ...allCategories.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(c.icon, size: 16, color: const Color(0xFF38BDF8)),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              c.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const DropdownMenuItem(
                                  value: '__new__',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.blueAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        '+ Crear nueva...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) async {
                                if (val == '__new__') {
                                  final newCat = await _promptNewCategoryName();
                                  if (newCat != null && newCat.trim().isNotEmpty) {
                                    await widget.syncService.addCustomCategory(newCat.trim());
                                    setState(() => _selectedTargetCategory = newCat.trim());
                                  }
                                } else if (val != null) {
                                  setState(() => _selectedTargetCategory = val);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.enhanced_encryption_rounded),
                label: Text(
                  _isProcessing
                      ? 'Cifrando con AES-256-GCM...'
                      : 'Cifrar e Importar (${_parsedItems.where((e) => e.isSelected).length}) a la Bóveda',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessing ? null : _importSelectedItems,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
