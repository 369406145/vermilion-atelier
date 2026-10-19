package studio.vermilion.atelier

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class DocLayer(var name: String, var visible: Boolean, val bmp: Bitmap)

class InkDocument(
    val id: String,
    var title: String,
    val width: Int,
    val height: Int,
    val paperId: PaperId,
    val paper: Bitmap,
    val layers: MutableList<DocLayer>,
) {
    var active: Int = 0
    var dirty: Boolean = false
    var persisted: Boolean = false
    var zoom: Float = 1f
    var panX: Float = 0f
    var panY: Float = 0f

    private data class Snap(val index: Int, val bmp: Bitmap)
    private val undo = ArrayDeque<Snap>()
    private val redo = ArrayDeque<Snap>()
    private var checkpoint: Bitmap? = null

    val canUndo: Boolean get() = undo.isNotEmpty()
    val canRedo: Boolean get() = redo.isNotEmpty()

    fun beginChange() {
        checkpoint?.recycle()
        checkpoint = layers[active].bmp.copy(Bitmap.Config.ARGB_8888, false)
    }

    fun commitChange() {
        val snap = checkpoint ?: return
        undo.addLast(Snap(active, snap))
        while (undo.size > 16) undo.removeFirst().bmp.recycle()
        redo.forEach { it.bmp.recycle() }
        redo.clear()
        checkpoint = null
        dirty = true
    }

    fun cancelChange() {
        val snap = checkpoint ?: return
        restoreBitmap(layers[active].bmp, snap)
        snap.recycle()
        checkpoint = null
    }

    fun undo() {
        val snap = undo.removeLastOrNull() ?: return
        if (snap.index !in layers.indices) {
            snap.bmp.recycle()
            return
        }
        val current = layers[snap.index].bmp.copy(Bitmap.Config.ARGB_8888, false)
        restoreBitmap(layers[snap.index].bmp, snap.bmp)
        snap.bmp.recycle()
        redo.addLast(Snap(snap.index, current))
    }

    fun redo() {
        val snap = redo.removeLastOrNull() ?: return
        if (snap.index !in layers.indices) {
            snap.bmp.recycle()
            return
        }
        val current = layers[snap.index].bmp.copy(Bitmap.Config.ARGB_8888, false)
        restoreBitmap(layers[snap.index].bmp, snap.bmp)
        snap.bmp.recycle()
        undo.addLast(Snap(snap.index, current))
    }

    private fun dropHistory() {
        checkpoint?.recycle()
        checkpoint = null
        undo.forEach { it.bmp.recycle() }
        undo.clear()
        redo.forEach { it.bmp.recycle() }
        redo.clear()
    }

    private fun canvas(): Canvas = Canvas(layers[active].bmp)

    fun paintTo(
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float,
        brush: BrushSpec,
        radius: Float,
        color: Int,
        flow: Float,
        erase: Boolean,
        mirror: Boolean,
    ) {
        paintSegment(
            canvas(),
            x1, y1, x2, y2,
            brush, radius, color, flow, erase,
            if (mirror) width.toFloat() else null,
        )
    }

    fun drawShape(
        kind: ShapeKind,
        ax: Float,
        ay: Float,
        bx: Float,
        by: Float,
        color: Int,
        stroke: Float,
        alpha: Float,
        mirror: Boolean,
    ) {
        val canvas = canvas()
        strokeShape(canvas, kind, ax, ay, bx, by, color, stroke, alpha)
        if (mirror) {
            strokeShape(canvas, kind, width - ax, ay, width - bx, by, color, stroke, alpha)
        }
    }

    fun fill(x: Float, y: Float, color: Int, alpha: Float) {
        floodFill(layers[active].bmp, x.roundToInt(), y.roundToInt(), color, alpha)
    }

    fun pick(x: Float, y: Float): Int {
        val ix = x.roundToInt().coerceIn(0, width - 1)
        val iy = y.roundToInt().coerceIn(0, height - 1)
        for (i in layers.indices.reversed()) {
            val layer = layers[i]
            if (!layer.visible) continue
            val pixel = layer.bmp.getPixel(ix, iy)
            if (Color.alpha(pixel) > 12) return pixel or 0xFF000000.toInt()
        }
        return paper.getPixel(ix, iy)
    }

    fun clearActive() {
        layers[active].bmp.eraseColor(Color.TRANSPARENT)
    }

    fun addLayer(): Boolean {
        if (layers.size >= 8) return false
        dropHistory()
        val index = active + 1
        layers.add(index, DocLayer("Wash ${layers.size + 1}", true, emptyLayer(width, height)))
        active = index
        return true
    }

    fun removeLayer(index: Int) {
        if (layers.size <= 1 || index !in layers.indices) return
        dropHistory()
        layers.removeAt(index).bmp.recycle()
        active = when {
            index < active -> active - 1
            index == active -> max(0, index - 1)
            else -> active
        }.coerceAtMost(layers.lastIndex)
    }

    fun composite(maxSide: Int = 0): Bitmap {
        val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawBitmap(paper, 0f, 0f, null)
        layers.forEach { if (it.visible) canvas.drawBitmap(it.bmp, 0f, 0f, null) }
        if (maxSide <= 0) return out
        val scale = maxSide.toFloat() / max(width, height)
        val tw = max(1, (width * scale).roundToInt())
        val th = max(1, (height * scale).roundToInt())
        val scaled = Bitmap.createScaledBitmap(out, tw, th, true)
        if (scaled != out) out.recycle()
        return scaled
    }

    fun recycle() {
        checkpoint?.recycle()
        undo.forEach { it.bmp.recycle() }
        redo.forEach { it.bmp.recycle() }
        paper.recycle()
        layers.forEach { it.bmp.recycle() }
    }

    companion object {
        fun open(context: Context, draft: Draft): InkDocument {
            val paper = renderPaper(draft.width, draft.height, draft.paper)
            val layers = mutableListOf<DocLayer>()
            var active = 0
            var persisted = false
            if (draft.existed) {
                val stored = WorkStore.load(context, draft.id)
                if (stored != null) {
                    stored.layers.forEach { (meta, bmp) ->
                        val fitted = if (bmp.width == draft.width && bmp.height == draft.height) {
                            bmp
                        } else {
                            val scaled = Bitmap.createScaledBitmap(bmp, draft.width, draft.height, true)
                            bmp.recycle()
                            scaled
                        }
                        layers += DocLayer(meta.name, meta.visible, fitted)
                    }
                    persisted = true
                }
            }
            if (layers.isEmpty() && draft.underlayUri != null) {
                val base = emptyLayer(draft.width, draft.height)
                drawContain(context, base, Uri.parse(draft.underlayUri))
                layers += DocLayer("Picture", true, base)
                layers += DocLayer("Ink", true, emptyLayer(draft.width, draft.height))
                active = 1
            }
            if (layers.isEmpty()) {
                layers += DocLayer("Ink", true, emptyLayer(draft.width, draft.height))
            }
            return InkDocument(draft.id, draft.title, draft.width, draft.height, draft.paper, paper, layers).apply {
                this.active = active.coerceIn(0, this.layers.lastIndex)
                this.persisted = persisted
            }
        }

        private fun drawContain(context: Context, layer: Bitmap, uri: Uri) {
            val src = context.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input)
            } ?: return
            val scale = min(layer.width.toFloat() / src.width, layer.height.toFloat() / src.height)
            val w = src.width * scale
            val h = src.height * scale
            val canvas = Canvas(layer)
            val left = (layer.width - w) / 2f
            val top = (layer.height - h) / 2f
            canvas.drawBitmap(src, null, android.graphics.RectF(left, top, left + w, top + h), null)
            src.recycle()
        }
    }
}
