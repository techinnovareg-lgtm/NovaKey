import 'package:flutter/material.dart';

/// Logotipo e Isologo oficial de NovaKey
class NovaKeyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact;

  const NovaKeyLogo({
    super.key,
    this.size = 38,
    this.showText = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Isologo
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1D4ED8), // Azul Cobalto Ciberseguridad
                Color(0xFF0F172A), // Pizarra profunda de alta tecnología
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.26),
            child: Image.asset(
              'assets/images/novakey_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: const Color(0xFF38BDF8),
                  size: size * 0.55,
                ),
              ),
            ),
          ),
        ),

        if (showText) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nova',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Key',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3B82F6),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (!compact)
                Text(
                  'BÓVEDA ZERO-KNOWLEDGE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
