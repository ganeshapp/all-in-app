/// Lesson typography: the inline markup the curriculum writes
/// (`**bold**`, `*italic*`, `` `code` ``, `{{term}}`) rendered with the §10.1
/// `TermText` so every glossary key becomes a dotted-gold S2 popover
/// (DESIGN.md §6.2, §6.3).
library;

import 'package:allin/features/study/content/glossary.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// `kGlossary` in the shape `TermText` / `TermPopover` want. Built once.
final Map<String, TermDefinition> kStudyTerms =
    Map<String, TermDefinition>.unmodifiable(<String, TermDefinition>{
      for (final t in kGlossary)
        t.key: TermDefinition(
          id: t.key,
          term: t.term,
          definition: t.definition,
        ),
    });

/// `**bold**` · `*italic*` · `` `code` `` — matched longest-first so the bold
/// delimiter always beats the italic one.
final RegExp _markup = RegExp(
  r'\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`',
  dotAll: true,
);

/// Splits [text] into styled spans. Used as `TermText.plainSpanBuilder`, so it
/// only ever sees the stretches *between* glossary terms.
List<InlineSpan> markupSpans(String text, TextStyle base, Color codeColor) {
  final spans = <InlineSpan>[];
  var index = 0;
  for (final m in _markup.allMatches(text)) {
    if (m.start > index) {
      spans.add(TextSpan(text: text.substring(index, m.start), style: base));
    }
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    } else if (m.group(2) != null) {
      spans.add(
        TextSpan(
          text: m.group(2),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: m.group(3),
          style: AllInText.mono(
            base.fontSize == null ? 13 : base.fontSize! - 1.5,
            color: codeColor,
          ),
        ),
      );
    }
    index = m.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: base));
  }
  return spans;
}

/// One run of lesson prose: glossary terms become tappable popovers, the rest
/// carries the `**bold**` / `*italic*` / `` `code` `` markup.
class LessonRichText extends StatelessWidget {
  const LessonRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.onOpenGlossary,
    this.reducedMotion = false,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final void Function(String termId)? onOpenGlossary;
  final bool reducedMotion;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = style ?? AllInText.body(16, color: c.textMuted, height: 1.55);
    return TermText(
      text,
      terms: kStudyTerms,
      style: base,
      textAlign: textAlign,
      maxLines: maxLines,
      onOpenGlossary: onOpenGlossary,
      reducedMotion: reducedMotion,
      plainSpanBuilder:
          (plain, s) => TextSpan(children: markupSpans(plain, s, c.goldLight)),
    );
  }
}
