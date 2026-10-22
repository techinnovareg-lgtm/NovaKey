import 'package:flutter/material.dart';
import '../models/user_subscription_profile.dart';

/// Modal interactivo con el detalle de los planes de NovaKey (Mensuales y Anuales)
class PlansShowcaseDialog extends StatefulWidget {
  final UserSubscriptionProfile currentUser;

  const PlansShowcaseDialog({super.key, required this.currentUser});

  static Future<void> show(BuildContext context, UserSubscriptionProfile currentUser) async {
    await showDialog(
      context: context,
      builder: (_) => PlansShowcaseDialog(currentUser: currentUser),
    );
  }

  @override
  State<PlansShowcaseDialog> createState() => _PlansShowcaseDialogState();
}

class _PlansShowcaseDialogState extends State<PlansShowcaseDialog> {
  bool _isAnnual = false; // Alternar entre Mensual y Anual

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F141C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1F2937)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planes y Suscripciones NovaKey',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Acceso sin restricciones desde PC (Web) y Dispositivos Móviles (Android)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Selector interactivo Mensual vs Anual
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B26),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF26334D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isAnnual = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isAnnual ? const Color(0xFF1D4ED8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Facturación Mensual',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_isAnnual ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _isAnnual = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isAnnual ? const Color(0xFF1D4ED8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Facturación Anual',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isAnnual ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Text(
                                  'AHORRA 17%',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF34D399),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tarjetas de Planes en Grid / Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  final cards = [
                    _buildPlanCard(
                      context: context,
                      title: 'STARTER',
                      subtitle: 'Uso personal básico',
                      price: 'Gratis',
                      period: 'de por vida',
                      badgeColor: const Color(0xFF64748B),
                      isCurrent: widget.currentUser.plan == NovaKeyPlan.starter,
                      features: const [
                        'Hasta 30 contraseñas / cuentas',
                        'Sincronización Web + Android en tiempo real',
                        'Cifrado Zero-Knowledge AES-256-GCM',
                        'Hasta 3 fotos de etiquetas físicas',
                        'Autenticación por PIN al correo',
                        'Exportación en formato JSON',
                      ],
                    ),
                    _buildPlanCard(
                      context: context,
                      title: 'PRO INDIVIDUAL',
                      subtitle: 'Para usuarios y profesionales',
                      price: _isAnnual ? 'S/ 99.00' : 'S/ 9.90',
                      period: _isAnnual ? 'por año (~S/ 8.25/mes)' : 'por mes',
                      badgeColor: const Color(0xFF0284C7),
                      isPopular: true,
                      savingsBadge: _isAnnual ? '2 meses gratis' : null,
                      isCurrent: widget.currentUser.plan == NovaKeyPlan.pro,
                      features: const [
                        'Contraseñas ILIMITADAS',
                        'Fotos de etiquetas ILIMITADAS',
                        'Sincronización Web + Android en vivo',
                        'Importación y Exportación Excel/JSON',
                        'Desbloqueo Biométrico Avanzado',
                        'Auditoría y generador de entropía',
                        'Soporte directo Tech Innova',
                      ],
                    ),
                    _buildPlanCard(
                      context: context,
                      title: 'BUSINESS / PYME',
                      subtitle: 'Equipos y empresas',
                      price: _isAnnual ? 'S/ 299.00' : 'S/ 29.90',
                      period: _isAnnual ? 'por año (~S/ 24.90/mes)' : 'por mes (5 cuentas)',
                      badgeColor: const Color(0xFF8B5CF6),
                      savingsBadge: _isAnnual ? '2 meses gratis' : null,
                      isCurrent: widget.currentUser.plan == NovaKeyPlan.business,
                      features: const [
                        'Todo lo incluido en el Plan Pro',
                        'Hasta 5 cuentas de usuario simultáneas',
                        'Panel de Superadmin exclusivo',
                        'Asignación centralizada de permisos',
                        'Respaldos automáticos encriptados',
                        'Soporte prioritario 24/7',
                      ],
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                    );
                  } else {
                    return Column(
                      children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // Sección para Contratar o Ampliar Plan con Tech Innova
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.contact_support_rounded, color: Color(0xFF38BDF8), size: 24),
                        SizedBox(width: 10),
                        Text(
                          '¿Deseas contratar o ampliar tu plan a Pro o Business?',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ponte en contacto con el equipo de soporte de Tech Innova para activar tu suscripción inmediatamente. Tras confirmar tu pago, el Superadmin habilitará tu plan de forma remota.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Canales de contacto directo
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('WhatsApp de Ventas & Soporte', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text('+51 947 515 529', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.email_outlined, color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Correo de Tech Innova', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text('tech.innova.reg@gmail.com', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 14),

                    // Medios de pago aceptados
                    const Text(
                      'Medios de pago 100% disponibles y factibles:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPaymentChip('🟣 Yape', const Color(0xFF7209B7)),
                        _buildPaymentChip('🔵 Plin', const Color(0xFF0077B6)),
                        _buildPaymentChip('🏛️ SIP Interbancario', const Color(0xFF059669)),
                        _buildPaymentChip('🟧 BCP (Banco de Crédito)', const Color(0xFFEA580C)),
                        _buildPaymentChip('🟩 Interbank', const Color(0xFF16A34A)),
                        _buildPaymentChip('🪙 Binance (USDT Crypto)', const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Garantía de Privacidad Zero-Knowledge: Ningún plan otorga acceso a tus contraseñas a Tech Innova ni a terceros. La clave maestra solo existe en tus dispositivos.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required Color badgeColor,
    required List<String> features,
    String? savingsBadge,
    bool isPopular = false,
    bool isCurrent = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF38BDF8)
              : isPopular
                  ? const Color(0xFF0284C7).withOpacity(0.8)
                  : const Color(0xFF1E293B),
          width: isCurrent || isPopular ? 1.8 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: badgeColor, letterSpacing: 0.8),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('TU PLAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                )
              else if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('POPULAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  period,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (savingsBadge != null) ...[
            const SizedBox(height: 4),
            Text(
              '✨ $savingsBadge',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 14),

          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1))),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
