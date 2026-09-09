/// O1 · the three first-table coach marks (DESIGN.md §4.15, §8.3).
///
/// A caption is 36 pt tall with a 6 pt gold pointer, Inter 14 on `ink800` at
/// 95 %, and it dismisses on any tap. The table composes these into its felt
/// `Stack`; the widget renders nothing at all unless the caption it names is
/// the one currently owed, so a call site is a single unconditional line.
///
/// ```dart
/// CoachMarkCaption(mark: CoachMark.step, pointer: CoachMarkPointer.down)
/// ```
library;

import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which edge the 6 pt gold pointer sits on — it points *at* the thing the
/// caption is about.
enum CoachMarkPointer { up, down, left, right }

class CoachMarkCaption extends ConsumerWidget {
  const CoachMarkCaption({
    super.key,
    required this.mark,
    this.pointer = CoachMarkPointer.down,
    this.maxWidth = 300,
  });

  /// Which of the three §4.15 captions this slot renders.
  final CoachMark mark;

  final CoachMarkPointer pointer;

  /// The caption wraps rather than running off a 360 pt felt.
  final double maxWidth;

  /// §4.15 geometry.
  static const double height = 36;
  static const double pointerSize = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleCoachMarkProvider) == mark;
    if (!visible) return const SizedBox.shrink();

    final c = context.colors;
    final horizontal =
        pointer == CoachMarkPointer.left || pointer == CoachMarkPointer.right;

    final bubble = Container(
      constraints: BoxConstraints(minHeight: height, maxWidth: maxWidth),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.md,
        vertical: AllInSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.ink800.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AllInRadius.md),
        border: Border.all(color: c.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        mark.caption,
        textAlign: TextAlign.center,
        style: AllInText.body(14, color: c.text),
      ),
    );

    final pointerWidget = CustomPaint(
      size:
          horizontal
              ? const Size(pointerSize, pointerSize * 2)
              : const Size(pointerSize * 2, pointerSize),
      painter: _PointerPainter(color: c.gold, direction: pointer),
    );

    final children =
        switch (pointer) {
          CoachMarkPointer.up => [pointerWidget, bubble],
          CoachMarkPointer.down => [bubble, pointerWidget],
          CoachMarkPointer.left => [pointerWidget, bubble],
          CoachMarkPointer.right => [bubble, pointerWidget],
        }.toList();

    final content =
        horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: children)
            : Column(mainAxisSize: MainAxisSize.min, children: children);

    return Semantics(
      liveRegion: true,
      label: mark.caption,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(coachMarksProvider.notifier).dismiss(),
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({required this.color, required this.direction});

  final Color color;
  final CoachMarkPointer direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    switch (direction) {
      case CoachMarkPointer.down:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height);
      case CoachMarkPointer.up:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width / 2, 0);
      case CoachMarkPointer.left:
        path
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height / 2);
      case CoachMarkPointer.right:
        path
          ..moveTo(0, 0)
          ..lineTo(0, size.height)
          ..lineTo(size.width, size.height / 2);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.color != color || old.direction != direction;
}
