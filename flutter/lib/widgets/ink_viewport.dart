import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/strokes.dart';
import '../state/editor_controller.dart';
import '../theme/atelier_theme.dart';

class InkViewport extends StatefulWidget {
  const InkViewport({super.key, required this.controller});

  final EditorController controller;

  @override
  State<InkViewport> createState() => _InkViewportState();
}

class _Pinch {
  _Pinch(this.dist, this.zoom, this.pan, this.mid);
  final double dist;
  final double zoom;
  final Offset pan;
  final Offset mid;
}

class _InkViewportState extends State<InkViewport> {
  final Map<int, Offset> _pointers = {};
  _Pinch? _pinch;
  int? _handId;
  Offset _handLast = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_fitIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitIfNeeded());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_fitIfNeeded);
    super.dispose();
  }

  void _fitIfNeeded() {
    if (!mounted || widget.controller.fitted || widget.controller.doc == null) return;
    final size = context.size;
    if (size == null || size.width == 0 || size.height == 0) return;
    widget.controller.fit(size);
  }

  Offset _toDoc(Offset local) {
    final doc = widget.controller.doc;
    final size = context.size ?? Size.zero;
    if (doc == null) return Offset.zero;
    final c = widget.controller;
    return Offset(
      (local.dx - size.width / 2 - c.pan.dx) / c.zoom + doc.width / 2,
      (local.dy - size.height / 2 - c.pan.dy) / c.zoom + doc.height / 2,
    );
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    final c = widget.controller;
    if (_pointers.length >= 2) {
      c.cancel();
      final pts = _pointers.values.toList();
      _pinch = _Pinch(
        max(1, (pts[0] - pts[1]).distance),
        c.zoom,
        c.pan,
        (pts[0] + pts[1]) / 2,
      );
      return;
    }
    if (c.tool.name == "hand") {
      _handId = event.pointer;
      _handLast = event.localPosition;
      return;
    }
    if (c.vanish && _hitVanish(event.localPosition)) {
      _handId = -event.pointer - 1;
      return;
    }
    c.down(_toDoc(event.localPosition));
  }

  bool _hitVanish(Offset local) {
    final doc = widget.controller.doc;
    if (doc == null) return false;
    final c = widget.controller;
    final size = context.size ?? Size.zero;
    final dx = size.width / 2 + c.pan.dx + (c.vanishPos.dx * doc.width - doc.width / 2) * c.zoom;
    final dy = size.height / 2 + c.pan.dy + (c.vanishPos.dy * doc.height - doc.height / 2) * c.zoom;
    return (local - Offset(dx, dy)).distance < 28;
  }

  void _move(PointerMoveEvent event) {
    _pointers[event.pointer] = event.localPosition;
    final c = widget.controller;
    final pinch = _pinch;
    if (_pointers.length >= 2 && pinch != null) {
      final pts = _pointers.values.toList();
      final dist = max(1.0, (pts[0] - pts[1]).distance);
      final mid = (pts[0] + pts[1]) / 2;
      c.setView(pinch.zoom * (dist / pinch.dist), pinch.pan + (mid - pinch.mid));
      return;
    }
    if (_handId != null && _handId! < 0) {
      final doc = c.doc;
      if (doc == null) return;
      final size = context.size ?? Size.zero;
      final x = ((event.localPosition.dx - size.width / 2 - c.pan.dx) / c.zoom + doc.width / 2) / doc.width;
      final y = ((event.localPosition.dy - size.height / 2 - c.pan.dy) / c.zoom + doc.height / 2) / doc.height;
      c.setVanish(Offset(x, y));
      return;
    }
    if (c.tool.name == "hand" && _handId == event.pointer) {
      c.pan += event.localPosition - _handLast;
      _handLast = event.localPosition;
      c.touch();
      return;
    }
    c.move(_toDoc(event.localPosition));
  }

  void _up(PointerEvent event) {
    final wasPinch = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinch = null;
    if (_handId == event.pointer || _handId == -event.pointer - 1) _handId = null;
    if (wasPinch) return;
    if (widget.controller.tool.name == "hand") return;
    if (_pointers.isEmpty) widget.controller.up();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: CustomPaint(
        painter: _InkPainter(widget.controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.controller) : super(repaint: controller);

  final EditorController controller;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AtelierColors.ink);
    final doc = controller.doc;
    if (doc == null) return;
    canvas.save();
    canvas.translate(size.width / 2 + controller.pan.dx, size.height / 2 + controller.pan.dy);
    canvas.scale(controller.zoom);
    canvas.translate(-doc.width / 2, -doc.height / 2);
    canvas.drawImage(doc.paper, Offset.zero, Paint());
    for (var i = 0; i < doc.layers.length; i++) {
      final layer = doc.layers[i];
      if (!layer.visible || layer.opacity <= 0) continue;
      final liveHere = i == doc.active && (controller.live.isNotEmpty || controller.shapeA != null);
      if (!liveHere) {
        canvas.drawImage(layer.image, Offset.zero, Paint()..color = Colors.white.withValues(alpha: layer.opacity));
        continue;
      }
      canvas.saveLayer(Rect.fromLTWH(0, 0, doc.width.toDouble(), doc.height.toDouble()), Paint());
      canvas.drawImage(layer.image, Offset.zero, Paint()..color = Colors.white.withValues(alpha: layer.opacity));
      if (controller.live.isNotEmpty) {
        drawLiveStroke(
          canvas,
          points: controller.live,
          brush: controller.brush,
          radius: controller.size / 2,
          color: controller.color,
          flow: controller.flow,
          erase: controller.tool.name == "eraser",
          mirror: controller.mirror,
          width: doc.width.toDouble(),
        );
      }
      final a = controller.shapeA;
      final b = controller.shapeB;
      if (a != null && b != null) {
        strokeShape(canvas, controller.shape, a, b, controller.color, controller.size, controller.flow);
        if (controller.mirror) {
          strokeShape(
            canvas,
            controller.shape,
            Offset(doc.width - a.dx, a.dy),
            Offset(doc.width - b.dx, b.dy),
            controller.color,
            controller.size,
            controller.flow,
          );
        }
      }
      canvas.restore();
    }
    if (controller.grid) {
      final paint = Paint()
        ..color = fade(AtelierColors.cinnabar, 0.35)
        ..strokeWidth = 1 / controller.zoom;
      for (var x = 48.0; x < doc.width; x += 48) {
        canvas.drawLine(Offset(x, 0), Offset(x, doc.height.toDouble()), paint);
      }
      for (var y = 48.0; y < doc.height; y += 48) {
        canvas.drawLine(Offset(0, y), Offset(doc.width.toDouble(), y), paint);
      }
    }
    if (controller.vanish) {
      final guide = Paint()
        ..color = fade(AtelierColors.cinnabar, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / controller.zoom;
      final center = Offset(controller.vanishPos.dx * doc.width, controller.vanishPos.dy * doc.height);
      final len = sqrt(doc.width * doc.width + doc.height * doc.height);
      for (var i = 0; i < 12; i++) {
        final ang = (i / 12) * pi * 2;
        canvas.drawLine(center, center + Offset(cos(ang) * len, sin(ang) * len), guide);
      }
      canvas.drawCircle(center, 8 / controller.zoom, guide);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
