package studio.vermilion.atelier

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

data class LayerMeta(val name: String, val visible: Boolean, val file: String)

data class WorkSummary(
    val id: String,
    val title: String,
    val paper: PaperId,
    val updatedAt: Long,
    val thumb: File,
    val width: Int,
    val height: Int,
)

data class StoredWork(
    val summary: WorkSummary,
    val layers: List<Pair<LayerMeta, Bitmap>>,
)

object WorkStore {
    private fun root(context: Context) = File(context.filesDir, "works").apply { mkdirs() }

    fun list(context: Context): List<WorkSummary> {
        val dir = root(context)
        return dir.listFiles()?.mapNotNull { folder ->
            val meta = File(folder, "meta.json")
            val thumb = File(folder, "thumb.jpg")
            if (!meta.exists() || !thumb.exists()) return@mapNotNull null
            val json = JSONObject(meta.readText())
            WorkSummary(
                id = json.getString("id"),
                title = json.getString("title"),
                paper = PaperId.valueOf(json.getString("paper")),
                updatedAt = json.getLong("updatedAt"),
                thumb = thumb,
                width = json.getInt("width"),
                height = json.getInt("height"),
            )
        }?.sortedByDescending { it.updatedAt } ?: emptyList()
    }

    fun load(context: Context, id: String): StoredWork? {
        val folder = File(root(context), id)
        val metaFile = File(folder, "meta.json")
        if (!metaFile.exists()) return null
        val json = JSONObject(metaFile.readText())
        val layersJson = json.getJSONArray("layers")
        val layers = buildList {
            for (i in 0 until layersJson.length()) {
                val item = layersJson.getJSONObject(i)
                val meta = LayerMeta(item.getString("name"), item.getBoolean("visible"), item.getString("file"))
                val bmp = BitmapFactory.decodeFile(File(folder, meta.file).absolutePath) ?: return null
                add(meta to bmp.copy(Bitmap.Config.ARGB_8888, true))
                bmp.recycle()
            }
        }
        val summary = WorkSummary(
            id = json.getString("id"),
            title = json.getString("title"),
            paper = PaperId.valueOf(json.getString("paper")),
            updatedAt = json.getLong("updatedAt"),
            thumb = File(folder, "thumb.jpg"),
            width = json.getInt("width"),
            height = json.getInt("height"),
        )
        return StoredWork(summary, layers)
    }

    fun save(context: Context, doc: InkDocument, thumb: Bitmap) {
        val folder = File(root(context), doc.id).apply { mkdirs() }
        val layerMeta = JSONArray()
        doc.layers.forEachIndexed { index, layer ->
            val name = "layer-$index.png"
            FileOutputStream(File(folder, name)).use { out ->
                layer.bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            layerMeta.put(
                JSONObject()
                    .put("name", layer.name)
                    .put("visible", layer.visible)
                    .put("file", name),
            )
        }
        FileOutputStream(File(folder, "thumb.jpg")).use { out ->
            thumb.compress(Bitmap.CompressFormat.JPEG, 72, out)
        }
        val json = JSONObject()
            .put("id", doc.id)
            .put("title", doc.title.ifBlank { "Untitled sheet" })
            .put("width", doc.width)
            .put("height", doc.height)
            .put("paper", doc.paperId.name)
            .put("updatedAt", System.currentTimeMillis())
            .put("layers", layerMeta)
        File(folder, "meta.json").writeText(json.toString())
        doc.persisted = true
        doc.dirty = false
    }

    fun delete(context: Context, id: String) {
        File(root(context), id).deleteRecursively()
    }

    fun exportPng(context: Context, bitmap: Bitmap, title: String): Boolean {
        val safe = title.ifBlank { "vermilion" }
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
            .ifBlank { "vermilion" }
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "$safe.png")
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= 29) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Vermilion Atelier")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return writePrivate(context, bitmap, safe)
            context.contentResolver.openOutputStream(uri)?.use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            } ?: return false
            if (Build.VERSION.SDK_INT >= 29) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                context.contentResolver.update(uri, values, null, null)
            }
            true
        } catch (_: SecurityException) {
            writePrivate(context, bitmap, safe)
        }
    }

    private fun writePrivate(context: Context, bitmap: Bitmap, safe: String): Boolean {
        val dir = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: return false
        dir.mkdirs()
        FileOutputStream(File(dir, "$safe.png")).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        return true
    }
}
