import 'package:flutter/material.dart';
import '../models/managed_client_account.dart';
import '../models/user_subscription_profile.dart';

/// Tablero de Mando Central del Superadmin (Dashboard de Gestión de Clientes, Planes y Suscripciones)
class SuperAdminDashboardDialog extends StatefulWidget {
  final UserSubscriptionProfile currentUser;

  const SuperAdminDashboardDialog({super.key, required this.currentUser});

  static Future<void> show(BuildContext context, UserSubscriptionProfile currentUser) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SuperAdminDashboardDialog(currentUser: currentUser),
    );
  }

  @override
  State<SuperAdminDashboardDialog> createState() => _SuperAdminDashboardDialogState();
}

class _SuperAdminDashboardDialogState extends State<SuperAdminDashboardDialog> {
  String _searchQuery = '';
  String _filterPlan = 'Todos';
  String _filterStatus = 'Todos';

  // Base de datos de clientes en memoria gestionados por Tech Innova
  final List<ManagedClientAccount> _accounts = [
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
      fullName: 'Ana María Quispe',
      email: 'ana.quispe@gmail.com',
      phone: '+51 912 345 678',
      role: 'Cliente',
      plan: NovaKeyPlan.pro,
      billingCycle: 'Mensual',
      status: 'Vencido',
      startDate: DateTime(2026, 8, 10),
      expirationDate: DateTime(2026, 9, 10),
      deviceCount: 1,
    ),
    ManagedClientAccount(
      id: 'USR-006',
      fullName: 'Roberto Mendoza',
      email: 'roberto.m@empresa.com',
      phone: '+51 933 221 100',
      role: 'Cliente',
      plan: NovaKeyPlan.starter,
      billingCycle: 'Vitalicio',
      status: 'Activo',
      startDate: DateTime(2026, 10, 5),
      expirationDate: DateTime(2099, 12, 31),
      deviceCount: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Actualizar estados automáticos según fechas
    for (final acc in _accounts) {
      acc.refreshStatus();
    }
  }

  // Filtrado reactivo de clientes
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

  // Métricas para los KPIs del Tablero
  int get _totalClients => _accounts.where((a) => a.role != 'Superadmin').length;
  int get _activeClients => _accounts.where((a) => a.status == 'Activo' && a.role != 'Superadmin').length;
  int get _expiringClients => _accounts.where((a) => a.status == 'Por Vencer').length;
  int get _expiredClients => _accounts.where((a) => a.status == 'Vencido' || a.status == 'Suspendido').length;

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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAccounts;

    return Dialog(
      backgroundColor: const Color(0xFF0B0F17),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Encabezado del Tablero de Mando
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Tablero de Mando Superadmin',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 10),
                            Chip(
                              label: Text('TECH INNOVA · CORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                              backgroundColor: Color(0xFF231E12),
                              side: BorderSide(color: Color(0xFF78350F)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        Text(
                          'Control central de clientes, licencias, cálculo de vencimientos y operaciones de contratos',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _openCreateOrEditModal(context),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    tooltip: 'Cerrar Tablero',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Tarjetas KPI de Estado Rápido
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
                      title: 'Vencidas / Suspendidas',
                      value: '$_expiredClients',
                      subtext: 'Sincronización pausada',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFEF4444),
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

              const SizedBox(height: 20),

              // 3. Barra de Búsqueda y Filtros Rápidos
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, correo, teléfono o ID de cliente...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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
                  const SizedBox(width: 12),
                  // Filtro por Plan
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
                  const SizedBox(width: 10),
                  // Filtro por Estado
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
                        items: ['Todos', 'Activo', 'Por Vencer', 'Vencido', 'Suspendido'].map((s) {
                          return DropdownMenuItem(value: s, child: Text('Estado: $s'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _filterStatus = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. Tabla de Datos / DataGrid de Clientes
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron usuarios bajo los criterios de búsqueda.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(const Color(0xFF18202F)),
                                dataRowHeight: 56,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                  letterSpacing: 0.5,
                                ),
                                columns: const [
                                  DataColumn(label: Text('CLIENTE / ID')),
                                  DataColumn(label: Text('CORREO & CONTACTO')),
                                  DataColumn(label: Text('PLAN & CICLO')),
                                  DataColumn(label: Text('FECHA INICIO')),
                                  DataColumn(label: Text('VENCIMIENTO / DÍAS')),
                                  DataColumn(label: Text('ESTADO')),
                                  DataColumn(label: Text('ACCIONES')),
                                ],
                                rows: filtered.map((account) {
                                  return _buildDataRow(account);
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 5. Pie de Página del Tablero
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mostrando ${filtered.length} de ${_accounts.length} cuentas registradas en el sistema.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Actualizar Fechas'),
                        onPressed: () {
                          setState(() {
                            for (final a in _accounts) {
                              a.refreshStatus();
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vencimientos y estados recalculados.')),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
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
      case 'Vencido':
      case 'Suspendido':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = Colors.grey;
    }

    final isPermanent = acc.billingCycle == 'Vitalicio' || acc.plan == NovaKeyPlan.starter;

    return DataRow(
      cells: [
        // Cliente / ID
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: acc.role == 'Superadmin' ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                child: Text(
                  acc.fullName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(acc.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(acc.id, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),

        // Correo & Teléfono
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(acc.email, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
              Text(acc.phone, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ),

        // Plan & Ciclo
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: acc.plan.badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: acc.plan.badgeColor.withOpacity(0.6)),
                ),
                child: Text(
                  acc.plan.badgeLabel,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: acc.plan.badgeColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(acc.billingCycle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),

        // Fecha Inicio
        DataCell(
          Text(
            '${acc.startDate.day.toString().padLeft(2, '0')}/${acc.startDate.month.toString().padLeft(2, '0')}/${acc.startDate.year}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ),

        // Vencimiento / Días Restantes
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isPermanent ? 'Ilimitado' : '${acc.expirationDate.day.toString().padLeft(2, '0')}/${acc.expirationDate.month.toString().padLeft(2, '0')}/${acc.expirationDate.year}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPermanent ? const Color(0xFF38BDF8) : Colors.white),
              ),
              if (!isPermanent)
                Text(
                  acc.daysRemaining >= 0 ? '${acc.daysRemaining} días restantes' : 'Vencido hace ${acc.daysRemaining.abs()} días',
                  style: TextStyle(fontSize: 10, color: acc.daysRemaining <= 7 ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                ),
            ],
          ),
        ),

        // Estado
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
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                ),
                const SizedBox(width: 6),
                Text(
                  acc.status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
        ),

        // Acciones CRUD
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF38BDF8)),
                tooltip: 'Editar Datos y Plan',
                onPressed: () => _openCreateOrEditModal(context, existingAccount: acc),
              ),
              IconButton(
                icon: const Icon(Icons.more_time_rounded, size: 18, color: Color(0xFF10B981)),
                tooltip: 'Ampliar Contrato (+1 Mes o +1 Año)',
                onPressed: () => _openExtendContractModal(context, acc),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'reset_password') {
                    _confirmPasswordReset(acc);
                  } else if (val == 'toggle_status') {
                    setState(() {
                      acc.status = acc.status == 'Activo' ? 'Suspendido' : 'Activo';
                    });
                  } else if (val == 'delete') {
                    _confirmDelete(acc);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Text('Enviar PIN de Restablecimiento'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(acc.status == 'Activo' ? 'Suspender Acceso Nube' : 'Reactivar Acceso'),
                      ],
                    ),
                  ),
                  if (acc.role != 'Superadmin')
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Eliminar Cuenta', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Diálogo para Crear o Editar Cliente (Cálculo automático de vencimiento)
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937)),
          ),
          title: Row(
            children: [
              Icon(existingAccount == null ? Icons.person_add_alt_1_rounded : Icons.edit_note_rounded, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 10),
              Text(
                existingAccount == null ? 'Aprovisionar Nuevo Cliente' : 'Editar Cliente & Suscripción',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo / Razón Social',
                      prefixIcon: Icon(Icons.business_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico (Login)',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de Contacto',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<NovaKeyPlan>(
                          value: selectedPlan,
                          decoration: const InputDecoration(labelText: 'Plan', border: OutlineInputBorder()),
                          items: NovaKeyPlan.values.map((p) {
                            return DropdownMenuItem(value: p, child: Text(p.displayName, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedPlan = val;
                                calculatedExpiration = ManagedClientAccount.calculateExpiration(
                                  existingAccount?.startDate ?? DateTime.now(),
                                  selectedCycle,
                                  selectedPlan,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCycle,
                          decoration: const InputDecoration(labelText: 'Ciclo Facturación', border: OutlineInputBorder()),
                          items: ['Mensual', 'Anual', 'Vitalicio'].map((c) {
                            return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedCycle = val;
                                calculatedExpiration = ManagedClientAccount.calculateExpiration(
                                  existingAccount?.startDate ?? DateTime.now(),
                                  selectedCycle,
                                  selectedPlan,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Caja informativa de cálculo automático de vencimiento
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fecha de Vencimiento Calculada:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              Text(
                                (selectedPlan == NovaKeyPlan.starter || selectedCycle == 'Vitalicio')
                                    ? 'Acceso Vitalicio / Sin Caducidad'
                                    : '${calculatedExpiration.day}/${calculatedExpiration.month}/${calculatedExpiration.year}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
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
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim().toLowerCase();
                final phone = phoneCtrl.text.trim();

                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa el nombre y correo del cliente.')),
                  );
                  return;
                }

                setState(() {
                  if (existingAccount != null) {
                    existingAccount.fullName = name;
                    existingAccount.email = email;
                    existingAccount.phone = phone;
                    existingAccount.plan = selectedPlan;
                    existingAccount.billingCycle = selectedCycle;
                    existingAccount.expirationDate = calculatedExpiration;
                    existingAccount.refreshStatus();
                  } else {
                    final newAcc = ManagedClientAccount(
                      id: 'USR-00${_accounts.length + 1}',
                      fullName: name,
                      email: email,
                      phone: phone.isNotEmpty ? phone : 'No registrado',
                      role: 'Cliente',
                      plan: selectedPlan,
                      billingCycle: selectedCycle,
                      status: 'Activo',
                      startDate: DateTime.now(),
                      expirationDate: calculatedExpiration,
                      deviceCount: 2,
                    );
                    _accounts.add(newAcc);
                  }
                });

                Navigator.of(dlgCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(existingAccount != null ? '✅ Datos actualizados con éxito.' : '✅ Cliente aprovisionado con éxito.'),
                    backgroundColor: Colors.green.shade800,
                  ),
                );
              },
              child: Text(existingAccount == null ? 'Aprovisionar' : 'Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  // Modal para Ampliar Contrato (Renovación Rápida)
  void _openExtendContractModal(BuildContext context, ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.more_time_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text('Ampliar Contrato: ${acc.fullName}', style: const TextStyle(fontSize: 15, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vencimiento actual: ${acc.expirationDate.day}/${acc.expirationDate.month}/${acc.expirationDate.year}', style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            const Text('Selecciona el periodo a renovar:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            ListTile(
              tileColor: const Color(0xFF18202F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: const Text('+1 Mes Adicional', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF38BDF8)),
              onTap: () {
                setState(() => acc.extendContract(months: 1));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Contrato ampliado 1 mes hasta ${acc.expirationDate.day}/${acc.expirationDate.month}/${acc.expirationDate.year}')),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: const Color(0xFF18202F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: const Text('+1 Año Completo (2 meses gratis)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Aplica tarifa anual con descuento', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
              onTap: () {
                setState(() => acc.extendContract(years: 1));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Contrato ampliado 1 año hasta ${acc.expirationDate.day}/${acc.expirationDate.month}/${acc.expirationDate.year}')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  // Confirmar Restablecimiento de Contraseña para el Usuario
  void _confirmPasswordReset(ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Restablecer Acceso de Usuario', style: TextStyle(fontSize: 15, color: Colors.white)),
          ],
        ),
        content: Text(
          'Se emitirá un código PIN de seguridad de un solo uso hacia el correo registrado: ${acc.email} para que el cliente pueda definir una nueva contraseña.',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔑 Código PIN de recuperación despachado exitosamente a ${acc.email}.'),
                  backgroundColor: Colors.amber.shade900,
                ),
              );
            },
            child: const Text('Enviar PIN al Correo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Eliminar Cuenta
  void _confirmDelete(ManagedClientAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11141A),
        title: const Text('¿Eliminar cuenta de cliente?', style: TextStyle(color: Colors.white)),
        content: Text('Se revocará el acceso de ${acc.fullName} (${acc.email}) y sus dispositivos vinculados.', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _accounts.remove(acc));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cuenta eliminada del sistema.')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
