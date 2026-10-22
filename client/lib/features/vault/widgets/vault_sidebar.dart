import 'package:flutter/material.dart';
import '../../../core/widgets/novakey_logo.dart';
import '../models/vault_category.dart';
import 'tech_innova_credits.dart';

/// Barra lateral izquierda para navegación de categorías, herramientas y créditos
class VaultSidebar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final Map<String, int> counts;
  final List<VaultCategory> categories;
  final VoidCallback onAddNewItem;
  final VoidCallback onAddCategory;
  final ValueChanged<String>? onDeleteCategory;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onSync;
  final VoidCallback onOpenPasswordGenerator;
  final VoidCallback? onChangePassword;
  final VoidCallback onLock;
  final Duration currentTimeout;
  final ValueChanged<Duration>? onTimeoutChanged;
  final bool isDrawer;

  const VaultSidebar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.counts,
    required this.categories,
    required this.onAddNewItem,
    required this.onAddCategory,
    this.onDeleteCategory,
    required this.onImport,
    required this.onExport,
    required this.onSync,
    required this.onOpenPasswordGenerator,
    this.onChangePassword,
    required this.onLock,
    required this.currentTimeout,
    this.onTimeoutChanged,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    const bgSidebar = Color(0xFF131720);
    const borderColor = Color(0xFF1F2937);

    return Container(
      width: isDrawer ? null : 270,
      decoration: BoxDecoration(
        color: bgSidebar,
        border: isDrawer
            ? null
            : const Border(
                right: BorderSide(color: borderColor, width: 1),
              ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera: Logo e Isologo NovaKey
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NovaKeyLogo(size: 38),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF1D4ED8).withOpacity(0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFF38BDF8)),
                        SizedBox(width: 5),
                        Text(
                          'Cifrado Zero-Knowledge AES-256',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Botón Principal: + Agregar Credencial
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Nueva Credencial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  if (isDrawer) Navigator.of(context).pop();
                  onAddNewItem();
                },
              ),
            ),

            const SizedBox(height: 10),

            // Lista Scrolleable: Categorías y Herramientas
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 6, top: 4),
                    child: Text(
                      'VISTAS RÁPIDAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  // Botones de Navegación Rápida
                  _buildNavItem(
                    id: 'all',
                    title: 'Todos los Registros',
                    icon: Icons.all_inbox_rounded,
                    count: counts['all'] ?? 0,
                  ),
                  _buildNavItem(
                    id: 'favorites',
                    title: 'Favoritos',
                    icon: Icons.star_rounded,
                    count: counts['favorites'] ?? 0,
                  ),

                  const SizedBox(height: 10),
                  const Divider(color: borderColor, height: 1),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4, bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CATEGORÍAS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        InkWell(
                          onTap: onAddCategory,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF38BDF8)),
                                SizedBox(width: 4),
                                Text(
                                  'Nueva',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Categorías Dinámicas y Personalizadas
                  ...categories.map((cat) => _buildNavItem(
                        id: cat.id,
                        title: cat.name,
                        icon: cat.icon,
                        count: counts[cat.id] ?? 0,
                        onDelete: !cat.isSystem && onDeleteCategory != null
                            ? () => onDeleteCategory!(cat.id)
                            : null,
                      )),

                  const SizedBox(height: 14),
                  const Divider(color: borderColor, height: 1),
                  const SizedBox(height: 10),

                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 6),
                    child: Text(
                      'HERRAMIENTAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  _buildToolItem(
                    title: 'Importar (.txt / Excel)',
                    icon: Icons.file_upload_outlined,
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      onImport();
                    },
                  ),
                  _buildToolItem(
                    title: 'Generar Clave Segura',
                    icon: Icons.auto_awesome_rounded,
                    iconColor: Colors.amberAccent,
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      onOpenPasswordGenerator();
                    },
                  ),
                  if (onChangePassword != null)
                    _buildToolItem(
                      title: 'Cambiar Clave Maestra',
                      icon: Icons.password_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      onTap: () {
                        if (isDrawer) Navigator.of(context).pop();
                        onChangePassword!();
                      },
                    ),
                  _buildToolItem(
                    title: 'Exportar Respaldo JSON',
                    icon: Icons.download_rounded,
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      onExport();
                    },
                  ),
                  _buildToolItem(
                    title: 'Sincronizar ahora',
                    icon: Icons.sync_rounded,
                    onTap: onSync,
                  ),
                ],
              ),
            ),

            // Pie de la Barra Lateral: Créditos Tech Innova y Bloqueo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: borderColor, width: 1)),
                color: Color(0xFF0F1219),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tarjeta de Créditos Tech Innova con enlace directo a tech-innova.online
                  const TechInnovaCredits(),

                  const SizedBox(height: 10),

                  // Fila de Controles: Tiempo de Auto-bloqueo y Botón Bloquear
                  Row(
                    children: [
                      // Selector de tiempo
                      Expanded(
                        child: PopupMenuButton<int>(
                          tooltip: 'Tiempo de inactividad',
                          initialValue: currentTimeout.inSeconds,
                          onSelected: (sec) {
                            onTimeoutChanged?.call(Duration(seconds: sec));
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 60, child: Text('1 minuto')),
                            const PopupMenuItem(value: 120, child: Text('2 minutos (Normal)')),
                            const PopupMenuItem(value: 300, child: Text('5 minutos')),
                            const PopupMenuItem(value: 900, child: Text('15 minutos')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2430),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 5),
                                Text(
                                  currentTimeout.inSeconds < 60
                                      ? '${currentTimeout.inSeconds}s'
                                      : '${currentTimeout.inMinutes}m',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón Bloquear
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red.withOpacity(0.3)),
                          ),
                        ),
                        icon: const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 18),
                        tooltip: 'Bloquear Bóveda (Wipe RAM)',
                        onPressed: onLock,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String id,
    required String title,
    required IconData icon,
    required int count,
    VoidCallback? onDelete,
  }) {
    final isSelected = selectedCategory == id;
    const activeColor = Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1D4ED8).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(
          icon,
          size: 19,
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                ),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () => onCategorySelected(id),
      ),
    );
  }

  Widget _buildToolItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(icon, size: 18, color: iconColor ?? const Color(0xFF64748B)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
