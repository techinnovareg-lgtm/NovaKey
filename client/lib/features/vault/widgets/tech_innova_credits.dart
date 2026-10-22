import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Componente de créditos oficial de Tech Innova con enlace directo a tech-innova.online
class TechInnovaCredits extends StatefulWidget {
  final bool compact;

  const TechInnovaCredits({super.key, this.compact = false});

  @override
  State<TechInnovaCredits> createState() => _TechInnovaCreditsState();
}

class _TechInnovaCreditsState extends State<TechInnovaCredits> {
  bool _isHovered = false;

  Future<void> _launchTechInnova() async {
    final uri = Uri.parse('https://tech-innova.online');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('No se pudo abrir el sitio web de Tech Innova: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Acentos de alta tecnología y ciberseguridad
    const cyberBlue = Color(0xFF2563EB);
    const brightCyan = Color(0xFF38BDF8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _launchTechInnova,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isHovered ? const Color(0xFF131D31) : const Color(0xFF131722),
                _isHovered ? const Color(0xFF0F172A) : const Color(0xFF0D1017),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? brightCyan : cyberBlue.withOpacity(0.35),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: cyberBlue.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Logotipo Tech Innova
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFF161F36),
                  padding: const EdgeInsets.all(3),
                  child: Image.asset(
                    'assets/images/logo_TI.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.code_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Textos y Enlace
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Desarrollado por',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Tech Innova',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'tech-innova.online',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isHovered ? const Color(0xFF60A5FA) : const Color(0xFF38BDF8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 11,
                          color: _isHovered ? const Color(0xFF60A5FA) : const Color(0xFF38BDF8),
                        ),
                      ],
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
}
