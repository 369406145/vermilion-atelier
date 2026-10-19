package studio.vermilion.atelier

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class EditorState(val draft: Draft) {
    var doc by mutableStateOf<InkDocument?>(null)
    var tool by mutableStateOf(Tool.BRUSH)
    var brush by mutableStateOf(BRUSHES[0])
    var color by mutableIntStateOf(0xFF1A120E.toInt())
    var size by mutableFloatStateOf(18f)
    var flow by mutableFloatStateOf(0.9f)
    var mirror by mutableStateOf(false)
    var stabilize by mutableFloatStateOf(0.28f)
    var shape by mutableStateOf(ShapeKind.LINE)
    var grid by mutableStateOf(false)
    var vanish by mutableStateOf(false)
    var vanishX by mutableFloatStateOf(0.5f)
    var vanishY by mutableFloatStateOf(0.42f)
    var canUndo by mutableStateOf(false)
    var canRedo by mutableStateOf(false)
    var revision by mutableIntStateOf(0)
    var title by mutableStateOf(draft.title)
    var notice by mutableStateOf<String?>(null)

    fun refreshHistory() {
        val drawing = doc ?: return
        canUndo = drawing.canUndo
        canRedo = drawing.canRedo
        revision++
    }

    fun save(context: Context) {
        val drawing = doc ?: return
        drawing.title = title.trim().ifBlank { "Untitled sheet" }
        title = drawing.title
        val thumb = drawing.composite(480)
        WorkStore.save(context, drawing, thumb)
        thumb.recycle()
        notice = "Kept on this device"
    }

    fun export(context: Context) {
        val drawing = doc ?: return
        save(context)
        val full = drawing.composite()
        val ok = WorkStore.exportPng(context, full, drawing.title)
        full.recycle()
        notice = if (ok) "Saved a PNG" else "Could not write the PNG"
    }
}
