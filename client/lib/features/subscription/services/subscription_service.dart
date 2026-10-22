import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/managed_client_account.dart';
import '../models/user_subscription_profile.dart';

/// Servicio de gestión y almacenamiento de planes y clientes asignados por el Superadmin
class SubscriptionService {
  static const String _keyAccountsJson = 'novakey_managed_accounts';
  static const String _keyNotifiedPlanPrefix = 'novakey_notified_plan_';

  // Base de datos de clientes compartida en memoria y persistida localmente
  static final List<ManagedClientAccount> _accounts = [
    ManagedClientAccount(
      id: 'USR-001',
      fullName: 'Carlos Amambal',
      email: 'carlos.amambal@tech-innova.online',
      phone: '+51 987 654 321',
      role: 'Superadmin',
      plan: NovaKeyPlan.business,
      billingCycle: 'Vitalicio',
      status: 'Activo',
      startDate: DateTime(2026, 1, 1),
      expirationDate: DateTime(2099, 12, 31),
      deviceCount: 4,
    ),
    ManagedClientAccount(
      id: 'USR-002',
      fullName: 'Soporte Tech Innova',
      email: 'tech.innova.reg@gmail.com',
      phone: '+51 980 123 456',
      role: 'Superadmin',
      plan: NovaKeyPlan.business,
      billingCycle: 'Vitalicio',
      status: 'Activo',
      startDate: DateTime(2026, 1, 15),
      expirationDate: DateTime(2099, 12, 31),
      deviceCount: 3,
    ),
    ManagedClientAccount(
      id: 'USR-003',
      fullName: 'Valerio Morales',
      email: 'valecknife@gmail.com',
      phone: '+51 945 112 233',
      role: 'Cliente',
      plan: NovaKeyPlan.pro,
      billingCycle: 'Anual',
      status: 'Activo',
      startDate: DateTime(2026, 10, 1),
      expirationDate: DateTime(2027, 10, 1),
      deviceCount: 2,
    ),
    ManagedClientAccount(
      id: 'USR-004',
      fullName: 'Estudio Jurídico Lima',
      email: 'contacto@estudiojuridico.pe',
      phone: '+51 999 888 777',
      role: 'Cliente',
      plan: NovaKeyPlan.business,
      billingCycle: 'Mensual',
      status: 'Por Vencer',
      startDate: DateTime(2026, 9, 25),
      expirationDate: DateTime(2026, 10, 25),
      deviceCount: 5,
    ),
    ManagedClientAccount(
      id: 'USR-005',
      fullName: 'Consultora Andes SAC',
      email: 'admin@consultoraandes.com',
      phone: '+51 912 345 678',
      role: 'Cliente',
      plan: NovaKeyPlan.pro,
      billingCycle: 'Mensual',
      status: 'Vencido',
      startDate: DateTime(2026, 8, 1),
      expirationDate: DateTime(2026, 9, 1),
      deviceCount: 2,
      isArchived: false,
    ),
  ];

  static List<ManagedClientAccount> get accounts => _accounts;

  /// Obtiene o auto-asigna el plan de un usuario según su correo
  static ManagedClientAccount getOrCreateAccountForEmail(String email) {
    final clean = email.trim().toLowerCase();
    for (final acc in _accounts) {
      if (acc.email.toLowerCase() == clean) {
        acc.refreshStatus();
        return acc;
      }
    }

    // Si es un usuario nuevo que se acaba de registrar en la Web o App: Asignar Plan STARTER (Gratuito)
    final bool isSuper = clean == 'tech.innova.reg@gmail.com' || clean == 'carlos.amambal@tech-innova.online';
    final newAcc = ManagedClientAccount(
      id: 'USR-00${_accounts.length + 1}',
      fullName: clean.split('@').first,
      email: clean,
      phone: 'No registrado',
      role: isSuper ? 'Superadmin' : 'Cliente',
      plan: isSuper ? NovaKeyPlan.business : NovaKeyPlan.starter,
      billingCycle: isSuper ? 'Vitalicio' : 'Vitalicio',
      status: 'Activo',
      startDate: DateTime.now(),
      expirationDate: isSuper ? DateTime(2099, 12, 31) : DateTime(2099, 12, 31),
      deviceCount: 1,
    );
    _accounts.add(newAcc);
    return newAcc;
  }

  /// Verifica si el usuario tiene una notificación pendiente de activación de plan
  static Future<String?> checkPendingUpgradeNotification(String email) async {
    final clean = email.trim().toLowerCase();
    final acc = getOrCreateAccountForEmail(clean);
    
    // Si sigue en Starter o es Superadmin no requiere anuncio de felicitación
    if (acc.plan == NovaKeyPlan.starter || acc.role == 'Superadmin') return null;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyNotifiedPlanPrefix$clean';
    final lastNotifiedPlan = prefs.getString(key);

    if (lastNotifiedPlan != acc.plan.name) {
      // Registrar que ya se le notificó sobre este plan
      await prefs.setString(key, acc.plan.name);
      return acc.plan.displayName;
    }
    return null;
  }

  /// Permite al Superadmin cambiar el plan de un usuario y forzar la notificación en su próximo login
  static Future<void> updateAccountPlan({
    required String email,
    required NovaKeyPlan newPlan,
    required String billingCycle,
    required DateTime expirationDate,
  }) async {
    final clean = email.trim().toLowerCase();
    final acc = getOrCreateAccountForEmail(clean);
    acc.plan = newPlan;
    acc.billingCycle = billingCycle;
    acc.expirationDate = expirationDate;
    acc.refreshStatus();

    // Resetear marca para que al usuario le salga el mensaje de felicitaciones al iniciar sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyNotifiedPlanPrefix$clean');
  }

  /// Elimina permanentemente una cuenta de cliente (excepto Superadmin)
  static bool deleteAccount(String id) {
    final index = _accounts.indexWhere((a) => a.id == id && a.role != 'Superadmin');
    if (index != -1) {
      _accounts.removeAt(index);
      return true;
    }
    return false;
  }

  /// Archiva o desarchiva una cuenta de cliente
  static bool toggleArchiveAccount(String id, bool archive) {
    try {
      final acc = _accounts.firstWhere((a) => a.id == id);
      if (acc.role == 'Superadmin') return false;
      acc.isArchived = archive;
      acc.refreshStatus();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Archiva en masa todas las cuentas con planes vencidos
  static int archiveAllExpiredAccounts() {
    int count = 0;
    for (final acc in _accounts) {
      if (acc.role != 'Superadmin' && acc.status == 'Vencido' && !acc.isArchived) {
        acc.isArchived = true;
        acc.refreshStatus();
        count++;
      }
    }
    return count;
  }
}
