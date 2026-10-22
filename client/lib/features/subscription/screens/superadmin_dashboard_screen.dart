import 'package:flutter/material.dart';
import '../../../core/widgets/novakey_logo.dart';
import '../../vault/screens/vault_home_screen.dart';
import '../../vault/services/vault_sync_service.dart';
import '../models/managed_client_account.dart';
import '../models/user_subscription_profile.dart';
import '../services/subscription_service.dart';

/// Pantalla Completa del Tablero de Mando del Superadmin (Tech Innova)
class SuperAdminDashboardScreen extends StatefulWidget {
  final VaultSyncService syncService;
  final VoidCallback onLock;
  final Duration currentTimeout;
  final ValueChanged<Duration>? onTimeoutChanged;

  const SuperAdminDashboardScreen({
    super.key,
    required this.syncService,
    required this.onLock,
    this.currentTimeout = const Duration(minutes: 2),
    this.onTimeoutChanged,
  });

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  String _searchQuery = '';
  String _filterPlan = 'Todos';
  String _filterStatus = 'Todos';

  List<ManagedClientAccount> get _accounts => SubscriptionService.accounts;

  @override
  void initState() {
    super.initState();
    for (final acc in _accounts) {
      acc.refreshStatus();
    }
  }

  List<ManagedClientAccount> get _filteredAccounts {
    return _accounts.where((acc) {
      final matchesSearch = acc.fullName.toLowerCase().contains(_searchQuery) ||
          acc.email.toLowerCase().contains(_searchQuery) ||
          acc.phone.contains(_searchQuery) ||
          acc.id.toLowerCase().contains(_searchQuery);

      final matchesPlan = _filterPlan == 'Todos' || acc.plan.displayName.contains(_filterPlan);
      final matchesStatus = _filterStatus == 'Todos' || acc.status == _filterStatus;

      return matchesSearch && matchesPlan && matchesStatus;
    }).toList();
  }

  int get _totalClients => _accounts.where((a) => a.role != 'Superadmin').length;
  int get _activeClients => _accounts.where((a) => a.status == 'Activo' && a.role != 'Superadmin').length;
  int get _expiringClients => _accounts.where((a) => a.status == 'Por Vencer').length;
  int get _expiredClients => _accounts.where((a) => (a.status == 'Vencido' || a.status == 'Suspendido') && !a.isArchived).length;
  int get _archivedClients => _accounts.where((a) => a.isArchived || a.status == 'Archivado').length;

  double get _monthlyIncomeEst {
    double total = 0;
    for (final a in _accounts) {
      if (a.status == 'Activo' || a.status == 'Por Vencer') {
        if (a.plan == NovaKeyPlan.pro) {
          total += (a.billingCycle == 'Anual') ? (99.0 / 12) : 9.90;
        } else if (a.plan == NovaKeyPlan.business) {
          total += (a.billingCycle == 'Anual') ? (299.0 / 12) : 29.90;
        }
      }
    }
    return total;
  }

  void _openClientPersonalVault() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaultHomeScreen(
          syncService: widget.syncService,
          onLock: widget.onLock,
          currentTimeout: widget.currentTimeout,
          onTimeoutChanged: widget.onTimeoutChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAccounts;

    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Navegación Principal del Superadmin
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF101520),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const NovaKeyLogo(size: 38, showText: true),
                  const SizedBox(width: 16),
                  Container(
                    height: 36,
                    width: 1,
                    color: const Color(0xFF334155),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Panel Superadministrador',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Chip(
                            label: Text('TECH INNOVA · GLOBAL ADMIN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                            backgroundColor: Color(0xFF131D2E),
                            side: BorderSide(color: Color(0xFF1D4ED8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        'Gestión centralizada de clientes, planes comerciales, vencimientos y soporte',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Botón para acceder a su Bóveda Personal de Contraseñas
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Mi Bóveda de Contraseñas'),
                    onPressed: _openClientPersonalVault,
                  ),
                  const SizedBox(width: 12),

                  // Botón Nuevo Cliente
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _openCreateOrEditModal(context),
                  ),
                  const SizedBox(width: 14),

                  // Menú Superadmin
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de Cuenta',
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFF59E0B),
                      child: Text(
                        widget.syncService.userEmail.isNotEmpty ? widget.syncService.userEmail[0].toUpperCase() : 'S',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'vault') {
                        _openClientPersonalVault();
                      } else if (val == 'logout') {
                        widget.onLock();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(widget.syncService.userEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'vault',
                        child: Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 18, color: Color(0xFF38BDF8)),
                            SizedBox(width: 10),
                            Text('Ver Mi Bóveda Personal'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Cerrar Sesión Superadmin', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contenido Principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjetas KPI
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Clientes Totales',
                            value: '$_totalClients',
                            subtext: 'Web + Android sincronizados',
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Suscripciones Activas',
                            value: '$_activeClients',
                            subtext: 'Acceso en regla a la nube',
                            icon: Icons.verified_user_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Por Vencer (≤ 7 días)',
                            value: '$_expiringClients',
                            subtext: 'Requieren renovación',
                            icon: Icons.notification_important_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Vencidas / Sin Renovar',
                            value: '$_expiredClients',
                            subtext: 'Sincronización pausada',
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Cuentas Archivadas',
                            value: '$_archivedClients',
                            subtext: 'Planes no renovados',
                            icon: Icons.archive_outlined,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'Ingreso Estimado',
                            value: 'S/ ${_monthlyIncomeEst.toStringAsFixed(2)}',
                            subtext: 'Recurrencia mensualizada',
                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Barra de Búsqueda y Filtros
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar por cliente, correo electrónico o teléfono...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFF131823),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF1E293B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF1E293B)),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Filtro Plan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131823),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterPlan,
                              dropdownColor: const Color(0xFF161F30),
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              items: ['Todos', 'Starter', 'Pro', 'Business'].map((p) {
                                return DropdownMenuItem(value: p, child: Text('Plan: $p'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _filterPlan = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filtro Estado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131823),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterStatus,
                              dropdownColor: const Color(0xFF161F30),
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              items: ['Todos', 'Activo', 'Por Vencer', 'Vencido', 'Archivado', 'Suspendido'].map((s) {
                                return DropdownMenuItem(value: s, child: Text('Estado: $s'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _filterStatus = val);
                              },
                            ),
                          ),
                        ),
                        if (_expiredClients > 0) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: const Icon(Icons.inventory_2_outlined, size: 16),
                            label: Text('Archivar Vencidos ($_expiredClients)'),
                            onPressed: _confirmArchiveAllExpired,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Tabla de Clientes
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111520),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Center(
                                  child: Text('No se encontraron clientes registrados.', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(const Color(0xFF161C2C)),
                                  dataRowHeight: 60,
                                  columns: const [
                                    DataColumn(label: Text('CLIENTE / ID')),
                                    DataColumn(label: Text('CORREO & TELÉFONO')),
                                    DataColumn(label: Text('PLAN ASIGNADO')),
                                    DataColumn(label: Text('FECHA INICIO')),
                                    DataColumn(label: Text('VENCIMIENTO / DÍAS')),
                                    DataColumn(label: Text('ESTADO')),
                                    DataColumn(label: Text('ACCIONES ADMINISTRATIVAS')),
                                  ],
                                  rows: filtered.map((acc) => _buildDataRow(acc)).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Corporativo Tech Innova
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0C101A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  // Logotipo oficial de Tech Innova
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Image.asset(
                      'assets/images/logo_TI.png',
                      height: 26,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'TECH INNOVA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(height: 24, width: 1, color: const Color(0xFF334155)),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Desarrollado y Administrado por Tech Innova · Software & Ciberseguridad',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0)),
                      ),
                      Text(
                        'Contacto Comercial & Activaciones: +51 947 515 529 · tech.innova.reg@gmail.com',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'Zero-Knowledge Platform Enterprise',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '© ${DateTime.now().year} Tech Innova. Todos los derechos reservados.',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  DataRow _buildDataRow(ManagedClientAccount acc) {
    Color statusColor;
    switch (acc.status) {
      case 'Activo':
        statusColor = const Color(0xFF10B981);
        break;
      case 'Por Vencer':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Archivado':
        statusColor = const Color(0xFF64748B);
        break;
      default:
        statusColor = const Color(0xFFEF4444);
    }

    final isPermanent = acc.billingCycle == 'Vitalicio' || acc.plan == NovaKeyPlan.starter;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: acc.role == 'Superadmin'
                    ? const Color(0xFFF59E0B)
                    : (acc.isArchived ? const Color(0xFF475569) : const Color(0xFF2563EB)),
                child: Text(acc.fullName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(acc.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  Text(acc.id, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(acc.email, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
              Text(acc.phone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: acc.plan.badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: acc.plan.badgeColor.withOpacity(0.6)),
                ),
                child: Text(acc.plan.badgeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: acc.plan.badgeColor)),
              ),
              const SizedBox(width: 8),
              Text(acc.billingCycle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        DataCell(
          Text('${acc.startDate.day.toString().padLeft(2, '0')}/${acc.startDate.month.toString().padLeft(2, '0')}/${acc.startDate.year}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isPermanent
                    ? 'Ilimitado / Vitalicio'
                    : '${acc.expirationDate.day.toString().padLeft(2, '0')}/${acc.expirationDate.month.toString().padLeft(2, '0')}/${acc.expirationDate.year}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPermanent ? const Color(0xFF38BDF8) : (acc.isArchived ? const Color(0xFF94A3B8) : Colors.white),
                ),
              ),
              if (!isPermanent)
                Text(
                  acc.isArchived
                      ? 'Archivada (Inactiva)'
                      : (acc.daysRemaining >= 0 ? '${acc.daysRemaining} días restantes' : 'Vencido'),
                  style: TextStyle(
                    fontSize: 10,
                    color: acc.isArchived
                        ? const Color(0xFF94A3B8)
                        : (acc.daysRemaining <= 7 ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (acc.isArchived) ...[
                  const Icon(Icons.archive_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                ],
                Text(acc.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF38BDF8)),
                tooltip: 'Asignar / Cambiar Plan',
                onPressed: () => _openCreateOrEditModal(context, existingAccount: acc),
              ),
              IconButton(
                icon: const Icon(Icons.more_time_rounded, size: 18, color: Color(0xFF10B981)),
                tooltip: 'Ampliar Contrato (+1 Mes o +1 Año)',
                onPressed: () => _openExtendContractModal(context, acc),
              ),
              IconButton(
                icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFFF59E0B)),
                tooltip: 'Restablecer Contraseña (PIN)',
                onPressed: () => _confirmPasswordReset(acc),
              ),
              if (acc.role != 'Superadmin') ...[
                IconButton(
                  icon: Icon(
                    acc.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    size: 18,
                    color: acc.isArchived ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                  ),
                  tooltip: acc.isArchived ? 'Desarchivar Cuenta' : 'Archivar Cuenta (Plan Vencido)',
                  onPressed: () => _confirmToggleArchive(acc),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Eliminar Cuenta Definitivamente',
                  onPressed: () => _confirmDeleteAccount(acc),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openCreateOrEditModal(BuildContext context, {ManagedClientAccount? existingAccount}) {
    final nameCtrl = TextEditingController(text: existingAccount?.fullName ?? '');
    final emailCtrl = TextEditingController(text: existingAccount?.email ?? '');
    final phoneCtrl = TextEditingController(text: existingAccount?.phone ?? '');
    NovaKeyPlan selectedPlan = existingAccount?.plan ?? NovaKeyPlan.pro;
    String selectedCycle = existingAccount?.billingCycle ?? 'Mensual';

    DateTime calculatedExpiration = existingAccount?.expirationDate ??
        ManagedClientAccount.calculateExpiration(DateTime.now(), selectedCycle, selectedPlan);

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF11141A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existingAccount == null ? 'Aprovisionar Cliente' : 'Cambiar Plan de ${existingAccount.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre Completo / Razón Social', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<NovaKeyPlan>(
                          value: selectedPlan,
                          decoration: const InputDecoration(labelText: 'Plan', border: OutlineInputBorder()),
                          items: NovaKeyPlan.values.map((p) => DropdownMenuItem(value: p, child: Text(p.displayName, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedPlan = val;
                                calculatedExpiration = ManagedClientAccount.calculateExpiration(existingAccount?.startDate ?? DateTime.now(), selectedCycle, selectedPlan);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCycle,
                          decoration: const InputDecoration(labelText: 'Ciclo', border: OutlineInputBorder()),
                          items: ['Mensual', 'Anual', 'Vitalicio'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedCycle = val;
                                calculatedExpiration = ManagedClientAccount.calculateExpiration(existingAccount?.startDate ?? DateTime.now(), selectedCycle, selectedPlan);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vencimiento Calculado:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              Text((selectedPlan == NovaKeyPlan.starter || selectedCycle == 'Vitalicio') ? 'Acceso Vitalicio' : '${calculatedExpiration.day}/${calculatedExpiration.month}/${calculatedExpiration.year}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dlgCtx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final email = emailCtrl.text.trim().toLowerCase();
                if (existingAccount != null) {
                  await SubscriptionService.updateAccountPlan(
                    email: email,
                    newPlan: selectedPlan,
                    billingCycle: selectedCycle,
                    expirationDate: calculatedExpiration,
                  );
                  existingAccount.fullName = nameCtrl.text.trim();
                  existingAccount.phone = phoneCtrl.text.trim();
                } else {
                  final newAcc = ManagedClientAccount(
                    id: 'USR-00${_accounts.length + 1}',
                    fullName: nameCtrl.text.trim(),
                    email: email,
                    phone: phoneCtrl.text.trim(),
                    role: 'Cliente',
                    plan: selectedPlan,
                    billingCycle: selectedCycle,
                    status: 'Activo',
                    startDate: DateTime.now(),
                    expirationDate: calculatedExpiration,
                  );
                  _accounts.add(newAcc);
                }
                setState(() {});
                Navigator.of(dlgCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Plan y cliente actualizados. Al usuario le saldrá la felicitación en su próximo login.')),
                );
              },
              child: const Text('Guardar y Activar Plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _openExtendContractModal(BuildContext context, ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        title: Text('Ampliar Contrato: ${acc.fullName}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              tileColor: const Color(0xFF18202F),
              title: const Text('+1 Mes Adicional', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF38BDF8)),
              onTap: () {
                setState(() => acc.extendContract(months: 1));
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: const Color(0xFF18202F),
              title: const Text('+1 Año (2 Meses Gratis)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
              onTap: () {
                setState(() => acc.extendContract(years: 1));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPasswordReset(ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        title: const Text('Restablecer Acceso', style: TextStyle(color: Colors.white)),
        content: Text('Se despachará un código PIN de verificación a ${acc.email} para autorizar su cambio de contraseña.', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🔑 Código PIN despachado al correo de ${acc.fullName}.')),
              );
            },
            child: const Text('Enviar PIN al Correo'),
          ),
        ],
      ),
    );
  }

  void _confirmToggleArchive(ManagedClientAccount acc) {
    final willArchive = !acc.isArchived;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Icon(
              willArchive ? Icons.archive_outlined : Icons.unarchive_outlined,
              color: willArchive ? const Color(0xFF94A3B8) : const Color(0xFF38BDF8),
            ),
            const SizedBox(width: 10),
            Text(
              willArchive ? '¿Archivar Cuenta?' : '¿Desarchivar Cuenta?',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          willArchive
              ? 'La cuenta de ${acc.fullName} (${acc.email}) pasará al archivo histórico por no haber renovado su plan. El usuario no podrá sincronizar nuevos registros en la nube hasta que renueve su plan con Tech Innova.'
              : '¿Deseas restaurar la cuenta de ${acc.fullName}? Volverá a la lista activa de clientes con su estado regular de suscripción.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willArchive ? const Color(0xFF334155) : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                SubscriptionService.toggleArchiveAccount(acc.id, willArchive);
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(willArchive ? '📦 Cuenta archivada con éxito.' : '✅ Cuenta desarchivada con éxito.'),
                ),
              );
            },
            child: Text(willArchive ? 'Archivar Cuenta' : 'Desarchivar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('¿Eliminar Cuenta Definitivamente?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de eliminar permanentemente a:\n• ${acc.fullName}\n• ${acc.email} (${acc.id})',
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción es irreversible y borrará el registro del cliente y sus asignaciones de licencia.',
                      style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                SubscriptionService.deleteAccount(acc.id);
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ Cuenta de ${acc.fullName} eliminada permanentemente.'),
                  backgroundColor: const Color(0xFFB91C1C),
                ),
              );
            },
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );
  }

  void _confirmArchiveAllExpired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Archivar Cuentas Vencidas', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Se archivarán todas las cuentas ($_expiredClients) cuyos planes ya expiraron y no han sido renovados.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final count = SubscriptionService.archiveAllExpiredAccounts();
              setState(() {});
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📦 Se archivaron $count cuentas vencidas con éxito.')),
              );
            },
            child: const Text('Confirmar Archivado Masivo'),
          ),
        ],
      ),
    );
  }
}
