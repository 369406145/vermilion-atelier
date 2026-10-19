import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/catalog.dart';
import '../theme/atelier_theme.dart';
import '../widgets/chrome.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({
    super.key,
    required this.presetId,
    required this.paper,
    required this.promptTitle,
    required this.onBack,
    required this.onBegin,
  });

  final String presetId;
  final PaperId paper;
  final String? promptTitle;
  final VoidCallback onBack;
  final ValueChanged<Draft> onBegin;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  late String _preset = widget.presetId;
  late PaperId _paper = widget.paper;
  String? _title;

  @override
  void initState() {
    super.initState();
    _title = widget.promptTitle;
  }

  Future<void> _picture() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
      if (!mounted) return;
      if (file == null) {
        NoticeScope.read(context).say("No picture chosen.");
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      NoticeScope.read(context).say("Picture on the sheet. The ink wash sits above it.");
      final preset = presetById(_preset);
      widget.onBegin(
        Draft(
          id: newId(),
          title: _title ?? preset.name,
          width: preset.w,
          height: preset.h,
          paper: _paper,
          underlay: bytes,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      NoticeScope.read(context).say("Could not open that picture.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = presetById(_preset);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      NoticeScope.read(context).say("Back to the studio.");
                      widget.onBack();
                    },
                    child: const Text("Back", style: TextStyle(color: AtelierColors.rice)),
                  ),
                  Expanded(child: Text("Cut a sheet", style: Theme.of(context).textTheme.headlineMedium)),
                ],
              ),
              if (_title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8),
                  child: Text("For “$_title”", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AtelierColors.cinnabar)),
                ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: papers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = papers[index];
                    final on = item.id == _paper;
                    return Pressable(
                      label: item.name,
                      onPressed: () {
                        setState(() => _paper = item.id);
                        NoticeScope.read(context).say("${item.name}. ${item.hint}.");
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: on ? AtelierColors.cinnabar : AtelierColors.panel,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("${item.name} · ${item.hint}", style: Theme.of(context).textTheme.labelLarge),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final item = presets[index];
                    final on = item.id == _preset;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Pressable(
                        label: item.name,
                        onPressed: () {
                          setState(() {
                            _preset = item.id;
                            if (widget.promptTitle == null) _title = null;
                          });
                          NoticeScope.read(context).say("${item.name}, ${item.w} by ${item.h}.");
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: on ? AtelierColors.raise : AtelierColors.panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: on ? AtelierColors.cinnabar : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(item.ratio, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AtelierColors.cinnabar)),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: Theme.of(context).textTheme.labelLarge),
                                    Text(item.blurb, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Text("${item.w}×${item.h}", style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              PrimaryButton(
                label: "Begin ${preset.name.toLowerCase()}",
                onPressed: () {
                  NoticeScope.read(context).say("The sheet is yours. One finger draws, two fingers move.");
                  final chosen = presetById(_preset);
                  widget.onBegin(
                    Draft(
                      id: newId(),
                      title: _title ?? chosen.name,
                      width: chosen.w,
                      height: chosen.h,
                      paper: _paper,
                    ),
                  );
                },
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _picture,
                  icon: const Icon(Icons.image_outlined, color: AtelierColors.mist),
                  label: const Text("Start from a picture", style: TextStyle(color: AtelierColors.mist)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
