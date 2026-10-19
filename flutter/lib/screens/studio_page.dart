import 'dart:io';

import 'package:flutter/material.dart';

import '../data/work_store.dart';
import '../models/catalog.dart';
import '../theme/atelier_theme.dart';
import '../widgets/chrome.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({super.key, required this.onCreate, required this.onPrompts, required this.onOpen});

  final VoidCallback onCreate;
  final VoidCallback onPrompts;
  final ValueChanged<Draft> onOpen;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  List<WorkSummary> _works = [];
  bool _loading = true;
  String? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final works = await WorkStore.list();
    if (!mounted) return;
    setState(() {
      _works = works;
      _loading = false;
    });
  }

  Future<void> _remove(WorkSummary work) async {
    await WorkStore.delete(work.id);
    if (!mounted) return;
    setState(() {
      _works = _works.where((item) => item.id != work.id).toList();
      _pending = null;
    });
    NoticeScope.read(context).say("Removed ${work.title}.");
  }

  Future<void> _copy(WorkSummary work) async {
    await WorkStore.duplicate(work.id);
    await _load();
    if (!mounted) return;
    NoticeScope.read(context).say("Copied ${work.title}.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AtelierColors.cinnabar,
                backgroundColor: AtelierColors.panel,
                onRefresh: () async {
                  await _load();
                  if (mounted) NoticeScope.read(context).say("Cabinet refreshed.");
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("VERMILION", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AtelierColors.cinnabar, letterSpacing: 2)),
                              Text("Atelier", style: Theme.of(context).textTheme.displayLarge),
                            ],
                          ),
                        ),
                        const SealMark(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "A pocket ink studio. Wolf hair, mineral color, and a great deal of unpainted paper. Everything stays on this device until you save a PNG.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator(color: AtelierColors.cinnabar)),
                      )
                    else if (_works.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AtelierColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("The cabinet is empty, which is the correct way to begin.", style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text("Cut a sheet, bring in a picture to draw over, or take a prompt that tells you when to stop.", style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < _works.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _card(_works[i])),
                              const SizedBox(width: 12),
                              Expanded(child: i + 1 < _works.length ? _card(_works[i + 1]) : const SizedBox()),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            AtelierDock(studio: true, onStudio: () => NoticeScope.read(context).say("You are in the studio."), onCreate: widget.onCreate, onPrompts: widget.onPrompts),
          ],
        ),
      ),
    );
  }

  Widget _card(WorkSummary work) {
    final pending = _pending == work.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          label: "Open ${work.title}",
          onPressed: () => widget.onOpen(
            Draft(id: work.id, title: work.title, width: work.width, height: work.height, paper: work.paper, existed: true),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Image.file(
                File(work.thumbPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AtelierColors.raise),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
        Text("${ago(work.updatedAt)} · ${work.paper.name}", style: Theme.of(context).textTheme.bodySmall),
        if (pending)
          Row(
            children: [
              TextButton(onPressed: () => _remove(work), child: const Text("Delete", style: TextStyle(color: AtelierColors.cinnabar))),
              TextButton(onPressed: () {
                setState(() => _pending = null);
                NoticeScope.read(context).say("Kept.");
              }, child: const Text("Keep", style: TextStyle(color: AtelierColors.rice))),
            ],
          )
        else
          Row(
            children: [
              TextButton(onPressed: () => _copy(work), child: const Text("Copy", style: TextStyle(color: AtelierColors.mist))),
              TextButton(onPressed: () {
                setState(() => _pending = work.id);
                NoticeScope.read(context).say("Delete ${work.title}? This stays on the device either way.");
              }, child: const Text("Remove", style: TextStyle(color: AtelierColors.mist))),
            ],
          ),
      ],
    );
  }
}
