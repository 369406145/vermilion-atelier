package studio.vermilion.atelier

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

class InkView(context: Context) : View(context) {
    var model: EditorState? = null
    private val pointers = LinkedHashMap<Int, Pair<Float, Float>>()
    private var strokeId: Int = -1
    private var lastX = 0f
    private var lastY = 0f
    private var shapeStart: Pair<Float, Float>? = null
    private var shapeEnd: Pair<Float, Float>? = null
    private var pinchStart: Pinch? = null
    private var fitted = false

    private val gridPaint = Paint().apply {
        color = 0x66C44536
        strokeWidth = 1f
    }
    private val guidePaint = Paint().apply {
        color = 0x73C44536
        strokeWidth = 1f
    }

    private data class Pinch(val dist: Float, val zoom: Float, val panX: Float, val panY: Float, val midX: Float, val midY: Float)

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        if (w > 0 && h > 0) fit()
    }

    fun fit() {
        val doc = model?.doc ?: return
        if (width == 0 || height == 0) return
        doc.zoom = min(width / doc.width.toFloat(), height / doc.height.toFloat()) * 0.92f
        doc.panX = 0f
        doc.panY = 0f
        fitted = true
        invalidate()
    }

    fun fitIfNeeded() {
        if (!fitted) fit()
    }

    override fun onDraw(canvas: Canvas) {
        val doc = model?.doc ?: return
        if (doc.paper.isRecycled) return
        val vm = model ?: return
        canvas.drawColor(0xFF12100E.toInt())
        canvas.save()
        canvas.translate(width / 2f + doc.panX, height / 2f + doc.panY)
        canvas.scale(doc.zoom, doc.zoom)
        canvas.translate(-doc.width / 2f, -doc.height / 2f)
        canvas.drawBitmap(doc.paper, 0f, 0f, null)
        doc.layers.forEach { layer ->
            if (layer.visible && !layer.bmp.isRecycled) canvas.drawBitmap(layer.bmp, 0f, 0f, null)
        }
        val start = shapeStart
        val end = shapeEnd
        if (start != null && end != null) {
            strokeShape(canvas, vm.shape, start.first, start.second, end.first, end.second, vm.color, vm.size, vm.flow)
            if (vm.mirror) {
                strokeShape(
                    canvas, vm.shape,
                    doc.width - start.first, start.second,
                    doc.width - end.first, end.second,
                    vm.color, vm.size, vm.flow,
                )
            }
        }
        if (vm.grid) {
            var x = 48f
            while (x < doc.width) {
                canvas.drawLine(x, 0f, x, doc.height.toFloat(), gridPaint)
                x += 48f
            }
            var y = 48f
            while (y < doc.height) {
                canvas.drawLine(0f, y, doc.width.toFloat(), y, gridPaint)
                y += 48f
            }
        }
        if (vm.vanish) {
            val cx = vm.vanishX * doc.width
            val cy = vm.vanishY * doc.height
            val len = hypot(doc.width.toFloat(), doc.height.toFloat())
            for (i in 0 until 12) {
                val ang = (i / 12f) * Math.PI.toFloat() * 2f
                canvas.drawLine(cx, cy, cx + kotlin.math.cos(ang) * len, cy + kotlin.math.sin(ang) * len, guidePaint)
            }
            canvas.drawCircle(cx, cy, 10f / doc.zoom, guidePaint)
        }
        canvas.restore()
    }

    private fun toDoc(sx: Float, sy: Float): Pair<Float, Float> {
        val doc = model?.doc ?: return 0f to 0f
        val x = (sx - width / 2f - doc.panX) / doc.zoom + doc.width / 2f
        val y = (sy - height / 2f - doc.panY) / doc.zoom + doc.height / 2f
        return x to y
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val doc = model?.doc ?: return false
        val vm = model ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                val index = event.actionIndex
                pointers[event.getPointerId(index)] = event.getX(index) to event.getY(index)
                if (pointers.size >= 2) {
                    cancelInProgress(doc)
                    val pts = pointers.values.toList()
                    val dist = max(1f, hypot(pts[0].first - pts[1].first, pts[0].second - pts[1].second))
                    pinchStart = Pinch(dist, doc.zoom, doc.panX, doc.panY, (pts[0].first + pts[1].first) / 2f, (pts[0].second + pts[1].second) / 2f)
                } else if (event.actionMasked == MotionEvent.ACTION_DOWN) {
                    startSingle(vm, doc, event.getPointerId(0), event.x, event.y)
                }
            }
            MotionEvent.ACTION_MOVE -> {
                for (i in 0 until event.pointerCount) {
                    pointers[event.getPointerId(i)] = event.getX(i) to event.getY(i)
                }
                val pinch = pinchStart
                if (pointers.size >= 2 && pinch != null) {
                    val pts = pointers.values.toList()
                    val dist = max(1f, hypot(pts[0].first - pts[1].first, pts[0].second - pts[1].second))
                    val midX = (pts[0].first + pts[1].first) / 2f
                    val midY = (pts[0].second + pts[1].second) / 2f
                    doc.zoom = clamp(pinch.zoom * (dist / pinch.dist), 0.15f, 8f)
                    doc.panX = pinch.panX + (midX - pinch.midX)
                    doc.panY = pinch.panY + (midY - pinch.midY)
                    invalidate()
                } else if (vm.tool == Tool.HAND && strokeId >= 0) {
                    val point = pointers[strokeId] ?: return true
                    doc.panX += point.first - lastX
                    doc.panY += point.second - lastY
                    lastX = point.first
                    lastY = point.second
                    invalidate()
                } else if (shapeStart != null) {
                    val point = pointers[strokeId] ?: return true
                    shapeEnd = toDoc(point.first, point.second)
                    invalidate()
                } else if (strokeId >= 0 && (vm.tool == Tool.BRUSH || vm.tool == Tool.ERASER)) {
                    val point = pointers[strokeId] ?: return true
                    val docPoint = toDoc(point.first, point.second)
                    val k = vm.stabilize
                    val x = lastX * k + docPoint.first * (1f - k)
                    val y = lastY * k + docPoint.second * (1f - k)
                    doc.paintTo(lastX, lastY, x, y, vm.brush, vm.size / 2f, vm.color, vm.flow, vm.tool == Tool.ERASER, vm.mirror)
                    lastX = x
                    lastY = y
                    invalidate()
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                val id = event.getPointerId(event.actionIndex)
                if (id == strokeId && event.actionMasked != MotionEvent.ACTION_POINTER_UP || pointers.size == 1) {
                    finishSingle(vm, doc, event)
                }
                pointers.remove(id)
                if (pointers.size < 2) pinchStart = null
                if (pointers.isEmpty()) strokeId = -1
            }
        }
        return true
    }

    private fun startSingle(vm: EditorState, doc: InkDocument, pointerId: Int, sx: Float, sy: Float) {
        val (x, y) = toDoc(sx, sy)
        strokeId = pointerId
        lastX = x
        lastY = y
        when (vm.tool) {
            Tool.HAND -> {
                lastX = sx
                lastY = sy
            }
            Tool.PICKER -> {
                vm.color = doc.pick(x, y)
                vm.tool = Tool.BRUSH
            }
            Tool.FILL -> {
                doc.beginChange()
                doc.fill(x, y, vm.color, vm.flow)
                doc.commitChange()
                vm.refreshHistory()
                invalidate()
            }
            Tool.SHAPE -> {
                doc.beginChange()
                shapeStart = x to y
                shapeEnd = x to y
            }
            Tool.BRUSH, Tool.ERASER -> {
                doc.beginChange()
                doc.paintTo(x, y, x, y, vm.brush, vm.size / 2f, vm.color, vm.flow, vm.tool == Tool.ERASER, vm.mirror)
                invalidate()
            }
        }
    }

    private fun finishSingle(vm: EditorState, doc: InkDocument, event: MotionEvent) {
        val start = shapeStart
        if (start != null) {
            val end = toDoc(event.x, event.y)
            doc.drawShape(vm.shape, start.first, start.second, end.first, end.second, vm.color, vm.size, vm.flow, vm.mirror)
            shapeStart = null
            shapeEnd = null
            doc.commitChange()
            vm.refreshHistory()
            invalidate()
            return
        }
        if ((vm.tool == Tool.BRUSH || vm.tool == Tool.ERASER) && strokeId >= 0) {
            doc.commitChange()
            vm.refreshHistory()
        }
    }

    private fun cancelInProgress(doc: InkDocument) {
        if (shapeStart != null || strokeId >= 0 && (model?.tool == Tool.BRUSH || model?.tool == Tool.ERASER)) {
            doc.cancelChange()
        }
        shapeStart = null
        shapeEnd = null
        strokeId = -1
        invalidate()
    }
}
