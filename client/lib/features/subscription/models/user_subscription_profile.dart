import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

enum NovaKeyPlan {
  starter,
  pro,
  business;

  String get displayName {
    switch (this) {
      case NovaKeyPlan.starter:
        return 'Starter (Gratis)';
      case NovaKeyPlan.pro:
        return 'Pro Individual';
      case NovaKeyPlan.business:
        return 'Business / Pyme';
    }
  }

  String get badgeLabel {
    switch (this) {
      case NovaKeyPlan.starter:
        return 'PLAN GRATIS';
      case NovaKeyPlan.pro:
        return 'PLAN PRO';
      case NovaKeyPlan.business:
        return 'BUSINESS';
    }
  }

  Color get badgeColor {
    switch (this) {
      case NovaKeyPlan.starter:
        return const Color(0xFF64748B);
      case NovaKeyPlan.pro:
        return const Color(0xFF0284C7);
      case NovaKeyPlan.business:
        return const Color(0xFF8B5CF6);
    }
  }

  int get maxCredentials {
    switch (this) {
      case NovaKeyPlan.starter:
        return 30;
      case NovaKeyPlan.pro:
      case NovaKeyPlan.business:
        return 999999;
    }
  }

  int get maxPhotos {
    switch (this) {
      case NovaKeyPlan.starter:
        return 3;
      case NovaKeyPlan.pro:
      case NovaKeyPlan.business:
        return 999999;
    }
  }

  String get priceMonthlyText {
    switch (this) {
      case NovaKeyPlan.starter:
        return 'S/ 0.00 / mes';
      case NovaKeyPlan.pro:
        return 'S/ 9.90 / mes';
      case NovaKeyPlan.business:
        return 'S/ 29.90 / mes';
    }
  }

  String get priceAnnualText {
    switch (this) {
      case NovaKeyPlan.starter:
        return 'S/ 0.00 / año';
      case NovaKeyPlan.pro:
        return 'S/ 99.00 / año'; // ~S/ 8.25/mes (Ahorra 2 meses)
      case NovaKeyPlan.business:
        return 'S/ 299.00 / año'; // ~S/ 24.90/mes (Ahorra 2 meses)
    }
  }

  String get annualSavingsBadge {
    switch (this) {
      case NovaKeyPlan.starter:
        return '';
      case NovaKeyPlan.pro:
        return 'Ahorra 17% (2 meses gratis)';
      case NovaKeyPlan.business:
        return 'Ahorra 17% (2 meses gratis)';
    }
  }

  String priceText({bool isAnnual = false}) {
    return isAnnual ? priceAnnualText : priceMonthlyText;
  }
}

class UserSubscriptionProfile {
  final String email;
  final bool isSuperAdmin;
  final NovaKeyPlan plan;
  final DateTime? expiresAt;
  final bool isActive;

  UserSubscriptionProfile({
    required this.email,
    this.isSuperAdmin = false,
    this.plan = NovaKeyPlan.starter,
    this.expiresAt,
    this.isActive = true,
  });

  factory UserSubscriptionProfile.fromEmail(String email) {
    final clean = email.trim().toLowerCase();
    final account = SubscriptionService.getOrCreateAccountForEmail(clean);
    return UserSubscriptionProfile(
      email: clean,
      isSuperAdmin: account.role == 'Superadmin',
      plan: account.plan,
      expiresAt: account.expirationDate,
      isActive: account.status == 'Activo' || account.status == 'Por Vencer',
    );
  }
}
