import 'package:flutter/material.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../core/security/recovery_kit_service.dart';
import '../../auth/widgets/recovery_kit_dialog.dart';
import '../../vault/services/vault_sync_service.dart';
import '../models/user_subscription_profile.dart';
import 'plans_showcase_dialog.dart';
import 'superadmin_dashboard_dialog.dart';

/// Menú emergente de perfil de usuario en la esquina superior derecha
class UserProfileMenuButton extends StatelessWidget {
  final String userEmail;
  final VoidCallback onLock;
  final VoidCallback onChangePassword;
  final Duration currentTimeout;
  final ValueChanged<Duration>? onTimeoutChanged;
  final VaultSyncService? syncService;

  const UserProfileMenuButton({
    super.key,
    required this.userEmail,
    required this.onLock,
    required this.onChangePassword,
    required this.currentTimeout,
    this.onTimeoutChanged,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final profile = UserSubscriptionProfile.fromEmail(userEmail);
    final initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      tooltip: 'Perfil y Configuración de Cuenta',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: profile.isSuperAdmin
                ? const Color(0xFFF59E0B).withOpacity(0.6)
                : const Color(0xFF2563EB).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: profile.isSuperAdmin ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
              child: Text(
                initial,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                userEmail,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
      onSelected: (val) {
        if (val == 'plans') {
          PlansShowcaseDialog.show(context, profile);
        } else if (val == 'superadmin') {
          SuperAdminDashboardDialog.show(context, profile);
        } else if (val == 'recovery_kit') {
          _showRecoveryKit(context);
        } else if (val == 'change_password') {
          onChangePassword();
        } else if (val == 'autolock') {
          _showAutoLockPicker(context);
        } else if (val == 'logout') {
          _confirmLogout(context);
        }
      },
      itemBuilder: (context) => [
        // 1. Cabecera con datos del usuario y badge del plan
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: profile.plan.badgeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: profile.plan.badgeColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      profile.isSuperAdmin ? 'SUPERADMIN' : profile.plan.badgeLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: profile.isSuperAdmin ? const Color(0xFFF59E0B) : profile.plan.badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Multi-Dispositivo Activo',
                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),

        // 2. Planes de suscripción
        const PopupMenuItem<String>(
          value: 'plans',
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Text('Planes y Suscripción', style: TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        ),

        // 3. Panel Superadmin (Solo si es Superadmin)
        if (profile.isSuperAdmin) ...[
          const PopupMenuItem<String>(
            value: 'superadmin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 18, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Text('Panel de Superadmin', style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B))),
              ],
            ),
          ),
        ],

        // 4. Kit de Rescate de Emergencia (Zero-Knowledge)
        const PopupMenuItem<String>(
          value: 'recovery_kit',
          child: Row(
            children: [
              Icon(Icons.vpn_key_rounded, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Kit de Rescate de Emergencia', style: TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        ),

        // 5. Cambiar Contraseña Maestra
        const PopupMenuItem<String>(
          value: 'change_password',
          child: Row(
            children: [
              Icon(Icons.key_rounded, size: 18, color: Color(0xFF94A3B8)),
              SizedBox(width: 10),
              Text('Cambiar Clave Maestra', style: TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        ),

        // 6. Ajustar Autobloqueo
        const PopupMenuItem<String>(
          value: 'autolock',
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: Color(0xFF94A3B8)),
              SizedBox(width: 10),
              Text('Tiempo de Autobloqueo', style: TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        ),

        const PopupMenuDivider(height: 1),

        // 6. Cerrar Sesión / Salir
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Cerrar Sesión / Salir',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showRecoveryKit(BuildContext context) async {
    String? key = await RecoveryKitService.getSavedRecoveryKey(userEmail);
    if ((key == null || key.isEmpty) && syncService != null) {
      try {
        final newKey = RecoveryKitService.generateRecoveryKey();
        final salt = await CryptoEngine.deriveDeterministicSalt(userEmail);
        final payload = await RecoveryKitService.encryptMekForRecovery(
          masterEncryptionKey: syncService!.masterEncryptionKey,
          recoveryKey: newKey,
          salt: salt,
        );
        await RecoveryKitService.saveRecoveryData(
          email: userEmail,
          payload: payload,
          recoveryKey: newKey,
        );
        key = newKey;
      } catch (_) {}
    }

    if (context.mounted) {
      if (key == null || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró una clave de rescate guardada en este dispositivo.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await RecoveryKitDialog.show(
        context: context,
        email: userEmail,
        recoveryKey: key,
        isInitialSetup: false,
      );
    }
  }

  void _showAutoLockPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Tiempo de Autobloqueo', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeoutOption(ctx, '1 Minuto', const Duration(minutes: 1)),
            _buildTimeoutOption(ctx, '2 Minutos (Recomendado)', const Duration(minutes: 2)),
            _buildTimeoutOption(ctx, '5 Minutos', const Duration(minutes: 5)),
            _buildTimeoutOption(ctx, '15 Minutos', const Duration(minutes: 15)),
            _buildTimeoutOption(ctx, 'Nunca (Riesgoso)', const Duration(days: 365)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption(BuildContext ctx, String label, Duration duration) {
    final isSelected = currentTimeout == duration;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF38BDF8), size: 18) : null,
      onTap: () {
        if (onTimeoutChanged != null) onTimeoutChanged!(duration);
        Navigator.of(ctx).pop();
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('¿Cerrar Sesión?', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        content: const Text(
          'Al salir, las claves criptográficas maestras se purgarán de inmediato de la memoria RAM del equipo y la sesión quedará bloqueada.',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onLock();
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
