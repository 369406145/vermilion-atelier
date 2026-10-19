package studio.vermilion.atelier

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.Shader
import java.util.Random
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

fun clamp(n: Float, lo: Float, hi: Float) = max(lo, min(hi, n))

fun renderPaper(w: Int, h: Int, paper: PaperId): Bitmap {
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val base = when (paper) {
        PaperId.SILK -> Color.parseColor("#EFE2CC")
        PaperId.COARSE -> Color.parseColor("#F1E6D4")
        else -> Color.parseColor("#F7F3EA")
    }
    val pixels = IntArray(w * h)
    val rnd = Random((w * 31L + h + paper.ordinal * 17).toInt().toLong())
    val amp = when (paper) {
        PaperId.PLAIN -> 5
        PaperId.COARSE -> 20
        PaperId.SILK -> 9
        PaperId.XUAN -> 13
    }
    val br = Color.red(base)
    val bg = Color.green(base)
    val bb = Color.blue(base)
    for (i in pixels.indices) {
        val n = ((rnd.nextFloat() - 0.5f) * amp)
        pixels[i] = Color.rgb(
            (br + n).toInt().coerceIn(0, 255),
            (bg + n * 0.94f).toInt().coerceIn(0, 255),
            (bb + n * 0.82f).toInt().coerceIn(0, 255),
        )
    }
    bmp.setPixels(pixels, 0, w, 0, 0, w, h)
    if (paper != PaperId.PLAIN) {
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1f
            color = if (paper == PaperId.COARSE) 0x17604020 else 0x0D6E522E
        }
        val fibers = if (paper == PaperId.COARSE) 70 else 36
        val reach = if (paper == PaperId.COARSE) 16f else 10f
        for (i in 0 until fibers) {
            val x = rnd.nextFloat() * w
            val y = rnd.nextFloat() * h
            val len = 4f + rnd.nextFloat() * reach
            val ang = rnd.nextFloat() * Math.PI.toFloat()
            canvas.drawLine(x, y, x + cos(ang) * len, y + sin(ang) * 0.45f * len, paint)
        }
    }
    return bmp
}

fun emptyLayer(w: Int, h: Int) = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)

private val stampPaint = Paint(Paint.ANTI_ALIAS_FLAG)
private val eraseMode = PorterDuffXfermode(PorterDuff.Mode.DST_OUT)
private val srcMode = PorterDuffXfermode(PorterDuff.Mode.SRC)

fun stamp(
    canvas: Canvas,
    x: Float,
    y: Float,
    radius: Float,
    color: Int,
    alpha: Float,
    hard: Float,
    erase: Boolean,
    dry: Boolean,
) {
    val r = max(radius, 0.4f)
    stampPaint.reset()
    stampPaint.isAntiAlias = true
    if (erase) stampPaint.xfermode = eraseMode
    if (dry && !erase) {
        val count = 7 + (r / 4f).toInt()
        stampPaint.color = color
        for (i in 0 until count) {
            val ang = Math.random() * Math.PI * 2
            val dist = Math.random() * r
            val sr = max(0.4, r * (0.06 + Math.random() * 0.14)).toFloat()
            stampPaint.alpha = (alpha * (0.2 + Math.random() * 0.7) * 255).toInt().coerceIn(0, 255)
            canvas.drawCircle(
                (x + cos(ang) * dist).toFloat(),
                (y + sin(ang) * dist).toFloat(),
                sr,
                stampPaint,
            )
        }
        stampPaint.xfermode = null
        return
    }
    val a = (alpha * 255).toInt().coerceIn(0, 255)
    val solid = if (erase) Color.argb(a, 0, 0, 0) else Color.argb(a, Color.red(color), Color.green(color), Color.blue(color))
    val clear = if (erase) Color.argb(0, 0, 0, 0) else Color.argb(0, Color.red(color), Color.green(color), Color.blue(color))
    val inner = (hard * 0.9f).coerceIn(0f, 0.98f)
    stampPaint.shader = RadialGradient(
        x, y, r,
        intArrayOf(solid, solid, clear),
        floatArrayOf(0f, inner, 1f),
        Shader.TileMode.CLAMP,
    )
    canvas.drawCircle(x, y, r, stampPaint)
    stampPaint.shader = null
    stampPaint.xfermode = null
}

fun paintSegment(
    canvas: Canvas,
    x1: Float,
    y1: Float,
    x2: Float,
    y2: Float,
    brush: BrushSpec,
    radius: Float,
    color: Int,
    flow: Float,
    erase: Boolean,
    mirrorWidth: Float?,
) {
    val dist = hypot((x2 - x1).toDouble(), (y2 - y1).toDouble()).toFloat()
    val speedR = if (brush.kind == BrushKind.SPEED) {
        radius * clamp(14f / max(dist, 0.8f), 0.2f, 1.45f)
    } else {
        radius
    }
    val step = max(0.7f, speedR * brush.spacing)
    val n = max(1, ceil(dist / step).toInt())
    val alpha = clamp(flow * brush.baseFlow, 0.02f, 1f)
    val dry = brush.kind == BrushKind.DRY && !erase
    for (i in 0..n) {
        val t = if (n == 0) 0f else i / n.toFloat()
        val x = x1 + (x2 - x1) * t
        val y = y1 + (y2 - y1) * t
        stamp(canvas, x, y, speedR, color, alpha, brush.hard, erase, dry)
        if (mirrorWidth != null) {
            stamp(canvas, mirrorWidth - x, y, speedR, color, alpha, brush.hard, erase, dry)
        }
    }
}

private val shapePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeCap = Paint.Cap.ROUND
    strokeJoin = Paint.Join.ROUND
}

fun strokeShape(
    canvas: Canvas,
    kind: ShapeKind,
    ax: Float,
    ay: Float,
    bx: Float,
    by: Float,
    color: Int,
    width: Float,
    alpha: Float,
) {
    shapePaint.color = color
    shapePaint.alpha = (alpha * 255).toInt().coerceIn(0, 255)
    shapePaint.strokeWidth = max(1f, width)
    when (kind) {
        ShapeKind.LINE -> canvas.drawLine(ax, ay, bx, by, shapePaint)
        ShapeKind.RECT -> canvas.drawRect(min(ax, bx), min(ay, by), max(ax, bx), max(ay, by), shapePaint)
        ShapeKind.ELLIPSE -> canvas.drawOval(min(ax, bx), min(ay, by), max(ax, bx), max(ay, by), shapePaint)
    }
}

fun restoreBitmap(dst: Bitmap, src: Bitmap) {
    val canvas = Canvas(dst)
    val paint = Paint().apply { xfermode = srcMode }
    canvas.drawBitmap(src, 0f, 0f, paint)
}

fun floodFill(bmp: Bitmap, sx: Int, sy: Int, color: Int, alpha: Float) {
    val w = bmp.width
    val h = bmp.height
    if (sx !in 0 until w || sy !in 0 until h) return
    val pixels = IntArray(w * h)
    bmp.getPixels(pixels, 0, w, 0, 0, w, h)
    val start = sy * w + sx
    val src = pixels[start]
    val paint = Color.argb(
        (alpha * 255).toInt().coerceIn(0, 255),
        Color.red(color),
        Color.green(color),
        Color.blue(color),
    )
    if (src == paint) return
    val sr = Color.red(src)
    val sg = Color.green(src)
    val sb = Color.blue(src)
    val sa = Color.alpha(src)
    val seen = BooleanArray(w * h)
    val stack = ArrayDeque<Int>()
    stack.add(start)
    seen[start] = true
    fun consider(q: Int) {
        if (seen[q]) return
        seen[q] = true
        val p = pixels[q]
        if (
            abs(Color.red(p) - sr) <= 32 &&
            abs(Color.green(p) - sg) <= 32 &&
            abs(Color.blue(p) - sb) <= 32 &&
            abs(Color.alpha(p) - sa) <= 32
        ) {
            stack.add(q)
        }
    }
    while (stack.isNotEmpty()) {
        val p = stack.removeLast()
        pixels[p] = paint
        val x = p % w
        val y = p / w
        if (x > 0) consider(p - 1)
        if (x + 1 < w) consider(p + 1)
        if (y > 0) consider(p - w)
        if (y + 1 < h) consider(p + w)
    }
    bmp.setPixels(pixels, 0, w, 0, 0, w, h)
}
