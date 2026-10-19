import 'dart:convert';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/document.dart';
import '../models/catalog.dart';

class WorkSummary {
  const WorkSummary({
    required this.id,
    required this.title,
    required this.paper,
    required this.updatedAt,
    required this.thumbPath,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;
  final PaperId paper;
  final int updatedAt;
  final String thumbPath;
  final int width;
  final int height;
}

class WorkStore {
  static Future<Directory> root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory("${base.path}/works");
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<WorkSummary>> list() async {
    final dir = await root();
    final folders = await dir.list().toList();
    final works = <WorkSummary>[];
    for (final entity in folders) {
      if (entity is! Directory) continue;
      final meta = File("${entity.path}/meta.json");
      final thumb = File("${entity.path}/thumb.png");
      if (!await meta.exists() || !await thumb.exists()) continue;
      try {
        final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
        works.add(
          WorkSummary(
            id: json["id"] as String,
            title: json["title"] as String,
            paper: PaperId.values.byName(json["paper"] as String),
            updatedAt: json["updatedAt"] as int,
            thumbPath: thumb.path,
            width: json["width"] as int,
            height: json["height"] as int,
          ),
        );
      } catch (_) {}
    }
    works.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return works;
  }

  static Future<InkDocument?> load(String id) async {
    final folder = Directory("${(await root()).path}/$id");
    final metaFile = File("${folder.path}/meta.json");
    if (!await metaFile.exists()) return null;
    final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final width = json["width"] as int;
    final height = json["height"] as int;
    final paperId = PaperId.values.byName(json["paper"] as String);
    final paper = await renderPaper(width, height, paperId);
    final layersJson = json["layers"] as List<dynamic>;
    final layers = <InkLayer>[];
    for (final raw in layersJson) {
      final item = raw as Map<String, dynamic>;
      final file = File("${folder.path}/${item["file"]}");
      var image = await decodeBytes(await file.readAsBytes());
      if (image.width != width || image.height != height) {
        final fitted = await containImage(image, width, height);
        image.dispose();
        image = fitted;
      }
      layers.add(
        InkLayer(
          name: item["name"] as String? ?? "Wash",
          image: image,
          visible: item["visible"] as bool? ?? true,
          opacity: (item["opacity"] as num?)?.toDouble() ?? 1,
        ),
      );
    }
    if (layers.isEmpty) {
      layers.add(InkLayer(name: "Ink", image: await blankImage(width, height)));
    }
    return InkDocument(
      id: json["id"] as String,
      title: json["title"] as String,
      width: width,
      height: height,
      paperId: paperId,
      paper: paper,
      layers: layers,
    )..persisted = true;
  }

  static Future<void> save(InkDocument doc) async {
    final folder = Directory("${(await root()).path}/${doc.id}");
    if (await folder.exists()) {
      await for (final entity in folder.list()) {
        if (entity is File) await entity.delete();
      }
    } else {
      await folder.create(recursive: true);
    }
    final layerMeta = <Map<String, dynamic>>[];
    for (var i = 0; i < doc.layers.length; i++) {
      final layer = doc.layers[i];
      final name = "layer-$i.png";
      await File("${folder.path}/$name").writeAsBytes(await pngBytes(layer.image));
      layerMeta.add({
        "name": layer.name,
        "visible": layer.visible,
        "opacity": layer.opacity,
        "file": name,
      });
    }
    final thumb = await doc.composite(maxSide: 480);
    await File("${folder.path}/thumb.png").writeAsBytes(await pngBytes(thumb));
    thumb.dispose();
    final json = {
      "id": doc.id,
      "title": doc.title.trim().isEmpty ? "Untitled sheet" : doc.title.trim(),
      "width": doc.width,
      "height": doc.height,
      "paper": doc.paperId.name,
      "updatedAt": DateTime.now().millisecondsSinceEpoch,
      "layers": layerMeta,
    };
    await File("${folder.path}/meta.json").writeAsString(jsonEncode(json));
    doc
      ..persisted = true
      ..dirty = false
      ..title = json["title"] as String;
  }

  static Future<void> delete(String id) async {
    final folder = Directory("${(await root()).path}/$id");
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  static Future<void> duplicate(String id) async {
    final src = Directory("${(await root()).path}/$id");
    if (!await src.exists()) return;
    final nid = newId();
    final dst = Directory("${(await root()).path}/$nid");
    await dst.create(recursive: true);
    await for (final entity in src.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      await entity.copy("${dst.path}/$name");
    }
    final metaFile = File("${dst.path}/meta.json");
    final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    json["id"] = nid;
    json["title"] = "${json["title"]} copy";
    json["updatedAt"] = DateTime.now().millisecondsSinceEpoch;
    await metaFile.writeAsString(jsonEncode(json));
  }

  static Future<String> exportPng(InkDocument doc) async {
    final full = await doc.composite();
    final bytes = await pngBytes(full);
    full.dispose();
    final safe = doc.title
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp(r"^-+|-+$"), "");
    final name = safe.isEmpty ? "vermilion" : safe;
    try {
      await Gal.requestAccess(toAlbum: true);
      await Gal.putImageBytes(bytes, album: "Vermilion Atelier");
      return "Saved a PNG to Pictures / Vermilion Atelier.";
    } on GalException {
      return _privateCopy(bytes, name, "The gallery said no. A PNG was kept in the app folder.");
    } catch (_) {
      return _privateCopy(bytes, name, "Could not write the gallery. A PNG was kept in the app folder.");
    }
  }

  static Future<String> _privateCopy(List<int> bytes, String name, String message) async {
    final dir = await getApplicationDocumentsDirectory();
    await File("${dir.path}/$name.png").writeAsBytes(bytes);
    return message;
  }
}
