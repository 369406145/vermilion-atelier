import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/document.dart';
import '../engine/strokes.dart';
import '../data/work_store.dart';
import '../models/catalog.dart';

class EditorController extends ChangeNotifier {
  EditorController(this.draft) : title = draft.title;

  final Draft draft;
  InkDocument? doc;
  Tool tool = Tool.brush;
  BrushSpec brush = brushes.first;
  Color color = const Color(0xFF1A120E);
  double size = 18;
  double flow = 0.9;
  bool mirror = false;
  double stabilize = 0.28;
  bool grid = false;
  bool vanish = false;
  Offset vanishPos = const Offset(0.5, 0.42);
  ShapeKind shape = ShapeKind.line;
  String title;
  bool loading = true;
  String? error;
  double zoom = 1;
  Offset pan = Offset.zero;
  bool fitted = false;
  bool baking = false;
  final live = <Offset>[];
  Offset? shapeA;
  Offset? shapeB;
  final recent = <Color>[const Color(0xFF1A120E)];
  void Function(String message)? onNote;

  void note(String message) => onNote?.call(message);

  void touch() => notifyListeners();

  Future<void> open() async {
    try {
      if (draft.existed) {
        final loaded = await WorkStore.load(draft.id);
        if (loaded != null) {
          doc = loaded;
          title = loaded.title;
          loading = false;
          touch();
          return;
        }
      }
      final paper = await renderPaper(draft.width, draft.height, draft.paper);
      final layers = <InkLayer>[];
      var active = 0;
      if (draft.underlay != null) {
        final decoded = await decodeBytes(draft.underlay!);
        final base = await containImage(decoded, draft.width, draft.height);
        decoded.dispose();
        layers.add(InkLayer(name: "Picture", image: base));
        layers.add(InkLayer(name: "Ink", image: await blankImage(draft.width, draft.height)));
        active = 1;
      } else {
        layers.add(InkLayer(name: "Ink", image: await blankImage(draft.width, draft.height)));
      }
      doc = InkDocument(
        id: draft.id,
        title: draft.title,
        width: draft.width,
        height: draft.height,
        paperId: draft.paper,
        paper: paper,
        layers: layers,
      )..active = active;
    } catch (_) {
      error = "This sheet could not be opened.";
    }
    loading = false;
    touch();
  }

  void remember(Color next) {
    recent.removeWhere((item) => item.toARGB32() == next.toARGB32());
    recent.insert(0, next);
    if (recent.length > 8) recent.removeLast();
  }

  void setColor(Color next, {bool quiet = false}) {
    color = next;
    if (!quiet) {
      remember(next);
      note("Pigment set.");
    }
    touch();
  }

  void setTool(Tool next, {String? label}) {
    tool = next;
    if (label != null) note(label);
    touch();
  }

  void selectBrush(BrushSpec next) {
    brush = next;
    tool = Tool.brush;
    note(next.name);
    touch();
  }

  void setShape(ShapeKind next) {
    shape = next;
    tool = Tool.shape;
    note(switch (next) {
      ShapeKind.line => "Line",
      ShapeKind.rect => "Frame",
      ShapeKind.ellipse => "Moon",
    });
    touch();
  }

  void toggleMirror() {
    mirror = !mirror;
    note(mirror ? "Mirror on." : "Mirror off.");
    touch();
  }

  void toggleGrid() {
    grid = !grid;
    note(grid ? "Grid on." : "Grid off.");
    touch();
  }

  void toggleVanish() {
    vanish = !vanish;
    note(vanish ? "One-point guide on. Drag the mark." : "Guide off.");
    touch();
  }

  void setVanish(Offset next) {
    vanishPos = Offset(next.dx.clamp(0.04, 0.96), next.dy.clamp(0.04, 0.96));
    touch();
  }

  void fit(Size viewport) {
    final drawing = doc;
    if (drawing == null || viewport.width <= 0 || viewport.height <= 0) return;
    zoom = min(viewport.width / drawing.width, viewport.height / drawing.height) * 0.92;
    pan = Offset.zero;
    fitted = true;
    touch();
  }

  void setView(double nextZoom, Offset nextPan) {
    zoom = nextZoom.clamp(0.15, 8);
    pan = nextPan;
    touch();
  }

  Offset _steady(Offset raw) {
    if (live.isEmpty) return raw;
    final last = live.last;
    final k = stabilize;
    return Offset(last.dx * k + raw.dx * (1 - k), last.dy * k + raw.dy * (1 - k));
  }

  void down(Offset point) {
    final drawing = doc;
    if (drawing == null || baking || tool == Tool.hand) return;
    if (tool == Tool.picker) {
      _pick(point);
      return;
    }
    if (tool == Tool.fill) {
      _fill(point);
      return;
    }
    if (tool == Tool.shape) {
      shapeA = point;
      shapeB = point;
      touch();
      return;
    }
    live
      ..clear()
      ..add(point);
    touch();
  }

  void move(Offset point) {
    if (baking || doc == null) return;
    if (tool == Tool.shape && shapeA != null) {
      shapeB = point;
      touch();
      return;
    }
    if ((tool == Tool.brush || tool == Tool.eraser) && live.isNotEmpty) {
      live.add(_steady(point));
      touch();
    }
  }

  void cancel() {
    live.clear();
    shapeA = null;
    shapeB = null;
    touch();
  }

  Future<void> up() async {
    final drawing = doc;
    if (drawing == null || baking) return;
    if (shapeA != null && shapeB != null) {
      final a = shapeA!;
      final b = shapeB!;
      final kind = shape;
      final mirrored = mirror;
      final stroke = size;
      final ink = color;
      final alpha = flow;
      await _commit((canvas) {
        strokeShape(canvas, kind, a, b, ink, stroke, alpha);
        if (mirrored) {
          strokeShape(
            canvas,
            kind,
            Offset(drawing.width - a.dx, a.dy),
            Offset(drawing.width - b.dx, b.dy),
            ink,
            stroke,
            alpha,
          );
        }
      });
      shapeA = null;
      shapeB = null;
      touch();
      return;
    }
    if (live.isEmpty || (tool != Tool.brush && tool != Tool.eraser)) return;
    final points = List<Offset>.from(live);
    final spec = brush;
    final radius = size / 2;
    final ink = color;
    final alpha = flow;
    final erase = tool == Tool.eraser;
    final mirrored = mirror;
    await _commit((canvas) {
      drawLiveStroke(
        canvas,
        points: points,
        brush: spec,
        radius: radius,
        color: ink,
        flow: alpha,
        erase: erase,
        mirror: mirrored,
        width: drawing.width.toDouble(),
      );
    });
    live.clear();
    touch();
  }

  Future<void> _pick(Offset point) async {
    final drawing = doc;
    if (drawing == null) return;
    final shot = await drawing.composite();
    final data = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
    shot.dispose();
    if (data == null) return;
    final x = point.dx.round().clamp(0, drawing.width - 1);
    final y = point.dy.round().clamp(0, drawing.height - 1);
    final i = (y * drawing.width + x) * 4;
    color = Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    remember(color);
    tool = Tool.brush;
    note("Pigment picked.");
    touch();
  }

  Future<void> _fill(Offset point) async {
    final drawing = doc;
    if (drawing == null || baking) return;
    baking = true;
    final index = drawing.active;
    final layer = drawing.layers[index];
    final before = layer.image;
    final next = await floodImage(before, point.dx.round(), point.dy.round(), color, flow);
    if (identical(next, before)) {
      note("That area is already this pigment.");
    } else {
      drawing.pushUndo(index, before);
      layer.image = next;
      note("Filled.");
    }
    baking = false;
    touch();
  }

  Future<void> _commit(void Function(Canvas canvas) draw) async {
    final drawing = doc;
    if (drawing == null || baking) return;
    baking = true;
    final index = drawing.active;
    final layer = drawing.layers[index];
    final before = layer.image;
    final next = await rasterize(drawing.width, drawing.height, (canvas) {
      canvas.drawImage(before, Offset.zero, Paint());
      draw(canvas);
    });
    drawing.pushUndo(index, before);
    layer.image = next;
    baking = false;
  }

  void undo() {
    final drawing = doc;
    if (drawing == null || !drawing.canUndo) {
      note("Nothing to step back to.");
      return;
    }
    drawing.undoStep();
    drawing.dirty = true;
    note("Stepped back.");
    touch();
  }

  void redo() {
    final drawing = doc;
    if (drawing == null || !drawing.canRedo) {
      note("Nothing to step forward to.");
      return;
    }
    drawing.redoStep();
    drawing.dirty = true;
    note("Stepped forward.");
    touch();
  }

  Future<void> keep() async {
    final drawing = doc;
    if (drawing == null) return;
    drawing.title = title.trim().isEmpty ? "Untitled sheet" : title.trim();
    title = drawing.title;
    await WorkStore.save(drawing);
    note("Kept on this device.");
    touch();
  }

  Future<void> download() async {
    final drawing = doc;
    if (drawing == null) return;
    await keep();
    final message = await WorkStore.exportPng(drawing);
    note(message);
  }

  Future<void> addLayer() async {
    final drawing = doc;
    if (drawing == null) return;
    if (drawing.layers.length >= 8) {
      note("Eight washes is the limit.");
      return;
    }
    drawing.dropHistory();
    final index = drawing.active + 1;
    drawing.layers.insert(
      index,
      InkLayer(name: "Wash ${drawing.layers.length + 1}", image: await blankImage(drawing.width, drawing.height)),
    );
    drawing.active = index;
    drawing.dirty = true;
    note("Wash added.");
    touch();
  }

  void removeLayer(int index) {
    final drawing = doc;
    if (drawing == null) return;
    if (drawing.layers.length <= 1) {
      note("A sheet needs one wash.");
      return;
    }
    if (index < 0 || index >= drawing.layers.length) return;
    drawing.dropHistory();
    drawing.layers.removeAt(index).image.dispose();
    if (drawing.active > index) drawing.active -= 1;
    if (drawing.active >= drawing.layers.length) drawing.active = drawing.layers.length - 1;
    drawing.dirty = true;
    note("Wash removed.");
    touch();
  }

  void activate(int index) {
    final drawing = doc;
    if (drawing == null || index < 0 || index >= drawing.layers.length) return;
    drawing.active = index;
    note(drawing.layers[index].name);
    touch();
  }

  void toggleVisible(int index) {
    final drawing = doc;
    if (drawing == null) return;
    final layer = drawing.layers[index];
    layer.visible = !layer.visible;
    drawing.dirty = true;
    note(layer.visible ? "Wash shown." : "Wash hidden.");
    touch();
  }

  void setOpacity(int index, double value) {
    final drawing = doc;
    if (drawing == null) return;
    drawing.layers[index].opacity = value.clamp(0.05, 1);
    drawing.dirty = true;
    touch();
  }

  void rename(int index, String name) {
    final drawing = doc;
    if (drawing == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      note("A wash needs a name.");
      return;
    }
    drawing.layers[index].name = trimmed;
    drawing.dirty = true;
    note("Renamed.");
    touch();
  }

  void moveLayer(int index, int dir) {
    final drawing = doc;
    if (drawing == null) return;
    final next = index + dir;
    if (next < 0 || next >= drawing.layers.length) {
      note(dir < 0 ? "Already at the back." : "Already in front.");
      return;
    }
    drawing.dropHistory();
    final layer = drawing.layers.removeAt(index);
    drawing.layers.insert(next, layer);
    if (drawing.active == index) {
      drawing.active = next;
    } else if (drawing.active == next) {
      drawing.active = index;
    }
    drawing.dirty = true;
    note(dir < 0 ? "Sent backward." : "Brought forward.");
    touch();
  }

  Future<void> duplicateLayer(int index) async {
    final drawing = doc;
    if (drawing == null) return;
    if (drawing.layers.length >= 8) {
      note("Eight washes is the limit.");
      return;
    }
    final layer = drawing.layers[index];
    final copy = await rasterize(drawing.width, drawing.height, (canvas) {
      canvas.drawImage(layer.image, Offset.zero, Paint());
    });
    drawing.dropHistory();
    drawing.layers.insert(
      index + 1,
      InkLayer(name: "${layer.name} copy", image: copy, visible: layer.visible, opacity: layer.opacity),
    );
    drawing.active = index + 1;
    drawing.dirty = true;
    note("Wash copied.");
    touch();
  }

  Future<void> mergeDown(int index) async {
    final drawing = doc;
    if (drawing == null) return;
    if (index <= 0) {
      note("Nothing underneath to merge into.");
      return;
    }
    final upper = drawing.layers[index];
    final lower = drawing.layers[index - 1];
    final merged = await rasterize(drawing.width, drawing.height, (canvas) {
      canvas.drawImage(lower.image, Offset.zero, Paint()..color = Colors.white.withValues(alpha: lower.opacity));
      canvas.drawImage(upper.image, Offset.zero, Paint()..color = Colors.white.withValues(alpha: upper.opacity));
    });
    drawing.dropHistory();
    lower.image.dispose();
    upper.image.dispose();
    lower
      ..image = merged
      ..opacity = 1
      ..visible = true
      ..name = lower.name;
    drawing.layers.removeAt(index);
    drawing.active = index - 1;
    drawing.dirty = true;
    note("Merged down.");
    touch();
  }

  Future<void> clearActive() async {
    final drawing = doc;
    if (drawing == null || baking) return;
    await _commit((canvas) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, drawing.width.toDouble(), drawing.height.toDouble()),
        Paint()..blendMode = BlendMode.clear,
      );
    });
    note("Wash cleared.");
    touch();
  }

  Future<void> placePicture(Uint8List bytes) async {
    final drawing = doc;
    if (drawing == null) return;
    if (drawing.layers.length >= 8) {
      note("Eight washes is the limit.");
      return;
    }
    baking = true;
    final decoded = await decodeBytes(bytes);
    final fitted = await containImage(decoded, drawing.width, drawing.height);
    decoded.dispose();
    drawing.dropHistory();
    final index = drawing.active + 1;
    drawing.layers.insert(index, InkLayer(name: "Picture", image: fitted));
    drawing.active = index;
    drawing.dirty = true;
    baking = false;
    note("Picture placed. Draw over it.");
    touch();
  }

  @override
  void dispose() {
    doc?.dispose();
    super.dispose();
  }
}
