import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/work_store.dart';
import '../models/catalog.dart';
import '../state/editor_controller.dart';
import '../theme/atelier_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/ink_viewport.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.draft, required this.onExit});

  final Draft draft;
  final VoidCallback onExit;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final EditorController _controller = EditorController(widget.draft);
  late final TextEditingController _title = TextEditingController(text: widget.draft.title);
  final _viewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.onNote = (message) {
      if (!mounted) return;
      NoticeScope.read(context).say(message);
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _fit() {
    final size = _viewKey.currentContext?.size;
    if (size == null) return;
    _controller.fitted = false;
    _controller.fit(size);
    _controller.note("Fitted to the screen.");
  }

  Future<void> _close() async {
    final dirty = _controller.doc?.dirty ?? false;
    if (!dirty) {
      widget.onExit();
      return;
    }
    final fresh = !widget.draft.existed;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Leave the sheet?", style: Theme.of(context).textTheme.headlineMedium),
        content: const Text("Unsaved ink stays only if you keep it on this device."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, "paint"), child: const Text("Keep painting")),
          TextButton(
            onPressed: () => Navigator.pop(context, "drop"),
            child: Text(fresh ? "Throw this sheet away" : "Leave without saving"),
          ),
          TextButton(onPressed: () => Navigator.pop(context, "save"), child: const Text("Keep and leave")),
        ],
      ),
    );
    if (!mounted || choice == null || choice == "paint") {
      if (choice == "paint") _controller.note("Still painting.");
      return;
    }
    if (choice == "save") {
      await _controller.keep();
      if (mounted) widget.onExit();
      return;
    }
    final dropSavedCopy = fresh && (_controller.doc?.persisted ?? false);
    final id = widget.draft.id;
    _controller.note(fresh ? "Sheet thrown away." : "Left without saving.");
    widget.onExit();
    if (dropSavedCopy) await WorkStore.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              controller: _controller,
              title: _title,
              onClose: _close,
              onDownload: _controller.download,
              onKeep: _controller.keep,
            ),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      _Rail(controller: _controller, onSheets: _openSheet),
                      Expanded(key: _viewKey, child: InkViewport(controller: _controller)),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    top: 8,
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => Text(
                        "${(_controller.zoom * 100).round()}%",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (_controller.loading) {
                        return const Center(child: Text("Grinding the ink…"));
                      }
                      if (_controller.error != null) {
                        return Center(child: Text(_controller.error!, style: const TextStyle(color: AtelierColors.cinnabar)));
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
            _Sliders(controller: _controller),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(String which) async {
    if (which == "brush") {
      _controller.note("Brushes.");
      await showModalBottomSheet<void>(context: context, builder: (context) => _BrushSheet(controller: _controller));
    } else if (which == "shape") {
      _controller.note("Marks.");
      await showModalBottomSheet<void>(context: context, builder: (context) => _ShapeSheet(controller: _controller));
    } else if (which == "color") {
      _controller.note("Pigment.");
      await showModalBottomSheet<void>(context: context, builder: (context) => _ColorSheet(controller: _controller));
    } else if (which == "layers") {
      _controller.note("Washes.");
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => _LayerSheet(controller: _controller));
    } else {
      _controller.note("The desk.");
      await showModalBottomSheet<void>(context: context, builder: (context) => _DeskSheet(controller: _controller, onFit: _fit, onPicture: _picture));
    }
  }

  Future<void> _picture() async {
    Navigator.pop(context);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
      if (!mounted) return;
      if (file == null) {
        _controller.note("No picture chosen.");
        return;
      }
      await _controller.placePicture(await file.readAsBytes());
    } catch (_) {
      _controller.note("Could not open that picture.");
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.title,
    required this.onClose,
    required this.onDownload,
    required this.onKeep,
  });

  final EditorController controller;
  final TextEditingController title;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: "Close"),
          Expanded(
            child: TextField(
              controller: title,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: (value) {
                controller.title = value;
                controller.doc?.title = value;
                controller.doc?.dirty = true;
              },
            ),
          ),
          IconButton(onPressed: controller.undo, icon: const Icon(Icons.undo), tooltip: "Undo"),
          IconButton(onPressed: controller.redo, icon: const Icon(Icons.redo), tooltip: "Redo"),
          IconButton(onPressed: onKeep, icon: const Icon(Icons.bookmark_border), tooltip: "Keep on this device"),
          IconButton(onPressed: onDownload, icon: const Icon(Icons.download), tooltip: "Save PNG"),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.controller, required this.onSheets});

  final EditorController controller;
  final ValueChanged<String> onSheets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SizedBox(
          width: 56,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              _tool(Icons.brush, "Brush", Tool.brush, () {
                if (controller.tool == Tool.brush) {
                  onSheets("brush");
                } else {
                  controller.setTool(Tool.brush, label: controller.brush.name);
                }
              }),
              _tool(Icons.cleaning_services, "Eraser", Tool.eraser, () => controller.setTool(Tool.eraser, label: "Eraser. Paper stays.")),
              _tool(Icons.format_color_fill, "Fill", Tool.fill, () => controller.setTool(Tool.fill, label: "Fill. Tap a region.")),
              _tool(Icons.colorize, "Pick", Tool.picker, () => controller.setTool(Tool.picker, label: "Eyedropper. Tap the sheet.")),
              _tool(Icons.crop_square, "Shape", Tool.shape, () {
                if (controller.tool == Tool.shape) {
                  onSheets("shape");
                } else {
                  controller.setTool(Tool.shape, label: "Shape. Drag a mark.");
                }
              }),
              _tool(Icons.pan_tool, "Move", Tool.hand, () => controller.setTool(Tool.hand, label: "Move. One finger pans.")),
              Pressable(
                label: "Pigment",
                onPressed: () => onSheets("color"),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: controller.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AtelierColors.rice),
                      ),
                    ),
                  ),
                ),
              ),
              _plain(Icons.layers, "Washes", () => onSheets("layers")),
              _plain(Icons.tune, "Desk", () => onSheets("more")),
            ],
          ),
        );
      },
    );
  }

  Widget _tool(IconData icon, String label, Tool tool, VoidCallback onTap) {
    final on = controller.tool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Pressable(
        label: label,
        onPressed: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AtelierColors.cinnabar : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AtelierColors.rice, size: 22),
        ),
      ),
    );
  }

  Widget _plain(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Pressable(
        label: label,
        onPressed: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AtelierColors.rice, size: 22)),
      ),
    );
  }
}

class _Sliders extends StatelessWidget {
  const _Sliders({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                _row(
                  context,
                  "Size",
                  controller.size,
                  1,
                  120,
                  (value) {
                    controller.size = value;
                    controller.touch();
                  },
                  controller.size.round().toString(),
                  (value) => controller.note("Size ${value.round()}."),
                ),
                _row(
                  context,
                  "Flow",
                  controller.flow,
                  0.04,
                  1,
                  (value) {
                    controller.flow = value;
                    controller.touch();
                  },
                  "${(controller.flow * 100).round()}",
                  (value) => controller.note("Flow ${(value * 100).round()}."),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String readout,
    ValueChanged<double> onEnd,
  ) {
    return Row(
      children: [
        SizedBox(width: 44, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged, onChangeEnd: onEnd),
        ),
        SizedBox(width: 36, child: Text(readout, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AtelierColors.rice))),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _BrushSheet extends StatelessWidget {
  const _BrushSheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: "Brushes",
      child: Column(
        children: [
          for (final brush in brushes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(brush.name, style: TextStyle(color: controller.brush.id == brush.id ? AtelierColors.cinnabar : AtelierColors.rice)),
              subtitle: Text(brush.hint),
              onTap: () {
                controller.selectBrush(brush);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _ShapeSheet extends StatelessWidget {
  const _ShapeSheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, ShapeKind kind) {
      final on = controller.shape == kind;
      return Expanded(
        child: Pressable(
          label: label,
          onPressed: () {
            controller.setShape(kind);
            Navigator.pop(context);
          },
          child: Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? AtelierColors.cinnabar : AtelierColors.line),
            ),
            child: Text(label, style: TextStyle(color: on ? AtelierColors.cinnabar : AtelierColors.rice)),
          ),
        ),
      );
    }

    return _SheetFrame(
      title: "Marks",
      child: Row(
        children: [
          chip("Line", ShapeKind.line),
          const SizedBox(width: 8),
          chip("Frame", ShapeKind.rect),
          const SizedBox(width: 8),
          chip("Moon", ShapeKind.ellipse),
        ],
      ),
    );
  }
}

class _ColorSheet extends StatelessWidget {
  const _ColorSheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(controller.color);
    return _SheetFrame(
      title: "Pigment",
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Recent", style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final recent in controller.recent)
                    _swatch(recent, () => controller.setColor(recent)),
                ],
              ),
              const SizedBox(height: 12),
              Text("Hue", style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: hsv.hue,
                max: 360,
                onChanged: (hue) => controller.setColor(hsv.withHue(hue).toColor(), quiet: true),
                onChangeEnd: (hue) {
                  controller.remember(hsv.withHue(hue).toColor());
                  controller.note("Pigment set.");
                },
              ),
              Text("Ink depth", style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: hsv.value,
                max: 1,
                onChanged: (value) => controller.setColor(hsv.withValue(value).toColor(), quiet: true),
                onChangeEnd: (value) {
                  controller.remember(hsv.withValue(value).toColor());
                  controller.note("Pigment set.");
                },
              ),
              for (final group in swatches) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(group.name.toUpperCase(), style: Theme.of(context).textTheme.bodySmall),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in group.colors) _swatch(Color(color), () => controller.setColor(Color(color))),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _swatch(Color color, VoidCallback onTap) {
    return Pressable(
      label: "Color",
      onPressed: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AtelierColors.line),
        ),
      ),
    );
  }
}

class _LayerSheet extends StatelessWidget {
  const _LayerSheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (context, scroll) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final doc = controller.doc;
            if (doc == null) return const SizedBox.shrink();
            final index = doc.active;
            final layer = doc.layers[index];
            return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text("Washes", style: Theme.of(context).textTheme.headlineMedium),
                for (var i = doc.layers.length - 1; i >= 0; i--)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: i == index,
                    title: Text(doc.layers[i].name, style: TextStyle(color: i == index ? AtelierColors.cinnabar : AtelierColors.rice)),
                    trailing: Icon(doc.layers[i].visible ? Icons.visibility : Icons.visibility_off, color: AtelierColors.mist),
                    onTap: () => controller.activate(i),
                  ),
                Text("Opacity of ${layer.name}", style: Theme.of(context).textTheme.bodySmall),
                Slider(
                  value: layer.opacity,
                  min: 0.05,
                  max: 1,
                  onChanged: (value) => controller.setOpacity(index, value),
                  onChangeEnd: (_) => controller.note("Opacity ${(layer.opacity * 100).round()}."),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _act(context, "Hide", () => controller.toggleVisible(index)),
                    _act(context, "Up", () => controller.moveLayer(index, 1)),
                    _act(context, "Down", () => controller.moveLayer(index, -1)),
                    _act(context, "Copy", () => controller.duplicateLayer(index)),
                    _act(context, "Merge", () => controller.mergeDown(index)),
                    _act(context, "Rename", () => _rename(context, index, layer.name)),
                    _act(context, "Remove", () => controller.removeLayer(index)),
                  ],
                ),
                TextButton.icon(
                  onPressed: controller.addLayer,
                  icon: const Icon(Icons.add, color: AtelierColors.cinnabar),
                  label: const Text("Add a wash", style: TextStyle(color: AtelierColors.cinnabar)),
                ),
              ],
            ),
          );
          },
        );
      },
    );
  }

  Widget _act(BuildContext context, String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AtelierColors.raise,
      labelStyle: const TextStyle(color: AtelierColors.rice),
    );
  }

  Future<void> _rename(BuildContext context, int index, String name) async {
    final text = TextEditingController(text: name);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename wash"),
        content: TextField(controller: text, autofocus: true, decoration: const InputDecoration(hintText: "Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, text.text), child: const Text("Rename")),
        ],
      ),
    );
    text.dispose();
    if (next != null) controller.rename(index, next);
  }
}

class _DeskSheet extends StatelessWidget {
  const _DeskSheet({required this.controller, required this.onFit, required this.onPicture});

  final EditorController controller;
  final VoidCallback onFit;
  final VoidCallback onPicture;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return _SheetFrame(
          title: "The desk",
          child: Column(
            children: [
              _toggle(context, "Mirror", controller.mirror, controller.toggleMirror),
              _toggle(context, "Grid", controller.grid, controller.toggleGrid),
              _toggle(context, "One-point guide", controller.vanish, controller.toggleVanish),
              Row(
                children: [
                  const Text("Steady", style: TextStyle(color: AtelierColors.mist)),
                  Expanded(
                    child: Slider(
                      value: controller.stabilize,
                      max: 0.85,
                      onChanged: (value) {
                        controller.stabilize = value;
                        controller.touch();
                      },
                      onChangeEnd: (value) => controller.note("Steady ${(value * 100).round()}."),
                    ),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Fit the sheet"),
                onTap: () {
                  Navigator.pop(context);
                  onFit();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Place a picture"),
                subtitle: const Text("A new wash, so you can draw over it."),
                onTap: onPicture,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Clear this wash", style: TextStyle(color: AtelierColors.cinnabar)),
                onTap: () {
                  Navigator.pop(context);
                  controller.clearActive();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggle(BuildContext context, String label, bool on, VoidCallback toggle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(on ? "On" : "Off", style: TextStyle(color: on ? AtelierColors.rice : AtelierColors.mist)),
      onTap: toggle,
    );
  }
}
