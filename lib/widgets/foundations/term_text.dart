/// `TermText` — prose with dotted-underline glossary terms that open a
/// [TermPopover] (DESIGN.md §10.1, §6.3).
///
/// Parses the lesson markup `{{key}}` and `{{key|display text}}` documented in
/// `features/study/content/lesson_model.dart`; an unknown key renders as plain
/// text, exactly as the desktop `Term` does. Each term carries hit slop so the
/// tap target reaches the §12 floor of 44 pt without changing line height.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'term_popover.dart';

class TermText extends StatelessWidget {
  const TermText(
    this.text, {
    super.key,
    this.terms,
    this.style,
    this.onOpenGlossary,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.plainSpanBuilder,
    this.reducedMotion = false,
  });

  /// Body copy, possibly containing `{{key}}` / `{{key|display}}`.
  final String text;

  /// Overrides for [AllInGlossary] (tests, tool screens with local terms).
  final Map<String, TermDefinition>? terms;
  final TextStyle? style;
  final void Function(String termId)? onOpenGlossary;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Lets the lesson reader apply its own `**bold**` / `` `code` `` markup to
  /// the stretches between terms.
  final InlineSpan Function(String plain, TextStyle style)? plainSpanBuilder;

  final bool reducedMotion;

  static final RegExp _pattern = RegExp(r'\{\{([^}|]+)(?:\|([^}]*))?\}\}');

  TermDefinition? _lookup(String key) =>
      terms?[key] ?? AllInGlossary.lookup(key);

  /// The spans this widget renders — exposed so richer readers can compose
  /// them into their own `Text.rich`.
  List<InlineSpan> buildSpans(BuildContext context, TextStyle base) {
    final c = context.colors;
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > index) {
        final plain = text.substring(index, match.start);
        spans.add(
          plainSpanBuilder?.call(plain, base) ??
              TextSpan(text: plain, style: base),
        );
      }
      final key = match.group(1)!.trim();
      final display = (match.group(2) ?? '').trim();
      final definition = _lookup(key);
      final label = display.isNotEmpty ? display : (definition?.term ?? key);
      if (definition == null) {
        spans.add(TextSpan(text: label, style: base));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _TermSpan(
              termId: key,
              label: label,
              definition: definition,
              style: base.copyWith(
                color: base.color,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: c.gold,
              ),
              onOpenGlossary: onOpenGlossary,
              reducedMotion: reducedMotion,
            ),
          ),
        );
      }
      index = match.end;
    }
    if (index < text.length) {
      final plain = text.substring(index);
      spans.add(
        plainSpanBuilder?.call(plain, base) ??
            TextSpan(text: plain, style: base),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? AllInText.body(15, color: context.colors.text);
    return Text.rich(
      TextSpan(children: buildSpans(context, base)),
      style: base,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

class _TermSpan extends StatefulWidget {
  const _TermSpan({
    required this.termId,
    required this.label,
    required this.definition,
    required this.style,
    required this.onOpenGlossary,
    required this.reducedMotion,
  });

  final String termId;
  final String label;
  final TermDefinition definition;
  final TextStyle style;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;

  @override
  State<_TermSpan> createState() => _TermSpanState();
}

class _TermSpanState extends State<_TermSpan> {
  final TermPopoverController _controller = TermPopoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HitSlop(
      minSize: const Size(44, 44),
      child: Semantics(
        button: true,
        label: '${widget.label}, glossary term',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _controller.open,
            child: TermPopover(
              termId: widget.termId,
              definition: widget.definition,
              controller: _controller,
              openOnTap: false,
              onOpenGlossary: widget.onOpenGlossary,
              reducedMotion: widget.reducedMotion,
              child: Text(widget.label, style: widget.style),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grows a widget's hit test area to [minSize] without changing its layout —
/// the "line-height slop" §6.3 relies on so an inline term is still a 44 pt
/// target. Nothing here paints; only [RenderBox.hitTest] changes.
class HitSlop extends SingleChildRenderObjectWidget {
  const HitSlop({
    super.key,
    required this.minSize,
    required Widget super.child,
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitSlop(minSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHitSlop).minSize = minSize;
  }
}

class _RenderHitSlop extends RenderProxyBox {
  _RenderHitSlop(this._minSize);

  Size _minSize;

  set minSize(Size value) {
    if (value == _minSize) return;
    _minSize = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final dx = math.max(0.0, (_minSize.width - size.width) / 2);
    final dy = math.max(0.0, (_minSize.height - size.height) / 2);
    final slop = Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
    if (!slop.contains(position)) return false;
    final clamped = Offset(
      position.dx.clamp(0.0, math.max(0.0, size.width - 0.01)),
      position.dy.clamp(0.0, math.max(0.0, size.height - 0.01)),
    );
    return super.hitTest(result, position: clamped);
  }
}
