import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Double-border card background: a thin outer line, a rounder inner line a
/// little further in, and two small arcs in each corner between them.
class ProfileFramePainter extends CustomPainter {
  final Color lineTop;
  final Color lineBottom;
  final Color fillTop;
  final Color fillBottom;

  /// Fixed sizes in logical pixels; when null they scale with the card width
  /// (good for small square-ish cards, too round for wide ones).
  final double? outerRadius;
  final double? gap;
  final double? innerRadius;

  const ProfileFramePainter({
    this.lineTop = const Color(0xFFC9B5FF),
    this.lineBottom = const Color(0xFF7B58E6),
    this.fillTop = const Color(0xFFFBF8FF),
    this.fillBottom = const Color(0xFFDCCBFF),
    this.outerRadius,
    this.gap,
    this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      Radius.circular(outerRadius ?? w * 0.09),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ).createShader(Offset.zero & size),
    );

    final line = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lineTop, lineBottom],
    ).createShader(Offset.zero & size);

    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = line,
    );

    final g = gap ?? w * 0.062;
    final innerRect = outer.outerRect.deflate(g);
    final innerR = innerRadius ?? w * 0.085;
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(innerR)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = line,
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..shader = line;
    final corners = <(Offset, double)>[
      (Offset(innerRect.left + innerR, innerRect.top + innerR), math.pi),
      (Offset(innerRect.right - innerR, innerRect.top + innerR), 1.5 * math.pi),
      (Offset(innerRect.right - innerR, innerRect.bottom - innerR), 0),
      (Offset(innerRect.left + innerR, innerRect.bottom - innerR), 0.5 * math.pi),
    ];
    for (final (centre, start) in corners) {
      for (final f in const [0.38, 0.75]) {
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: innerR + g * f),
          start + 0.22 * math.pi / 2,
          0.56 * math.pi / 2,
          false,
          arcPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ProfileFramePainter old) =>
      old.lineTop != lineTop ||
      old.lineBottom != lineBottom ||
      old.fillTop != fillTop ||
      old.fillBottom != fillBottom ||
      old.outerRadius != outerRadius ||
      old.gap != gap ||
      old.innerRadius != innerRadius;
}
