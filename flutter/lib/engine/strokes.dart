import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../theme/atelier_theme.dart';

double clampNum(double n, double lo, double hi) => max(lo, min(hi, n));

Future<ui.Image> rasterize(int width, int height, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

void stamp(
  Canvas canvas,
  double x,
  double y,
  double radius,
  Color color,
  double alpha,
  double hard,
  bool erase,
  bool dry,
) {
  final r = max(radius, 0.4);
  if (dry && !erase) {
    final rnd = Random((x * 10).round() * 73856093 ^ (y * 10).round() * 19349663);
    final count = 7 + (r / 4).floor();
    for (var i = 0; i < count; i++) {
      final ang = rnd.nextDouble() * pi * 2;
      final dist = rnd.nextDouble() * r;
      final sr = max(0.4, r * (0.06 + rnd.nextDouble() * 0.14));
      canvas.drawCircle(
        Offset(x + cos(ang) * dist, y + sin(ang) * dist),
        sr,
        Paint()
          ..color = fade(color, alpha * (0.2 + rnd.nextDouble() * 0.7))
          ..blendMode = BlendMode.srcOver,
      );
    }
    return;
  }
  final solid = fade(erase ? Colors.black : color, alpha);
  final clear = fade(erase ? Colors.black : color, 0);
  final inner = (hard * 0.9).clamp(0.0, 0.98);
  canvas.drawCircle(
    Offset(x, y),
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(x, y),
        r,
        [solid, solid, clear],
        [0, inner, 1],
      )
      ..blendMode = erase ? BlendMode.dstOut : BlendMode.srcOver,
  );
}

void paintSegment(
  Canvas canvas,
  Offset a,
  Offset b,
  BrushSpec brush,
  double radius,
  Color color,
  double flow,
  bool erase,
  double? mirrorWidth,
) {
  final dist = (b - a).distance;
  final speedR = brush.kind == BrushKind.speed ? radius * clampNum(14 / max(dist, 0.8), 0.2, 1.45) : radius;
  final step = max(0.7, speedR * brush.spacing);
  final n = max(1, (dist / step).ceil());
  final alpha = clampNum(flow * brush.baseFlow, 0.02, 1);
  final dry = brush.kind == BrushKind.dry && !erase;
  for (var i = 0; i <= n; i++) {
    final t = n == 0 ? 0.0 : i / n;
    final p = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    stamp(canvas, p.dx, p.dy, speedR, color, alpha, brush.hard, erase, dry);
    if (mirrorWidth != null) {
      stamp(canvas, mirrorWidth - p.dx, p.dy, speedR, color, alpha, brush.hard, erase, dry);
    }
  }
}

void strokeShape(
  Canvas canvas,
  ShapeKind kind,
  Offset a,
  Offset b,
  Color color,
  double width,
  double alpha,
) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = max(1, width)
    ..color = fade(color, alpha);
  switch (kind) {
    case ShapeKind.line:
      canvas.drawLine(a, b, paint);
    case ShapeKind.rect:
      canvas.drawRect(Rect.fromPoints(a, b), paint);
    case ShapeKind.ellipse:
      canvas.drawOval(Rect.fromPoints(a, b), paint);
  }
}

void drawLiveStroke(
  Canvas canvas, {
  required List<Offset> points,
  required BrushSpec brush,
  required double radius,
  required Color color,
  required double flow,
  required bool erase,
  required bool mirror,
  required double width,
}) {
  if (points.isEmpty) return;
  final mirrorWidth = mirror ? width : null;
  if (points.length == 1) {
    paintSegment(canvas, points.first, points.first, brush, radius, color, flow, erase, mirrorWidth);
    return;
  }
  for (var i = 1; i < points.length; i++) {
    paintSegment(canvas, points[i - 1], points[i], brush, radius, color, flow, erase, mirrorWidth);
  }
}
