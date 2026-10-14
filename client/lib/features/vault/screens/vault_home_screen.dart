import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vault_item.dart';
import '../services/vault_sync_service.dart';
import '../widgets/password_generator_dialog.dart';
import 'txt_import_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  final VaultSyncService syncService;
  final VoidCallback onLock;

  const VaultHomeScreen({
    super.key,
    required this.syncService,
    required this.onLock,
  });

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';
  Timer? _clipboardClearTimer;

  @override
  void initState() {
    super.initState();
    widget.syncService.initializeRealtimeSync();
    widget.syncService.fetchAndDecryptAll();
  }

  @override
  void dispose() {
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

  void _showAddEditItemModal([VaultItem? existingItem]) {
    final titleController = TextEditingController(text: existingItem?.title ?? '');
    final usernameController = TextEditingController(text: existingItem?.username ?? '');
    final passwordController = TextEditingController(text: existingItem?.password ?? '');
    final websiteController = TextEditingController(text: existingItem?.websiteUrl ?? '');
    final notesController = TextEditingController(text: existingItem?.notes ?? '');
    bool isFavorite = existingItem?.isFavorite ?? false;
    String category = existingItem?.category ?? 'login';
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
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
                      existingItem == null ? 'Nueva Credencial' : 'Editar Credencial',
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
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título o Servicio (Ej. GitHub, Banco, Correo)',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario / Correo Electrónico',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
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
                    labelText: 'URL del Sitio Web (Opcional)',
                    prefixIcon: Icon(Icons.link_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas Seguras (Cifradas)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
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
                            isFavorite: isFavorite,
                          )).copyWith(
                            title: titleController.text.trim(),
                            username: usernameController.text.trim(),
                            password: passwordController.text,
                            websiteUrl: websiteController.text.trim(),
                            notes: notesController.text.trim(),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Bóveda Segura'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Importar cuentas (.txt / Excel)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TxtImportScreen(syncService: widget.syncService),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar ahora',
            onPressed: () => widget.syncService.fetchAndDecryptAll(),
          ),
          IconButton(
            icon: const Icon(Icons.lock_rounded, color: Colors.redAccent),
            tooltip: 'Bloquear Bóveda (Wipe RAM)',
            onPressed: widget.onLock,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar cuentas, usuarios o servicios...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // Filtro por pestañas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'Todos', Icons.all_inbox_rounded),
                _buildFilterChip('login', 'Accesos', Icons.password_rounded),
                _buildFilterChip('favorites', 'Favoritos', Icons.star_rounded),
                _buildFilterChip('note', 'Notas', Icons.note_rounded),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de elementos de la Bóveda
          Expanded(
            child: StreamBuilder<List<VaultItem>>(
              stream: widget.syncService.vaultItemsStream,
              initialData: widget.syncService.currentItems,
              builder: (context, snapshot) {
                final allItems = snapshot.data ?? [];
                final filtered = allItems.where((item) {
                  final matchesSearch = item.title.toLowerCase().contains(_searchQuery) ||
                      item.username.toLowerCase().contains(_searchQuery) ||
                      item.websiteUrl.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_selectedCategory == 'favorites') return item.isFavorite;
                  if (_selectedCategory == 'login') return item.category == 'login';
                  if (_selectedCategory == 'note') return item.category == 'note';
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded, size: 64, color: Colors.grey.shade700),
                        const SizedBox(height: 16),
                        Text(
                          allItems.isEmpty
                              ? 'Tu bóveda está vacía.\nPresiona el botón + para agregar tu primera cuenta.'
                              : 'No se encontraron resultados para la búsqueda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.15),
                          child: Icon(
                            item.category == 'note' ? Icons.note_rounded : Icons.lock_rounded,
                            color: Colors.blueAccent,
                          ),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          item.username.isNotEmpty ? item.username : item.websiteUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        onPressed: () => _showAddEditItemModal(),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        avatar: Icon(icon, size: 16),
        onSelected: (_) => setState(() => _selectedCategory = key),
      ),
    );
  }
}
