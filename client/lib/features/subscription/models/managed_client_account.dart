import 'package:flutter/material.dart';
import '../models/user_subscription_profile.dart';

/// Modelo de datos para la gestión administrativa de cuentas en NovaKey
class ManagedClientAccount {
  final String id;
  String fullName;
  String email;
  String phone;
  String role; // 'Superadmin' | 'Cliente'
  NovaKeyPlan plan;
  String billingCycle; // 'Mensual' | 'Anual' | 'Vitalicio'
  String status; // 'Activo' | 'Por Vencer' | 'Vencido' | 'Suspendido'
  DateTime startDate;
  DateTime expirationDate;
  int deviceCount;
  bool isArchived;
  bool hasPendingUpgradeCelebration;

  ManagedClientAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.role = 'Cliente',
    required this.plan,
    required this.billingCycle,
    required this.status,
    required this.startDate,
    required this.expirationDate,
    this.deviceCount = 2,
    this.isArchived = false,
    this.hasPendingUpgradeCelebration = false,
  });

  /// Calcula automáticamente la fecha de vencimiento según el ciclo de facturación
  static DateTime calculateExpiration(DateTime fromDate, String cycle, NovaKeyPlan plan) {
    if (plan == NovaKeyPlan.starter || cycle == 'Vitalicio') {
      return DateTime(2099, 12, 31);
    }
    if (cycle == 'Anual') {
      return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
    // Mensual
    return DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
  }

  /// Calcula los días restantes para el vencimiento
  int get daysRemaining {
    if (plan == NovaKeyPlan.starter || billingCycle == 'Vitalicio') return 9999;
    return expirationDate.difference(DateTime.now()).inDays;
  }

  /// Actualiza automáticamente el estado según los días restantes y si está archivado
  void refreshStatus() {
    if (isArchived) {
      status = 'Archivado';
      return;
    }
    if (plan == NovaKeyPlan.starter || billingCycle == 'Vitalicio') {
      status = 'Activo';
      return;
    }
    final remaining = daysRemaining;
    if (remaining < 0) {
      status = 'Vencido';
    } else if (remaining <= 7) {
      status = 'Por Vencer';
    } else {
      status = 'Activo';
    }
  }

  /// Extiende el contrato en meses o años adicionales y desarchiva automáticamente
  void extendContract({int months = 1, int years = 0}) {
    isArchived = false;
    hasPendingUpgradeCelebration = true;
    DateTime base = expirationDate.isAfter(DateTime.now()) ? expirationDate : DateTime.now();
    if (years > 0) {
      expirationDate = DateTime(base.year + years, base.month, base.day);
    } else {
      expirationDate = DateTime(base.year, base.month + months, base.day);
    }
    refreshStatus();
  }
}
