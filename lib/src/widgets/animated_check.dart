import 'package:flutter/material.dart';

/// A checkbox that animates the two beats of ticking it: the box fills first,
/// then the tick is drawn.
///
/// Material's [Checkbox] swaps between two static states, which reads as a
/// flicker rather than as an action. This separates the two moments so the tap
/// registers:
///
///  1. a filled circle grows from the centre (or from the tapped point) to
///     cover the box — the "press" half;
///  2. the tick is then stroked from its first leg through to the last.
///
/// The whole thing is one driven animation so the two phases stay in step, and
/// un-ticking plays it backwards.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.checked,
    required this.onChanged,
    this.size = 24,
  });

  final bool checked;

  /// Called with the value the box should now hold.
  final ValueChanged<bool> onChanged;

  final double size;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked == oldWidget.checked) return;
    if (widget.checked) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      checked: widget.checked,
      child: InkResponse(
        // 48dp keeps the tap target at the Material minimum even though the
        // drawn box is 24dp.
        radius: 24,
        onTap: () => widget.onChanged(!widget.checked),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _CheckPainter(
                    // Fill covers the first ~60% of the animation, then the tick
                    // is drawn over it.
                    fill: Curves.easeOutCubic.transform(
                      (_controller.value / 0.6).clamp(0.0, 1.0),
                    ),
                    tick: Curves.easeOut.transform(
                      ((_controller.value - 0.45) / 0.55).clamp(0.0, 1.0),
                    ),
                    filledColor: scheme.primary,
                    tickColor: scheme.onPrimary,
                    idleBorderColor: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.fill,
    required this.tick,
    required this.filledColor,
    required this.tickColor,
    required this.idleBorderColor,
  });

  /// 0 → box is empty and outlined, 1 → box is fully filled.
  final double fill;

  /// 0 → no tick, 1 → tick fully drawn.
  final double tick;

  final Color filledColor;
  final Color tickColor;
  final Color idleBorderColor;

  /// Tick polyline in unit coordinates: down-right, then up-right.
  static const List<Offset> _tickPath = <Offset>[
    Offset(0.26, 0.52),
    Offset(0.43, 0.69),
    Offset(0.76, 0.33),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.width * 0.25);
    final rect = Offset.zero & size;

    // The outline fades out as the fill arrives, so the two never compete.
    if (fill < 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = idleBorderColor.withValues(
            alpha: (1 - fill * 1.6).clamp(0.0, 1.0),
          ),
      );
    }

    if (fill > 0) {
      // Grown from the centre rather than a corner, which keeps it symmetric
      // regardless of where inside the box the tap landed.
      final maxRadius = size.longestSide;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: maxRadius * fill,
            height: maxRadius * fill,
          ),
          Radius.circular(maxRadius * fill * 0.25),
        ),
        Paint()..color = filledColor,
      );
    }

    if (tick <= 0) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tickColor;

    final full = Path()
      ..moveTo(_tickPath[0].dx * size.width, _tickPath[0].dy * size.height)
      ..lineTo(_tickPath[1].dx * size.width, _tickPath[1].dy * size.height)
      ..lineTo(_tickPath[2].dx * size.width, _tickPath[2].dy * size.height);

    // Trim the path so the tick visibly grows rather than fading in.
    final metric = full.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tick),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.tick != tick ||
      oldDelegate.filledColor != filledColor ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.idleBorderColor != idleBorderColor;
}