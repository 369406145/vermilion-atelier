import 'dart:typed_data';

enum PaperId { plain, xuan, coarse, silk }

enum Tool { brush, eraser, fill, picker, shape, hand }

enum ShapeKind { line, rect, ellipse }

enum BrushKind { solid, dry, speed }

class BrushSpec {
  const BrushSpec(this.id, this.name, this.hint, this.spacing, this.hard, this.baseFlow, this.kind);
  final String id;
  final String name;
  final String hint;
  final double spacing;
  final double hard;
  final double baseFlow;
  final BrushKind kind;
}

class PaperChoice {
  const PaperChoice(this.id, this.name, this.hint);
  final PaperId id;
  final String name;
  final String hint;
}

class Preset {
  const Preset(this.id, this.name, this.ratio, this.w, this.h, this.blurb);
  final String id;
  final String name;
  final String ratio;
  final int w;
  final int h;
  final String blurb;
}

class Prompt {
  const Prompt(this.id, this.title, this.text, this.preset, this.paper);
  final String id;
  final String title;
  final String text;
  final String preset;
  final PaperId paper;
}

class SwatchGroup {
  const SwatchGroup(this.name, this.colors);
  final String name;
  final List<int> colors;
}

class Draft {
  const Draft({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.paper,
    this.existed = false,
    this.underlay,
  });

  final String id;
  final String title;
  final int width;
  final int height;
  final PaperId paper;
  final bool existed;
  final Uint8List? underlay;
}

const papers = [
  PaperChoice(PaperId.plain, "Bare", "No tooth"),
  PaperChoice(PaperId.xuan, "Xuan", "Soft fiber"),
  PaperChoice(PaperId.coarse, "Cold press", "Hungry paper"),
  PaperChoice(PaperId.silk, "Raw silk", "Warm ground"),
];

const presets = [
  Preset("scroll", "Hanging scroll", "9:16", 540, 960, "A single column of quiet."),
  Preset("leaf", "Album leaf", "3:4", 630, 840, "The size of a page you can hold."),
  Preset("seal", "Seal square", "1:1", 800, 800, "A moon, a bowl, a mark."),
  Preset("hand", "Handscroll", "16:9", 960, 540, "Read it sideways, or refuse to."),
  Preset("screen", "Screen panel", "4:3", 880, 660, "Wide enough for a room."),
  Preset("letter", "Letter sheet", "A4", 620, 877, "Leave room for a sentence."),
  Preset("card", "Postcard", "3:2", 900, 600, "Something you could actually send."),
];

const brushes = [
  BrushSpec("wolf", "Wolf hair", "A decisive edge.", 0.16, 0.62, 0.92, BrushKind.solid),
  BrushSpec("goat", "Goat wash", "Wide, thirsty, and slow.", 0.20, 0.02, 0.38, BrushKind.solid),
  BrushSpec("pine", "Dry pine", "The paper shows through.", 0.32, 0.45, 0.85, BrushKind.dry),
  BrushSpec("reed", "Reed pen", "Thins when you hurry.", 0.10, 0.78, 1, BrushKind.speed),
  BrushSpec("soot", "Soot stump", "Charcoal, not a line.", 0.14, 0.08, 0.55, BrushKind.solid),
];

const swatches = [
  SwatchGroup("Ink", [0xFF14110E, 0xFF3A342C, 0xFF6E6558, 0xFFA39886, 0xFFD9D0C0, 0xFFF4ECDF]),
  SwatchGroup("Minerals", [0xFF8D1F22, 0xFFC44536, 0xFFD4783A, 0xFFE2B657, 0xFF2F6F62, 0xFF1D4E79, 0xFF6B4C7A, 0xFFF0E2C8]),
  SwatchGroup("Blossom", [0xFFF0C4CB, 0xFFD45D7E, 0xFF8E3148, 0xFFEFD7A2, 0xFF6F9A62, 0xFF2F5344, 0xFFD5E3EA, 0xFF2E3D48]),
];

const prompts = [
  Prompt("pine", "Three strokes of pine", "A trunk, a reach, and the sky you refuse to fill. Stop at three.", "scroll", PaperId.xuan),
  Prompt("river", "The unpainted river", "The blank sheet is the water. Only the banks deserve ink.", "hand", PaperId.plain),
  Prompt("lantern", "One lantern", "Night everywhere else. The lantern is the only mineral color you may use.", "leaf", PaperId.coarse),
  Prompt("seal", "A seal, not a signature", "A square, slightly wrong on purpose. Cinnabar, then stop.", "seal", PaperId.silk),
  Prompt("window", "Borrowed scenery", "Draw the window first. What sits beyond it can be three marks.", "screen", PaperId.xuan),
  Prompt("letter", "The letter you will not send", "A fold, one sentence, and the ring where the tea sat.", "letter", PaperId.plain),
  Prompt("bowl", "Bowl with a crack", "Mend the crack in cinnabar. The repair is the subject.", "seal", PaperId.coarse),
  Prompt("rain", "Rain that missed the mountain", "A horizontal wash, one dark ridge. No raindrops. They always lie.", "hand", PaperId.xuan),
];

Preset presetById(String id) {
  for (final item in presets) {
    if (item.id == id) return item;
  }
  return presets.first;
}

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String ago(int millis) {
  final seconds = ((DateTime.now().millisecondsSinceEpoch - millis) / 1000).floor().clamp(0, 1 << 30);
  if (seconds < 45) return "Just now";
  if (seconds < 3600) return "${seconds ~/ 60}m ago";
  if (seconds < 86400) return "${seconds ~/ 3600}h ago";
  return "${seconds ~/ 86400}d ago";
}
