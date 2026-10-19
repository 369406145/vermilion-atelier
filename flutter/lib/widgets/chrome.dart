import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/atelier_theme.dart';

class NoticeBus extends ChangeNotifier {
  String? message;
  int ticket = 0;

  void say(String next) {
    message = next;
    ticket++;
    notifyListeners();
  }
}

class NoticeScope extends InheritedWidget {
  const NoticeScope({required this.bus, required super.child, super.key});

  final NoticeBus bus;

  static NoticeBus read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<NoticeScope>();
    assert(scope != null, "NoticeScope missing");
    return scope!.bus;
  }

  @override
  bool updateShouldNotify(NoticeScope oldWidget) => bus != oldWidget.bus;
}

class ToastOverlay extends StatefulWidget {
  const ToastOverlay({super.key, required this.bus, required this.child});

  final NoticeBus bus;
  final Widget child;

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  String? _text;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    widget.bus.addListener(_onNote);
  }

  @override
  void dispose() {
    widget.bus.removeListener(_onNote);
    super.dispose();
  }

  void _onNote() {
    final ticket = widget.bus.ticket;
    setState(() {
      _text = widget.bus.message;
      _seen = ticket;
    });
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted || _seen != ticket) return;
      setState(() => _text = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _text == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fade(AtelierColors.ink, 0.94),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AtelierColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(_text ?? "", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.label,
    this.radius = 16,
  });

  final VoidCallback onPressed;
  final Widget child;
  final String? label;
  final double radius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

class SealMark extends StatelessWidget {
  const SealMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AtelierColors.cinnabar, width: 2),
      ),
      child: Container(
        width: size * 0.52,
        height: size * 0.52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AtelierColors.cinnabar),
        ),
      ),
    );
  }
}

class AtelierDock extends StatelessWidget {
  const AtelierDock({
    super.key,
    required this.studio,
    required this.onStudio,
    required this.onCreate,
    required this.onPrompts,
  });

  final bool studio;
  final VoidCallback onStudio;
  final VoidCallback onCreate;
  final VoidCallback onPrompts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.panel,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _Tab(label: "Studio", active: studio, onTap: onStudio, mark: true)),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Pressable(
                  label: "Cut a new sheet",
                  onPressed: onCreate,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AtelierColors.cinnabar, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: AtelierColors.rice, size: 30),
                  ),
                ),
              ),
              Expanded(
                child: _Tab(
                  label: "Prompts",
                  active: !studio,
                  onTap: onPrompts,
                  icon: Icons.menu_book_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap, this.icon, this.mark = false});

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final bool mark;

  @override
  Widget build(BuildContext context) {
    final color = active ? AtelierColors.cinnabar : AtelierColors.mist;
    return Pressable(
      label: label,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mark)
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: label,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AtelierColors.cinnabar, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: label,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AtelierColors.raise, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}
