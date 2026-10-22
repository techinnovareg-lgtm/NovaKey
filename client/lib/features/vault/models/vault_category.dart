import 'package:flutter/material.dart';

/// Modelo de categoría de credenciales en NovaKey
class VaultCategory {
  final String id;
  final String name;
  final IconData icon;
  final bool isSystem;

  const VaultCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.isSystem = false,
  });

  /// Categorías predefinidas del sistema
  static const List<VaultCategory> defaultCategories = [
    VaultCategory(
      id: 'bancos',
      name: 'Bancos y Finanzas',
      icon: Icons.account_balance_rounded,
      isSystem: true,
    ),
    VaultCategory(
      id: 'correo',
      name: 'Correos y Cuentas',
      icon: Icons.mail_lock_rounded,
      isSystem: true,
    ),
    VaultCategory(
      id: 'tiendas',
      name: 'Tiendas por Departamento',
      icon: Icons.shopping_bag_rounded,
      isSystem: true,
    ),
    VaultCategory(
      id: 'device',
      name: 'Dispositivos y Módems',
      icon: Icons.router_rounded,
      isSystem: true,
    ),
    VaultCategory(
      id: 'note',
      name: 'Notas Seguras',
      icon: Icons.note_alt_rounded,
      isSystem: true,
    ),
  ];

  /// Deduce un ícono visual e intuitivo para cualquier categoría según su nombre
  static IconData getIconForName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower == 'all' || lower.contains('todo')) {
      return Icons.all_inbox_rounded;
    }
    if (lower == 'favorites' || lower.contains('favorit')) {
      return Icons.star_rounded;
    }
    if (lower.contains('banc') || lower.contains('finan') || lower.contains('tarjet') || lower.contains('dinero') || lower.contains('pago') || lower.contains('credito') || lower.contains('débito')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('tiend') || lower.contains('compr') || lower.contains('departamento') || lower.contains('shop') || lower.contains('retail') || lower.contains('market') || lower.contains('mall') || lower.contains('saga') || lower.contains('ripley')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('corr') || lower.contains('email') || lower.contains('mail') || lower.contains('gmail') || lower.contains('outlook') || lower.contains('login') || lower.contains('acceso') || lower.contains('cuenta')) {
      return Icons.mail_lock_rounded;
    }
    if (lower.contains('disp') || lower.contains('modem') || lower.contains('módem') || lower.contains('router') || lower.contains('cam') || lower.contains('cámara') || lower.contains('device') || lower.contains('red') || lower.contains('wifi') || lower.contains('switch')) {
      return Icons.router_rounded;
    }
    if (lower.contains('not') || lower.contains('apunt') || lower.contains('secret') || lower.contains('memo')) {
      return Icons.note_alt_rounded;
    }
    if (lower.contains('stream') || lower.contains('tv') || lower.contains('video') || lower.contains('pelicul') || lower.contains('music') || lower.contains('netflix') || lower.contains('spotify') || lower.contains('youtube') || lower.contains('cine')) {
      return Icons.live_tv_rounded;
    }
    if (lower.contains('trabaj') || lower.contains('oficin') || lower.contains('job') || lower.contains('empresa') || lower.contains('instituc') || lower.contains('laboral')) {
      return Icons.business_center_rounded;
    }
    if (lower.contains('serv') || lower.contains('cloud') || lower.contains('vps') || lower.contains('host') || lower.contains('base de datos') || lower.contains('sql') || lower.contains('aws') || lower.contains('azure')) {
      return Icons.dns_rounded;
    }
    if (lower.contains('social') || lower.contains('redes') || lower.contains('chat') || lower.contains('facebook') || lower.contains('instagram') || lower.contains('whatsapp') || lower.contains('tiktok')) {
      return Icons.forum_rounded;
    }
    if (lower.contains('salud') || lower.contains('medic') || lower.contains('hosp') || lower.contains('seguro') || lower.contains('clinica')) {
      return Icons.medical_services_rounded;
    }
    if (lower.contains('educ') || lower.contains('univ') || lower.contains('coleg') || lower.contains('curso') || lower.contains('estudio')) {
      return Icons.school_rounded;
    }
    if (lower.contains('jueg') || lower.contains('game') || lower.contains('steam') || lower.contains('play') || lower.contains('xbox')) {
      return Icons.sports_esports_rounded;
    }
    return Icons.folder_rounded;
  }
}
