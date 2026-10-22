import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/novakey_logo.dart';
import '../models/vault_category.dart';
import '../models/vault_item.dart';
import '../services/vault_sync_service.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/vault_sidebar.dart';
import '../../subscription/widgets/user_profile_menu_button.dart';
import '../../subscription/services/subscription_service.dart';
import 'txt_import_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  final VaultSyncService syncService;
  final VoidCallback onLock;
  final Duration currentTimeout;
  final ValueChanged<Duration>? onTimeoutChanged;

  const VaultHomeScreen({
    super.key,
    required this.syncService,
    required this.onLock,
    this.currentTimeout = const Duration(minutes: 2),
    this.onTimeoutChanged,
  });

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';
  Timer? _clipboardClearTimer;
  StreamSubscription<List<String>>? _categoriesSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.syncService.initializeRealtimeSync();
    _categoriesSub = widget.syncService.categoriesStream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await widget.syncService.fetchAndDecryptAll();
    if (mounted) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPlanUpgradeNotification();
      });
    }
  }

  Future<void> _checkPlanUpgradeNotification() async {
    if (!mounted) return;
    final planName = await SubscriptionService.checkPendingUpgradeNotification(
      widget.syncService.userEmail,
    );
    if (planName != null && mounted) {
      _showUpgradeCelebrationDialog(planName);
    }
  }

  void _showUpgradeCelebrationDialog(String planName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Felicidades, has contratado tu Plan $planName!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu suscripción ha sido activada con éxito por el equipo de Tech Innova. Tu bóveda ahora cuenta con todas las funciones del Plan $planName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    _buildCelebrationBenefitItem(
                      Icons.sync_rounded,
                      'Sincronización multi-dispositivo activa en Web y Android.',
                    ),
                    const SizedBox(height: 10),
                    _buildCelebrationBenefitItem(
                      Icons.security_rounded,
                      'Cifrado Zero-Knowledge AES-256-GCM de grado militar.',
                    ),
                    const SizedBox(height: 10),
                    _buildCelebrationBenefitItem(
                      Icons.headset_mic_rounded,
                      'Soporte prioritario y almacenamiento expandido en la nube.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '¡Empezar a Usar NovaKey!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationBenefitItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label copiado al portapapeles. Se borrará en 30s por seguridad.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
        ),
      ),
    );

    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void _showImageLightbox(String title, String imageBase64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.photo_rounded, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$title (Etiqueta / Dispositivo)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                    maxWidth: 600,
                  ),
                  child: Image.memory(
                    base64Decode(imageBase64),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Foto protegida con cifrado de extremo a extremo AES-256-GCM',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportVaultBackup() {
    final items = widget.syncService.currentItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay elementos en la bóveda para exportar.')),
      );
      return;
    }

    final backupList = items.map((item) => {
      'title': item.title,
      'username': item.username,
      'password': item.password,
      'websiteUrl': item.websiteUrl,
      'notes': item.notes,
      'category': item.category,
      'hasPhoto': item.imageBase64.isNotEmpty,
      'updatedAt': item.updatedAt.toIso8601String(),
    }).toList();

    final jsonBackupStr = const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'vaultUser': widget.syncService.userEmail,
      'totalRecords': items.length,
      'items': backupList,
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Respaldo de la Bóveda'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Se generó el respaldo de ${items.length} cuentas registradas. Puedes copiar el texto JSON de respaldo o guardarlo en un lugar seguro.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonBackupStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copiar Respaldo JSON'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonBackupStr));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Respaldo JSON copiado al portapapeles.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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

  bool _matchesCategory(VaultItem item, String selectedCat) {
    if (selectedCat == 'all') return true;
    if (selectedCat == 'favorites') return item.isFavorite;

    final itemCat = item.category.trim().toLowerCase();
    final targetCat = selectedCat.trim().toLowerCase();

    // Map 'login' and 'correo' compatibly
    if (targetCat == 'correo' || targetCat == 'login') {
      return itemCat == 'correo' || itemCat == 'login';
    }
    return itemCat == targetCat;
  }

  Future<String?> _promptNewCategoryName(BuildContext ctx) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
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
              'Ingresa el nombre de la categoría (ej. Bancos, Tiendas por departamento, Redes Sociales):',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nombre de la categoría',
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

  Future<void> _showAddCategoryDialog() async {
    final name = await _promptNewCategoryName(context);
    if (name != null && name.trim().isNotEmpty) {
      await widget.syncService.addCustomCategory(name.trim());
      setState(() {
        _selectedCategory = name.trim();
      });
    }
  }

  void _showAddEditItemModal([VaultItem? existingItem]) {
    final titleController = TextEditingController(text: existingItem?.title ?? '');
    final usernameController = TextEditingController(text: existingItem?.username ?? '');
    final passwordController = TextEditingController(text: existingItem?.password ?? '');
    final websiteController = TextEditingController(text: existingItem?.websiteUrl ?? '');
    final notesController = TextEditingController(text: existingItem?.notes ?? '');
    bool isFavorite = existingItem?.isFavorite ?? false;
    final initialCategory = existingItem?.category ??
        (_selectedCategory != 'all' && _selectedCategory != 'favorites'
            ? _selectedCategory
            : 'correo');
    String category = initialCategory == 'login' ? 'correo' : initialCategory;
    String currentImageBase64 = existingItem?.imageBase64 ?? '';
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickPhoto() async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                withData: true,
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                if (file.bytes != null) {
                  if (file.bytes!.lengthInBytes > 3 * 1024 * 1024) {
                    if (modalContext.mounted) {
                      ScaffoldMessenger.of(modalContext).showSnackBar(
                        const SnackBar(
                          content: Text('La imagen no debe superar los 3 MB.'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                    }
                    return;
                  }
                  final b64 = base64Encode(file.bytes!);
                  setModalState(() {
                    currentImageBase64 = b64;
                    if (category == 'login' || category == 'correo') {
                      category = 'device';
                    }
                  });
                }
              }
            } catch (e) {
              if (modalContext.mounted) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(content: Text('Error al cargar imagen: $e'), backgroundColor: Colors.red),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingItem == null ? 'Nueva Credencial / Dispositivo' : 'Editar Elemento',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () {
                          setModalState(() => isFavorite = !isFavorite);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector de Categoría Dinámico con opción de crear nueva categoría al vuelo
                  Builder(
                    builder: (context) {
                      final allCats = _getAllCategories();
                      final currentCatValue = allCats.any((c) => c.id == category)
                          ? category
                          : (category == 'login' ? 'correo' : allCats.first.id);

                      return DropdownButtonFormField<String>(
                        value: currentCatValue,
                        decoration: const InputDecoration(
                          labelText: 'Categoría de la Credencial',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ...allCats.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Icon(c.icon, size: 18, color: const Color(0xFF38BDF8)),
                                    const SizedBox(width: 8),
                                    Text(c.name),
                                  ],
                                ),
                              )),
                          const DropdownMenuItem(
                            value: '__new__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.blueAccent),
                                SizedBox(width: 8),
                                Text(
                                  '+ Crear nueva categoría...',
                                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == '__new__') {
                            final newCat = await _promptNewCategoryName(modalContext);
                            if (newCat != null && newCat.trim().isNotEmpty) {
                              await widget.syncService.addCustomCategory(newCat.trim());
                              setModalState(() => category = newCat.trim());
                            }
                          } else if (val != null) {
                            setModalState(() => category = val);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título o Dispositivo (Ej. Router Movistar, Cámara Entrada, Gmail)',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario / SSID / Código',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña / Clave Wi-Fi / PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            ),
                            onPressed: () {
                              setModalState(() => obscurePassword = !obscurePassword);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent),
                            tooltip: 'Generar Contraseña Segura',
                            onPressed: () async {
                              final generated = await showDialog<String>(
                                context: modalContext,
                                builder: (_) => const PasswordGeneratorDialog(),
                              );
                              if (generated != null && generated.isNotEmpty) {
                                setModalState(() {
                                  passwordController.text = generated;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: websiteController,
                    decoration: const InputDecoration(
                      labelText: 'IP Local o URL (Ej. 192.168.1.1 o https://...)',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas Seguras (Cifradas)',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sección de Foto / Etiqueta de Dispositivo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Foto de Credencial o Etiqueta de Dispositivo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            if (currentImageBase64.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('ADJUNTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sube la foto de la pegatina detrás de tu módem, cámara o dispositivo (Cifrada con AES-256-GCM).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 10),
                        if (currentImageBase64.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              color: Colors.black26,
                              height: 140,
                              width: double.infinity,
                              child: Image.memory(
                                base64Decode(currentImageBase64),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                                  label: const Text('Ver foto en grande', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showImageLightbox(
                                    titleController.text.isNotEmpty ? titleController.text : 'Dispositivo',
                                    currentImageBase64,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                                tooltip: 'Cambiar Foto',
                                onPressed: pickPhoto,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                tooltip: 'Quitar Foto',
                                onPressed: () => setModalState(() => currentImageBase64 = ''),
                              ),
                            ],
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_a_photo_rounded, color: Colors.blueAccent),
                            label: const Text('Adjuntar Foto de Etiqueta (Módem, Cámara, etc.)'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blueAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: pickPhoto,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(modalContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar'),
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) return;

                            final newItem = (existingItem ?? VaultItem(
                              title: titleController.text.trim(),
                              username: usernameController.text.trim(),
                              password: passwordController.text,
                              websiteUrl: websiteController.text.trim(),
                              notes: notesController.text.trim(),
                              category: category,
                              imageBase64: currentImageBase64,
                              isFavorite: isFavorite,
                            )).copyWith(
                              title: titleController.text.trim(),
                              username: usernameController.text.trim(),
                              password: passwordController.text,
                              websiteUrl: websiteController.text.trim(),
                              notes: notesController.text.trim(),
                              category: category,
                              imageBase64: currentImageBase64,
                              isFavorite: isFavorite,
                            );

                            await widget.syncService.saveItem(newItem);
                            if (modalContext.mounted) Navigator.of(modalContext).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getCategoryTitle(String cat) {
    if (cat == 'all') return 'Todos los Registros';
    if (cat == 'favorites') return 'Favoritos';
    if (cat == 'login') return 'Correos y Cuentas';
    final allCats = _getAllCategories();
    final match = allCats.firstWhere(
      (c) => c.id.toLowerCase() == cat.toLowerCase(),
      orElse: () => VaultCategory(
        id: cat,
        name: cat,
        icon: VaultCategory.getIconForName(cat),
      ),
    );
    return match.name;
  }

  IconData _getCategoryIcon(String cat) {
    if (cat == 'all') return Icons.all_inbox_rounded;
    if (cat == 'favorites') return Icons.star_rounded;
    if (cat == 'login') return Icons.mail_lock_rounded;
    final allCats = _getAllCategories();
    final match = allCats.firstWhere(
      (c) => c.id.toLowerCase() == cat.toLowerCase(),
      orElse: () => VaultCategory(
        id: cat,
        name: cat,
        icon: VaultCategory.getIconForName(cat),
      ),
    );
    return match.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return StreamBuilder<List<VaultItem>>(
      stream: widget.syncService.vaultItemsStream,
      initialData: widget.syncService.currentItems,
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final allCategories = _getAllCategories();

        final counts = <String, int>{
          'all': allItems.length,
          'favorites': allItems.where((e) => e.isFavorite).length,
        };
        for (final cat in allCategories) {
          counts[cat.id] = allItems.where((e) => _matchesCategory(e, cat.id)).length;
        }

        final filtered = allItems.where((item) {
          final matchesSearch = item.title.toLowerCase().contains(_searchQuery) ||
              item.username.toLowerCase().contains(_searchQuery) ||
              item.websiteUrl.toLowerCase().contains(_searchQuery) ||
              item.notes.toLowerCase().contains(_searchQuery);

          if (!matchesSearch) return false;

          return _matchesCategory(item, _selectedCategory);
        }).toList();

        final sidebar = VaultSidebar(
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) {
            setState(() => _selectedCategory = cat);
          },
          counts: counts,
          categories: allCategories,
          onAddNewItem: () => _showAddEditItemModal(),
          onAddCategory: _showAddCategoryDialog,
          onDeleteCategory: (catId) async {
            await widget.syncService.deleteCustomCategory(catId);
            if (_selectedCategory == catId) {
              setState(() => _selectedCategory = 'all');
            } else {
              setState(() {});
            }
          },
          onImport: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TxtImportScreen(syncService: widget.syncService),
              ),
            );
          },
          onExport: _exportVaultBackup,
          onSync: () => widget.syncService.fetchAndDecryptAll(),
          onOpenPasswordGenerator: () => showDialog(
            context: context,
            builder: (_) => const PasswordGeneratorDialog(),
          ),
          onChangePassword: () => ChangePasswordDialog.show(context, widget.syncService),
          onLock: widget.onLock,
          currentTimeout: widget.currentTimeout,
          onTimeoutChanged: widget.onTimeoutChanged,
          isDrawer: !isWide,
        );

        final mainContent = Column(
          children: [
            // Barra Superior de Contenido
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF11141A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1F2937), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(_selectedCategory),
                    color: const Color(0xFF38BDF8),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getCategoryTitle(_selectedCategory),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.5)),
                    ),
                    child: Text(
                      '${filtered.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Campo de búsqueda integrado
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar cuentas o equipos...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF19202C),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                  if (!isWide) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF38BDF8)),
                      tooltip: 'Nueva Credencial',
                      onPressed: () => _showAddEditItemModal(),
                    ),
                  ],
                  const SizedBox(width: 14),
                  // Menú de Perfil de Usuario, Planes, Superadmin y Cerrar Sesión
                  UserProfileMenuButton(
                    userEmail: widget.syncService.userEmail,
                    onLock: widget.onLock,
                    onChangePassword: () => ChangePasswordDialog.show(context, widget.syncService),
                    currentTimeout: widget.currentTimeout,
                    onTimeoutChanged: widget.onTimeoutChanged,
                  ),
                ],
              ),
            ),

            // Lista de elementos de la Bóveda
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF38BDF8)),
                          SizedBox(height: 16),
                          Text(
                            'Descifrando bóveda con clave maestra...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade700),
                              const SizedBox(height: 16),
                              Text(
                                allItems.isEmpty
                                    ? 'Tu bóveda está vacía.\nPresiona el botón "Nueva Credencial" para agregar tu primer acceso.'
                                    : 'No se encontraron registros en "${_getCategoryTitle(_selectedCategory)}".',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              color: const Color(0xFF161B26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: item.category == 'device'
                                      ? const Color(0xFF1D4ED8).withOpacity(0.35)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: item.category == 'device'
                                      ? const Color(0xFF1D4ED8).withOpacity(0.2)
                                      : const Color(0xFF1E293B),
                                  child: Icon(
                                    item.category == 'note'
                                        ? Icons.note_rounded
                                        : item.category == 'device'
                                            ? Icons.router_rounded
                                            : Icons.lock_rounded,
                                    color: item.category == 'device'
                                        ? const Color(0xFF38BDF8)
                                        : (item.category == 'note'
                                            ? Colors.amberAccent
                                            : const Color(0xFF60A5FA)),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.imageBase64.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.photo_camera_rounded, size: 12, color: Colors.amberAccent),
                                            SizedBox(width: 4),
                                            Text(
                                              'FOTO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.amberAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  item.username.isNotEmpty ? item.username : item.websiteUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.imageBase64.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.photo_library_rounded, size: 20, color: Colors.amberAccent),
                                        tooltip: 'Ver foto de la etiqueta física',
                                        onPressed: () => _showImageLightbox(item.title, item.imageBase64),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 20),
                                      tooltip: 'Copiar Contraseña',
                                      onPressed: () => _copyToClipboard(item.password, 'Contraseña'),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddEditItemModal(item);
                                        } else if (val == 'delete') {
                                          widget.syncService.deleteItem(item.id);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _showAddEditItemModal(item),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1017),
            body: Row(
              children: [
                sidebar,
                Expanded(child: mainContent),
              ],
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1017),
            appBar: AppBar(
              backgroundColor: const Color(0xFF131720),
              title: const NovaKeyLogo(size: 28, compact: true),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'Sincronizar',
                  onPressed: () => widget.syncService.fetchAndDecryptAll(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: UserProfileMenuButton(
                    userEmail: widget.syncService.userEmail,
                    onLock: widget.onLock,
                    onChangePassword: () => ChangePasswordDialog.show(context, widget.syncService),
                    currentTimeout: widget.currentTimeout,
                    onTimeoutChanged: widget.onTimeoutChanged,
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              child: sidebar,
            ),
            body: mainContent,
            floatingActionButton: FloatingActionButton(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              onPressed: () => _showAddEditItemModal(),
              child: const Icon(Icons.add_rounded),
            ),
          );
        }
      },
    );
  }
}
