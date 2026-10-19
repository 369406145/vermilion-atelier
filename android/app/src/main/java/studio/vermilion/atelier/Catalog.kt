package studio.vermilion.atelier

enum class PaperId { PLAIN, XUAN, COARSE, SILK }

enum class Tool { BRUSH, ERASER, FILL, PICKER, SHAPE, HAND }

enum class ShapeKind { LINE, RECT, ELLIPSE }

enum class BrushKind { SOLID, DRY, SPEED }

data class BrushSpec(
    val id: String,
    val name: String,
    val hint: String,
    val spacing: Float,
    val hard: Float,
    val baseFlow: Float,
    val kind: BrushKind,
)

data class PaperChoice(val id: PaperId, val name: String, val hint: String)

data class Preset(
    val id: String,
    val name: String,
    val ratio: String,
    val w: Int,
    val h: Int,
    val blurb: String,
)

data class Prompt(
    val id: String,
    val title: String,
    val text: String,
    val preset: String,
    val paper: PaperId,
)

data class SwatchGroup(val name: String, val colors: List<Int>)

data class Draft(
    val id: String,
    val title: String,
    val width: Int,
    val height: Int,
    val paper: PaperId,
    val existed: Boolean,
    val underlayUri: String? = null,
)

val PAPERS = listOf(
    PaperChoice(PaperId.PLAIN, "Bare", "No tooth"),
    PaperChoice(PaperId.XUAN, "Xuan", "Soft fiber"),
    PaperChoice(PaperId.COARSE, "Cold press", "Hungry paper"),
    PaperChoice(PaperId.SILK, "Raw silk", "Warm ground"),
)

val PRESETS = listOf(
    Preset("scroll", "Hanging scroll", "9:16", 540, 960, "A single column of quiet."),
    Preset("leaf", "Album leaf", "3:4", 630, 840, "The size of a page you can hold."),
    Preset("seal", "Seal square", "1:1", 800, 800, "A moon, a bowl, a mark."),
    Preset("hand", "Handscroll", "16:9", 960, 540, "Read it sideways, or refuse to."),
    Preset("screen", "Screen panel", "4:3", 880, 660, "Wide enough for a room."),
    Preset("letter", "Letter sheet", "A4", 620, 877, "Leave room for a sentence."),
    Preset("card", "Postcard", "3:2", 900, 600, "Something you could actually send."),
)

val BRUSHES = listOf(
    BrushSpec("wolf", "Wolf hair", "A decisive edge.", 0.16f, 0.62f, 0.92f, BrushKind.SOLID),
    BrushSpec("goat", "Goat wash", "Wide, thirsty, and slow.", 0.20f, 0.02f, 0.38f, BrushKind.SOLID),
    BrushSpec("pine", "Dry pine", "The paper shows through.", 0.32f, 0.45f, 0.85f, BrushKind.DRY),
    BrushSpec("reed", "Reed pen", "Thins when you hurry.", 0.10f, 0.78f, 1f, BrushKind.SPEED),
    BrushSpec("soot", "Soot stump", "Charcoal, not a line.", 0.14f, 0.08f, 0.55f, BrushKind.SOLID),
)

val SWATCHES = listOf(
    SwatchGroup("Ink", listOf(0xFF14110E, 0xFF3A342C, 0xFF6E6558, 0xFFA39886, 0xFFD9D0C0, 0xFFF4ECDF).map { it.toInt() }),
    SwatchGroup("Minerals", listOf(0xFF8D1F22, 0xFFC44536, 0xFFD4783A, 0xFFE2B657, 0xFF2F6F62, 0xFF1D4E79, 0xFF6B4C7A, 0xFFF0E2C8).map { it.toInt() }),
    SwatchGroup("Blossom", listOf(0xFFF0C4CB, 0xFFD45D7E, 0xFF8E3148, 0xFFEFD7A2, 0xFF6F9A62, 0xFF2F5344, 0xFFD5E3EA, 0xFF2E3D48).map { it.toInt() }),
)

val PROMPTS = listOf(
    Prompt("pine", "Three strokes of pine", "A trunk, a reach, and the sky you refuse to fill. Stop at three.", "scroll", PaperId.XUAN),
    Prompt("river", "The unpainted river", "The blank sheet is the water. Only the banks deserve ink.", "hand", PaperId.PLAIN),
    Prompt("lantern", "One lantern", "Night everywhere else. The lantern is the only mineral color you may use.", "leaf", PaperId.COARSE),
    Prompt("seal", "A seal, not a signature", "A square, slightly wrong on purpose. Cinnabar, then stop.", "seal", PaperId.SILK),
    Prompt("window", "Borrowed scenery", "Draw the window first. What sits beyond it can be three marks.", "screen", PaperId.XUAN),
    Prompt("letter", "The letter you will not send", "A fold, one sentence, and the ring where the tea sat.", "letter", PaperId.PLAIN),
    Prompt("bowl", "Bowl with a crack", "Mend the crack in cinnabar. The repair is the subject.", "seal", PaperId.COARSE),
    Prompt("rain", "Rain that missed the mountain", "A horizontal wash, one dark ridge. No raindrops. They always lie.", "hand", PaperId.XUAN),
)

fun presetById(id: String) = PRESETS.find { it.id == id } ?: PRESETS[0]
