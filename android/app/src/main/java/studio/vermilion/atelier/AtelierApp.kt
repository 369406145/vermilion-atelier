package studio.vermilion.atelier

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.CleaningServices
import androidx.compose.material.icons.filled.Colorize
import androidx.compose.material.icons.filled.CropSquare
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FormatColorFill
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.Redo
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID

private val Ink = Color(0xFF12100E)
private val Panel = Color(0xFF1C1814)
private val Raise = Color(0xFF2A241E)
private val Rice = Color(0xFFF4ECDF)
private val Mist = Color(0xFFA89880)
private val Cinnabar = Color(0xFFC44536)
private val Line = Color(0xFF3D342C)

private sealed interface Screen {
    data object Studio : Screen
    data object Prompts : Screen
    data class Create(val preset: String, val paper: PaperId, val promptTitle: String?) : Screen
    data class Edit(val draft: Draft) : Screen
}

@Composable
fun AtelierApp() {
    var screen by remember { mutableStateOf<Screen>(Screen.Studio) }
    var tick by remember { mutableIntStateOf(0) }
    Box(Modifier.fillMaxSize().background(Ink)) {
        when (val current = screen) {
            Screen.Studio -> StudioScreen(
                tick = tick,
                onCreate = { screen = Screen.Create("scroll", PaperId.XUAN, null) },
                onPrompts = { screen = Screen.Prompts },
                onOpen = { work ->
                    screen = Screen.Edit(
                        Draft(work.id, work.title, work.width, work.height, work.paper, existed = true),
                    )
                },
            )
            Screen.Prompts -> PromptsScreen(
                onStudio = { screen = Screen.Studio },
                onCreate = { screen = Screen.Create("scroll", PaperId.XUAN, null) },
                onUse = { prompt -> screen = Screen.Create(prompt.preset, prompt.paper, prompt.title) },
            )
            is Screen.Create -> CreateScreen(
                presetId = current.preset,
                paper = current.paper,
                promptTitle = current.promptTitle,
                onBack = { screen = Screen.Studio },
                onBegin = { draft -> screen = Screen.Edit(draft) },
            )
            is Screen.Edit -> EditorScreen(
                draft = current.draft,
                onExit = {
                    screen = Screen.Studio
                    tick++
                },
            )
        }
    }
}

@Composable
private fun StudioScreen(
    tick: Int,
    onCreate: () -> Unit,
    onPrompts: () -> Unit,
    onOpen: (WorkSummary) -> Unit,
) {
    val context = LocalContext.current
    var works by remember { mutableStateOf<List<WorkSummary>>(emptyList()) }
    var pending by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(tick) {
        works = withContext(Dispatchers.IO) { WorkStore.list(context) }
    }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Row(Modifier.fillMaxWidth().padding(top = 18.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Bottom) {
                Column {
                    Text("VERMILION", color = Cinnabar, fontSize = 12.sp, letterSpacing = 2.sp)
                    Text("Atelier", color = Rice, fontSize = 48.sp, fontFamily = FontFamily.Serif)
                }
                Box(Modifier.size(52.dp).border(2.dp, Cinnabar, RoundedCornerShape(6.dp)), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(28.dp).border(1.dp, Cinnabar, RoundedCornerShape(2.dp)))
                }
            }
            Text(
                "A pocket ink studio for people who think the page will refuse them. Wolf hair, mineral color, and a great deal of unpainted paper. Everything stays on this device.",
                color = Mist,
                modifier = Modifier.padding(top = 12.dp),
                lineHeight = 20.sp,
            )
            if (works.isEmpty()) {
                Column(Modifier.padding(top = 28.dp).fillMaxWidth().border(1.dp, Line, RoundedCornerShape(24.dp)).padding(20.dp)) {
                    Text("The cabinet is empty, which is the correct way to begin.", color = Rice, fontFamily = FontFamily.Serif, fontSize = 28.sp, lineHeight = 32.sp)
                    Text("Cut a sheet, or take a prompt that tells you when to stop.", color = Mist, modifier = Modifier.padding(top = 8.dp))
                }
            }
            works.chunked(2).forEach { row ->
                Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    row.forEach { work ->
                        Column(Modifier.weight(1f)) {
                            WorkThumb(work, Modifier.fillMaxWidth().height(210.dp).clip(RoundedCornerShape(16.dp)).clickable { onOpen(work) })
                            Text(work.title, color = Rice, fontFamily = FontFamily.Serif, fontSize = 20.sp, maxLines = 1)
                            Text(ago(work.updatedAt) + " · " + work.paper.name.lowercase(), color = Mist, fontSize = 12.sp)
                            if (pending == work.id) {
                                Row {
                                    TextButton(onClick = {
                                        WorkStore.delete(context, work.id)
                                        pending = null
                                        works = works.filter { it.id != work.id }
                                    }) { Text("Delete", color = Cinnabar) }
                                    TextButton(onClick = { pending = null }) { Text("Keep", color = Rice) }
                                }
                            } else {
                                TextButton(onClick = { pending = work.id }) { Text("Remove", color = Mist) }
                            }
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
            Spacer(Modifier.height(24.dp))
        }
        Dock(onStudio = {}, onCreate = onCreate, onPrompts = onPrompts, studio = true)
    }
}

@Composable
private fun WorkThumb(work: WorkSummary, modifier: Modifier) {
    val bmp = remember(work.thumb.absolutePath, work.updatedAt) {
        BitmapFactory.decodeFile(work.thumb.absolutePath)
    }
    if (bmp != null) {
        Image(
            bmp.asImageBitmap(),
            contentDescription = work.title,
            modifier = modifier.border(1.dp, Line, RoundedCornerShape(16.dp)),
            contentScale = ContentScale.Crop,
        )
    } else {
        Box(modifier.background(Raise))
    }
}

@Composable
private fun Dock(onStudio: () -> Unit, onCreate: () -> Unit, onPrompts: () -> Unit, studio: Boolean) {
    Row(
        Modifier.fillMaxWidth().background(Panel).navigationBarsPadding().padding(bottom = 8.dp, top = 6.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Column(
            Modifier.weight(1f).clickable(onClick = onStudio),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.size(8.dp).background(if (studio) Cinnabar else Mist, RoundedCornerShape(2.dp)))
            Text("Studio", color = if (studio) Cinnabar else Mist, fontSize = 12.sp)
        }
        Box(
            Modifier.size(56.dp).clip(CircleShape).background(Cinnabar).clickable(onClick = onCreate),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Add, contentDescription = "Cut a new sheet", tint = Rice)
        }
        Column(
            Modifier.weight(1f).clickable(onClick = onPrompts),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Filled.MenuBook, contentDescription = null, tint = if (studio) Mist else Cinnabar)
            Text("Prompts", color = if (studio) Mist else Cinnabar, fontSize = 12.sp)
        }
    }
}

@Composable
private fun PromptsScreen(onStudio: () -> Unit, onCreate: () -> Unit, onUse: (Prompt) -> Unit) {
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp)) {
            Text("RESTRAINTS", color = Cinnabar, letterSpacing = 2.sp, fontSize = 12.sp)
            Text("Prompts", color = Rice, fontFamily = FontFamily.Serif, fontSize = 48.sp)
            Text("Most pictures fail because they try to say everything. Pick one limit and obey it.", color = Mist, modifier = Modifier.padding(top = 8.dp, bottom = 16.dp))
            PROMPTS.forEach { prompt ->
                Column(Modifier.padding(bottom = 12.dp).fillMaxWidth().border(1.dp, Line, RoundedCornerShape(20.dp)).padding(16.dp)) {
                    Text(prompt.title, color = Rice, fontFamily = FontFamily.Serif, fontSize = 24.sp)
                    Text(prompt.text, color = Mist, modifier = Modifier.padding(top = 6.dp))
                    TextButton(onClick = { onUse(prompt) }) { Text("Use this sheet", color = Cinnabar) }
                }
            }
        }
        Dock(onStudio = onStudio, onCreate = onCreate, onPrompts = {}, studio = false)
    }
}

@Composable
private fun CreateScreen(
    presetId: String,
    paper: PaperId,
    promptTitle: String?,
    onBack: () -> Unit,
    onBegin: (Draft) -> Unit,
) {
    var chosenPreset by remember { mutableStateOf(presetId) }
    var chosenPaper by remember { mutableStateOf(paper) }
    var title by remember { mutableStateOf(promptTitle) }
    val context = LocalContext.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val preset = presetById(chosenPreset)
        onBegin(
            Draft(
                id = UUID.randomUUID().toString(),
                title = title ?: preset.name,
                width = preset.w,
                height = preset.h,
                paper = chosenPaper,
                existed = false,
                underlayUri = uri.toString(),
            ),
        )
    }
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("Back", color = Rice) }
            Text("Cut a sheet", color = Rice, fontFamily = FontFamily.Serif, fontSize = 28.sp, modifier = Modifier.weight(1f))
        }
        if (title != null) Text("For “$title”", color = Cinnabar, modifier = Modifier.padding(bottom = 8.dp))
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PAPERS.forEach { item ->
                val on = item.id == chosenPaper
                Text(
                    item.name + " · " + item.hint,
                    color = if (on) Rice else Rice,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(if (on) Cinnabar else Panel).clickable { chosenPaper = item.id }.padding(horizontal = 14.dp, vertical = 10.dp),
                )
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 12.dp)) {
            PRESETS.forEach { item ->
                val on = item.id == chosenPreset
                Row(
                    Modifier.padding(bottom = 8.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(if (on) Raise else Panel).border(1.dp, if (on) Cinnabar else Color.Transparent, RoundedCornerShape(16.dp)).clickable {
                        chosenPreset = item.id
                        if (promptTitle == null) title = null
                    }.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(item.ratio, color = Cinnabar, fontFamily = FontFamily.Serif, fontSize = 18.sp, modifier = Modifier.width(52.dp))
                    Column(Modifier.weight(1f)) {
                        Text(item.name, color = Rice)
                        Text(item.blurb, color = Mist, fontSize = 13.sp)
                    }
                    Text("${item.w}×${item.h}", color = Mist, fontSize = 12.sp)
                }
            }
        }
        val preset = presetById(chosenPreset)
        Text(
            "Begin " + preset.name.lowercase(),
            color = Rice,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Cinnabar).clickable {
                onBegin(
                    Draft(
                        id = UUID.randomUUID().toString(),
                        title = title ?: preset.name,
                        width = preset.w,
                        height = preset.h,
                        paper = chosenPaper,
                        existed = false,
                    ),
                )
            }.padding(vertical = 14.dp),
            fontSize = 16.sp,
        )
        TextButton(onClick = { picker.launch("image/*") }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Icon(Icons.Filled.Image, contentDescription = null, tint = Mist)
            Text("  Start from a picture", color = Mist)
        }
    }
}

@Composable
private fun EditorScreen(draft: Draft, onExit: () -> Unit) {
    val context = LocalContext.current
    val state = remember(draft.id) { EditorState(draft) }
    var sheet by remember { mutableStateOf<String?>(null) }
    var askLeave by remember { mutableStateOf(false) }
    LaunchedEffect(draft.id) {
        if (state.doc == null) {
            val created = withContext(Dispatchers.Default) { InkDocument.open(context, draft) }
            state.doc = created
        }
    }
    DisposableEffect(draft.id) {
        onDispose { state.doc?.recycle() }
    }
    Column(Modifier.fillMaxSize().background(Ink).statusBarsPadding()) {
        Row(Modifier.height(56.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            IconButton(Icons.Filled.Close, "Close") {
                if (state.doc?.dirty == true) askLeave = true else onExit()
            }
            androidx.compose.foundation.text.BasicTextField(
                value = state.title,
                onValueChange = {
                    state.title = it
                    state.doc?.dirty = true
                    state.doc?.title = it
                },
                textStyle = androidx.compose.ui.text.TextStyle(color = Rice, fontFamily = FontFamily.Serif, fontSize = 22.sp),
                modifier = Modifier.weight(1f),
                singleLine = true,
            )
            IconButton(Icons.Filled.Undo, "Undo", enabled = state.canUndo) {
                state.doc?.undo()
                state.refreshHistory()
            }
            IconButton(Icons.Filled.Redo, "Redo", enabled = state.canRedo) {
                state.doc?.redo()
                state.refreshHistory()
            }
            IconButton(Icons.Filled.Download, "Save image") { state.export(context) }
        }
        Row(Modifier.weight(1f).fillMaxWidth()) {
            Column(Modifier.width(56.dp).verticalScroll(rememberScrollState())) {
                ToolButton(Icons.Filled.Brush, "Brush", state.tool == Tool.BRUSH) {
                    state.tool = Tool.BRUSH
                    sheet = if (sheet == "brush") null else "brush"
                }
                ToolButton(Icons.Filled.CleaningServices, "Eraser", state.tool == Tool.ERASER) {
                    state.tool = Tool.ERASER
                    sheet = null
                }
                ToolButton(Icons.Filled.FormatColorFill, "Fill", state.tool == Tool.FILL) { state.tool = Tool.FILL; sheet = null }
                ToolButton(Icons.Filled.Colorize, "Pick", state.tool == Tool.PICKER) { state.tool = Tool.PICKER; sheet = null }
                ToolButton(Icons.Filled.CropSquare, "Shape", state.tool == Tool.SHAPE) {
                    state.tool = Tool.SHAPE
                    sheet = if (sheet == "shape") null else "shape"
                }
                ToolButton(Icons.Filled.PanTool, "Move", state.tool == Tool.HAND) { state.tool = Tool.HAND; sheet = null }
                Box(
                    Modifier.size(44.dp).align(Alignment.CenterHorizontally).clickable { sheet = if (sheet == "color") null else "color" },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(Modifier.size(22.dp).clip(CircleShape).background(Color(state.color)).border(1.dp, Rice, CircleShape))
                }
                ToolButton(Icons.Filled.Layers, "Layers", sheet == "layers") { sheet = if (sheet == "layers") null else "layers" }
                ToolButton(Icons.Filled.Tune, "Desk", sheet == "more") { sheet = if (sheet == "more") null else "more" }
            }
            Box(Modifier.weight(1f).fillMaxSize()) {
                if (state.doc == null) {
                    Text("Grinding the ink…", color = Mist, modifier = Modifier.align(Alignment.Center))
                }
                AndroidView(
                    factory = { InkView(it) },
                    update = { view ->
                        view.model = state
                        view.fitIfNeeded()
                        view.contentDescription = listOf(
                            state.tool,
                            state.brush.id,
                            state.color,
                            state.size,
                            state.flow,
                            state.mirror,
                            state.grid,
                            state.vanish,
                            state.shape,
                            state.revision,
                        ).joinToString(" ")
                        view.invalidate()
                    },
                    onRelease = { it.model = null },
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        Column(Modifier.background(Panel).navigationBarsPadding().padding(horizontal = 16.dp, vertical = 6.dp)) {
            state.notice?.let { Text(it, color = Mist, fontSize = 12.sp) }
            LabeledSlider("Size", state.size, 1f, 120f) { state.size = it }
            LabeledSlider("Flow", state.flow, 0.04f, 1f) { state.flow = it }
        }
    }
    if (sheet != null) {
        Box(Modifier.fillMaxSize().background(Color(0xAA12100E)).clickable { sheet = null }) {
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)).background(Panel).clickable { }.padding(16.dp).navigationBarsPadding().verticalScroll(rememberScrollState()),
            ) {
                Text(
                    when (sheet) {
                        "brush" -> "Brushes"
                        "color" -> "Pigment"
                        "shape" -> "Marks"
                        "layers" -> "Washes"
                        else -> "The desk"
                    },
                    color = Rice,
                    fontFamily = FontFamily.Serif,
                    fontSize = 26.sp,
                )
                when (sheet) {
                    "brush" -> BRUSHES.forEach { brush ->
                        Text(
                            brush.name + "  ·  " + brush.hint,
                            color = if (state.brush.id == brush.id) Cinnabar else Rice,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp).clickable {
                                state.brush = brush
                                state.tool = Tool.BRUSH
                                sheet = null
                            },
                        )
                    }
                    "color" -> ColorBlock(state)
                    "shape" -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ShapeChip("Line", state.shape == ShapeKind.LINE) { state.shape = ShapeKind.LINE; state.tool = Tool.SHAPE; sheet = null }
                        ShapeChip("Frame", state.shape == ShapeKind.RECT) { state.shape = ShapeKind.RECT; state.tool = Tool.SHAPE; sheet = null }
                        ShapeChip("Moon", state.shape == ShapeKind.ELLIPSE) { state.shape = ShapeKind.ELLIPSE; state.tool = Tool.SHAPE; sheet = null }
                    }
                    "layers" -> LayerBlock(state) { sheet = null }
                    else -> DeskBlock(state)
                }
                Spacer(Modifier.height(12.dp))
            }
        }
    }
    if (askLeave) {
        Box(Modifier.fillMaxSize().background(Color(0xCC12100E)), contentAlignment = Alignment.Center) {
            Column(Modifier.padding(24.dp).clip(RoundedCornerShape(24.dp)).background(Panel).padding(20.dp)) {
                Text("Leave the sheet?", color = Rice, fontFamily = FontFamily.Serif, fontSize = 28.sp)
                Text("Unsaved ink stays only if you keep it on this device.", color = Mist, modifier = Modifier.padding(top = 6.dp, bottom = 12.dp))
                Text(
                    "Keep and leave",
                    color = Rice,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Cinnabar).clickable {
                    state.save(context)
                    askLeave = false
                    onExit()
                }.padding(vertical = 12.dp))
                val existed = draft.existed || state.doc?.persisted == true
                Text(
                    if (existed) "Leave without saving" else "Throw this sheet away",
                    color = Rice,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Raise).clickable {
                        if (!draft.existed && state.doc?.persisted == true) WorkStore.delete(context, draft.id)
                        askLeave = false
                        onExit()
                    }.padding(vertical = 12.dp),
                )
                TextButton(onClick = { askLeave = false }) { Text("Keep painting", color = Mist) }
            }
        }
    }
}

@Composable
private fun ColorBlock(state: EditorState) {
    SWATCHES.forEach { group ->
        Text(group.name.uppercase(), color = Mist, fontSize = 11.sp, letterSpacing = 1.sp, modifier = Modifier.padding(top = 10.dp, bottom = 6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            group.colors.forEach { swatch ->
                Box(
                    Modifier.size(28.dp).clip(RoundedCornerShape(4.dp)).background(Color(swatch)).border(1.dp, Line, RoundedCornerShape(4.dp)).clickable {
                        state.color = swatch
                    },
                )
            }
        }
    }
}

@Composable
private fun LayerBlock(state: EditorState, close: () -> Unit) {
    val doc = state.doc ?: return
    state.revision
    doc.layers.forEachIndexed { index, layer ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                layer.name,
                color = if (index == doc.active) Cinnabar else Rice,
                modifier = Modifier.weight(1f).clickable {
                    doc.active = index
                    state.refreshHistory()
                    close()
                }.padding(vertical = 8.dp),
            )
            IconButton(if (layer.visible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, "Visibility") {
                layer.visible = !layer.visible
                state.refreshHistory()
            }
            IconButton(Icons.Filled.Delete, "Remove wash") {
                doc.removeLayer(index)
                state.refreshHistory()
            }
        }
    }
    TextButton(onClick = {
        if (!doc.addLayer()) state.notice = "Eight washes is the limit"
        state.refreshHistory()
    }) { Text("Add a wash", color = Cinnabar) }
}

@Composable
private fun DeskBlock(state: EditorState) {
    ToggleLine("Mirror", state.mirror) { state.mirror = !state.mirror }
    ToggleLine("Grid", state.grid) { state.grid = !state.grid }
    ToggleLine("One-point guide", state.vanish) { state.vanish = !state.vanish }
    Text("Steady", color = Mist, modifier = Modifier.padding(top = 8.dp))
    Slider(value = state.stabilize, onValueChange = { state.stabilize = it }, valueRange = 0f..0.85f)
    TextButton(onClick = {
        state.doc?.beginChange()
        state.doc?.clearActive()
        state.doc?.commitChange()
        state.refreshHistory()
    }) { Text("Clear this wash", color = Cinnabar) }
}

@Composable
private fun ToggleLine(label: String, on: Boolean, click: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = click).padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Rice)
        Text(if (on) "On" else "Off", color = if (on) Rice else Mist, modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(if (on) Cinnabar else Raise).padding(horizontal = 10.dp, vertical = 4.dp))
    }
}

@Composable
private fun ShapeChip(label: String, on: Boolean, click: () -> Unit) {
    Text(label, color = if (on) Cinnabar else Rice, modifier = Modifier.clip(RoundedCornerShape(12.dp)).border(1.dp, if (on) Cinnabar else Line, RoundedCornerShape(12.dp)).clickable(onClick = click).padding(horizontal = 16.dp, vertical = 12.dp))
}

@Composable
private fun LabeledSlider(label: String, value: Float, min: Float, max: Float, onChange: (Float) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = Mist, modifier = Modifier.width(44.dp), fontSize = 12.sp)
        Slider(value = value, onValueChange = onChange, valueRange = min..max, modifier = Modifier.weight(1f))
        Text(if (max <= 1.1f) "${(value * 100).toInt()}" else value.toInt().toString(), color = Rice, modifier = Modifier.width(36.dp), fontSize = 12.sp)
    }
}

@Composable
private fun ColumnScope.ToolButton(icon: ImageVector, label: String, active: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.padding(vertical = 2.dp).size(44.dp).align(Alignment.CenterHorizontally).clip(RoundedCornerShape(14.dp)).background(if (active) Cinnabar else Color.Transparent).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = Rice)
    }
}

@Composable
private fun IconButton(icon: ImageVector, label: String, enabled: Boolean = true, onClick: () -> Unit) {
    Box(Modifier.size(44.dp).clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = label, tint = if (enabled) Rice else Mist.copy(alpha = 0.4f))
    }
}

private fun ago(ts: Long): String {
    val s = ((System.currentTimeMillis() - ts) / 1000).coerceAtLeast(0)
    return when {
        s < 45 -> "Just now"
        s < 3600 -> "${s / 60}m ago"
        s < 86400 -> "${s / 3600}h ago"
        else -> "${s / 86400}d ago"
    }
}
