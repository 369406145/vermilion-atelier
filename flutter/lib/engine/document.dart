import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import 'strokes.dart';

class InkLayer {
  InkLayer({required this.name, required this.image, this.visible = true, this.opacity = 1});

  String name;
  bool visible;
  double opacity;
  ui.Image image;
}

class Snap {
  Snap(this.index, this.image);
  final int index;
  final ui.Image image;
}

class InkDocument {
  InkDocument({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.paperId,
    required this.paper,
    required this.layers,
  });

  final String id;
  String title;
  final int width;
  final int height;
  final PaperId paperId;
  final ui.Image paper;
  final List<InkLayer> layers;
  int active = 0;
  bool dirty = false;
  bool persisted = false;
  final List<Snap> undo = [];
  final List<Snap> redo = [];

  bool get canUndo => undo.isNotEmpty;
  bool get canRedo => redo.isNotEmpty;

  void dispose() {
    paper.dispose();
    for (final layer in layers) {
      layer.image.dispose();
    }
    dropHistory();
  }

  void dropHistory() {
    for (final snap in undo) {
      snap.image.dispose();
    }
    for (final snap in redo) {
      snap.image.dispose();
    }
    undo.clear();
    redo.clear();
  }

  void pushUndo(int index, ui.Image before) {
    undo.add(Snap(index, before));
    while (undo.length > 16) {
      undo.removeAt(0).image.dispose();
    }
    for (final snap in redo) {
      snap.image.dispose();
    }
    redo.clear();
    dirty = true;
  }

  void undoStep() {
    if (undo.isEmpty) return;
    final snap = undo.removeLast();
    if (snap.index < 0 || snap.index >= layers.length) {
      snap.image.dispose();
      return;
    }
    final layer = layers[snap.index];
    redo.add(Snap(snap.index, layer.image));
    layer.image = snap.image;
  }

  void redoStep() {
    if (redo.isEmpty) return;
    final snap = redo.removeLast();
    if (snap.index < 0 || snap.index >= layers.length) {
      snap.image.dispose();
      return;
    }
    final layer = layers[snap.index];
    undo.add(Snap(snap.index, layer.image));
    layer.image = snap.image;
  }

  Future<ui.Image> composite({int maxSide = 0}) async {
    final image = await rasterize(width, height, (canvas) {
      canvas.drawImage(paper, Offset.zero, Paint());
      for (final layer in layers) {
        if (!layer.visible || layer.opacity <= 0) continue;
        canvas.drawImage(layer.image, Offset.zero, Paint()..color = Colors.white.withValues(alpha: layer.opacity));
      }
    });
    if (maxSide <= 0) return image;
    final scale = maxSide / max(width, height);
    final tw = max(1, (width * scale).round());
    final th = max(1, (height * scale).round());
    final scaled = await rasterize(tw, th, (canvas) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
        Paint(),
      );
    });
    image.dispose();
    return scaled;
  }
}

Future<ui.Image> imageFromPixels(Uint8List rgba, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

Future<ui.Image> blankImage(int w, int h) => imageFromPixels(Uint8List(w * h * 4), w, h);

Future<ui.Image> decodeBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<ui.Image> containImage(ui.Image src, int w, int h) {
  final scale = min(w / src.width, h / src.height);
  final dw = src.width * scale;
  final dh = src.height * scale;
  final left = (w - dw) / 2;
  final top = (h - dh) / 2;
  return rasterize(w, h, (canvas) {
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(left, top, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
  });
}

Future<Uint8List> pngBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> renderPaper(int w, int h, PaperId paper) async {
  final pixels = Uint8List(w * h * 4);
  final base = switch (paper) {
    PaperId.silk => const [0xEF, 0xE2, 0xCC],
    PaperId.coarse => const [0xF1, 0xE6, 0xD4],
    _ => const [0xF7, 0xF3, 0xEA],
  };
  final amp = switch (paper) {
    PaperId.plain => 5.0,
    PaperId.coarse => 20.0,
    PaperId.silk => 9.0,
    PaperId.xuan => 13.0,
  };
  var seed = 17 + w * 13 + h + paper.index * 29;
  double rnd() {
    seed = (seed * 16807 + 11) % 2147483647;
    return seed / 2147483647;
  }

  for (var i = 0; i < pixels.length; i += 4) {
    final n = (rnd() - 0.5) * amp;
    pixels[i] = (base[0] + n).round().clamp(0, 255);
    pixels[i + 1] = (base[1] + n * 0.94).round().clamp(0, 255);
    pixels[i + 2] = (base[2] + n * 0.82).round().clamp(0, 255);
    pixels[i + 3] = 255;
  }
  if (paper != PaperId.plain) {
    final fibers = paper == PaperId.coarse ? 70 : 36;
    final reach = paper == PaperId.coarse ? 16.0 : 10.0;
    final ink = paper == PaperId.coarse ? 28 : 16;
    for (var i = 0; i < fibers; i++) {
      final x = rnd() * w;
      final y = rnd() * h;
      final len = 4 + rnd() * reach;
      final ang = rnd() * pi;
      final x2 = x + cos(ang) * len;
      final y2 = y + sin(ang) * 0.45 * len;
      final steps = max(1, len.ceil());
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final px = (x + (x2 - x) * t).round();
        final py = (y + (y2 - y) * t).round();
        if (px < 0 || py < 0 || px >= w || py >= h) continue;
        final o = (py * w + px) * 4;
        pixels[o] = (pixels[o] * (255 - ink) ~/ 255);
        pixels[o + 1] = (pixels[o + 1] * (255 - ink) ~/ 255);
        pixels[o + 2] = (pixels[o + 2] * (255 - ink) ~/ 255);
      }
    }
  }
  return imageFromPixels(pixels, w, h);
}

Future<ui.Image> floodImage(ui.Image src, int sx, int sy, Color color, double alpha) async {
  final w = src.width;
  final h = src.height;
  if (sx < 0 || sy < 0 || sx >= w || sy >= h) return src;
  final raw = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (raw == null) return src;
  final pixels = Uint8List.fromList(raw.buffer.asUint8List());
  final start = (sy * w + sx) * 4;
  final pr = (color.r * 255).round().clamp(0, 255).toInt();
  final pg = (color.g * 255).round().clamp(0, 255).toInt();
  final pb = (color.b * 255).round().clamp(0, 255).toInt();
  final pa = (alpha * 255).round().clamp(0, 255).toInt();
  if (pixels[start] == pr && pixels[start + 1] == pg && pixels[start + 2] == pb && (pixels[start + 3] - pa).abs() <= 2) {
    return src;
  }
  final sr = pixels[start];
  final sg = pixels[start + 1];
  final sb = pixels[start + 2];
  final sa = pixels[start + 3];
  final seen = Uint8List(w * h);
  final stack = <int>[sy * w + sx];
  seen[sy * w + sx] = 1;
  bool near(int i) =>
      (pixels[i] - sr).abs() <= 32 &&
      (pixels[i + 1] - sg).abs() <= 32 &&
      (pixels[i + 2] - sb).abs() <= 32 &&
      (pixels[i + 3] - sa).abs() <= 32;
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final i = p * 4;
    pixels[i] = pr;
    pixels[i + 1] = pg;
    pixels[i + 2] = pb;
    pixels[i + 3] = pa;
    final x = p % w;
    final y = p ~/ w;
    void consider(int q) {
      if (seen[q] == 1) return;
      seen[q] = 1;
      if (near(q * 4)) stack.add(q);
    }

    if (x > 0) consider(p - 1);
    if (x + 1 < w) consider(p + 1);
    if (y > 0) consider(p - w);
    if (y + 1 < h) consider(p + w);
  }
  return imageFromPixels(pixels, w, h);
}
