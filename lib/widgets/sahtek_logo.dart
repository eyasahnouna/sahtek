import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Logo officiel Sahtek.
/// [size]    — côté du carré arrondi (défaut 80)
/// [animate] — active la pulsation du glow (splash, auth)
/// [showText] — affiche "Sahtek" + sous-titre en dessous
class SahtekLogo extends StatefulWidget {
  final double size;
  final bool   animate;
  final bool   showText;

  const SahtekLogo({
    super.key,
    this.size     = 80,
    this.animate  = false,
    this.showText = false,
  });

  @override
  State<SahtekLogo> createState() => _SahtekLogoState();
}

class _SahtekLogoState extends State<SahtekLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SahtekLogo old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animate) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: widget.animate ? _scale.value : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow externe animé
                if (widget.animate)
                  Container(
                    width:  s * _pulse.value,
                    height: s * _pulse.value,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(s * 0.32),
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.18),
                          AppTheme.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                // Corps du logo
                Container(
                  width: s, height: s,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B8FAC), Color(0xFF00C9B1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(s * 0.27),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.38),
                        blurRadius: s * 0.28,
                        offset: Offset(0, s * 0.09),
                      ),
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.15),
                        blurRadius: s * 0.18,
                        offset: Offset(s * 0.04, s * 0.04),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _EcgPainter(s),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showText) ...[
          const SizedBox(height: 16),
          Text(
            'Sahtek',
            style: AppFonts.display(color: AppTheme.primary, size: 32)
                .copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Votre santé, sécurisée',
            style: AppFonts.body(color: Colors.grey.shade500, size: 14),
          ),
        ],
      ],
    );
  }
}

/// Dessine la ligne ECG + mini-cœur en blanc sur le fond gradient.
class _EcgPainter extends CustomPainter {
  final double size;
  _EcgPainter(this.size);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // ── Ligne ECG ─────────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color  = Colors.white
      ..strokeWidth  = w * 0.055
      ..strokeCap    = StrokeCap.round
      ..strokeJoin   = StrokeJoin.round
      ..style  = PaintingStyle.stroke;

    final ecg = Path();
    final cy  = h * 0.62;       // ligne de base légèrement vers le bas pour laisser place au cœur
    ecg.moveTo(w * 0.06, cy);
    ecg.lineTo(w * 0.26, cy);
    // spike haut
    ecg.lineTo(w * 0.36, cy - h * 0.20);
    // spike bas
    ecg.lineTo(w * 0.43, cy + h * 0.18);
    // second pic
    ecg.lineTo(w * 0.52, cy - h * 0.10);
    ecg.lineTo(w * 0.60, cy);
    ecg.lineTo(w * 0.94, cy);
    canvas.drawPath(ecg, linePaint);

    // ── Cœur centré en haut ───────────────────────────────────────────────────
    _drawHeart(canvas, Offset(w * 0.50, h * 0.28), w * 0.17);
  }

  void _drawHeart(Canvas canvas, Offset center, double r) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx   = center.dx;
    final cy   = center.dy;

    // Forme cœur via courbes de Bézier
    path.moveTo(cx, cy + r * 0.9);
    path.cubicTo(
      cx - r * 1.8, cy + r * 0.3,
      cx - r * 1.8, cy - r * 1.0,
      cx,            cy - r * 0.3,
    );
    path.cubicTo(
      cx + r * 1.8, cy - r * 1.0,
      cx + r * 1.8, cy + r * 0.3,
      cx,            cy + r * 0.9,
    );
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.size != size;
}

/// Wrapper qui fait rebondir son enfant au toucher.
class AnimatedTap extends StatefulWidget {
  final Widget      child;
  final VoidCallback? onTap;
  final double      scale;

  const AnimatedTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.94,
  });

  @override
  State<AnimatedTap> createState() => _AnimatedTapState();
}

class _AnimatedTapState extends State<AnimatedTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _anim = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut,
          reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}
