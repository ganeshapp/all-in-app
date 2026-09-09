/// `SizingRail` — the 48 pt context-row band that sets the raise size
/// (DESIGN.md §10.3; behaviour §4.5 "Sizing rail").
///
/// Seven detent **slots**, evenly spaced whatever their values are, so a tick
/// never slides out from under a live thumb. Collapsed detents keep their slot
/// and lose their label and their magnet. Dragging anywhere on the band moves
/// the knob; release never commits — only the Raise button commits.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// One slot on the rail: `Min · 1/3 · 1/2 · 2/3 · 3/4 · Pot · All-in`.
class RailDetent {
  const RailDetent({
    required this.label,
    required this.value,
    this.optionalLabel = false,
    this.semanticLabel,
  });

  /// Displayed under 50 pt of spacing only when [optionalLabel] is false.
  final String label;

  /// Raise-to total in chips.
  final int value;

  /// 1/3 and 2/3 drop their labels at 360 and stay unlabelled ticks (§4.2.3).
  final bool optionalLabel;

  /// Screen-reader wording ("one third pot").
  final String? semanticLabel;
}

class SizingRail extends StatefulWidget {
  const SizingRail({
    super.key,
    required this.min,
    required this.max,
    required this.detents,
    required this.value,
    required this.onChanged,
    this.bigBlind = 20,
    this.onChangeEnd,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  });

  /// `minRaiseTo` / `maxRaiseTo` in chips, straight from `legalActions()`.
  final int min;
  final int max;

  /// The seven slots, left to right, non-decreasing in value.
  final List<RailDetent> detents;

  /// Current raise-to total in chips.
  final int value;
  final ValueChanged<int> onChanged;
  final int bigBlind;
  final ValueChanged<int>? onChangeEnd;
  final bool enableHaptics;
  final bool reducedMotion;
  final String? semanticLabel;

  /// The context row never changes height (§4.5).
  static const double height = 48;

  /// Magnet radius around a distinct detent.
  static const double magnet = 6;

  /// Optional labels drop below this slot spacing (the 360 case, §4.2.3).
  static const double labelSpacingFloor = 50;

  /// Chip quantum: `max(1, bb / 2)` — 0.5 bb (§4.5).
  static int quantumFor(int bigBlind) => math.max(1, bigBlind ~/ 2);

  /// `minRaiseTo == maxRaiseTo`: the only legal raise is the shove, so the
  /// rail hides and the band carries a muted line instead (§4.5).
  static bool isDegenerate(int min, int max) => min >= max;

  @override
  State<SizingRail> createState() => _SizingRailState();
}

class _SizingRailState extends State<SizingRail> {
  bool _dragging = false;
  int? _lastMagnet;

  static const double _inset = 18;
  static const double _labelRow = 15;

  List<int> get _distinct {
    final out = <int>[];
    for (var i = 0; i < widget.detents.length; i++) {
      if (i == 0 || widget.detents[i].value != widget.detents[i - 1].value) {
        out.add(i);
      }
    }
    return out;
  }

  double _slotX(int index, double width) {
    final n = widget.detents.length;
    if (n <= 1) return width / 2;
    final track = math.max(0.0, width - _inset * 2);
    return _inset + track * index / (n - 1);
  }

  double _xForValue(int value, double width) {
    final distinct = _distinct;
    if (distinct.isEmpty) return _slotX(0, width);
    if (value <= widget.detents[distinct.first].value) {
      return _slotX(distinct.first, width);
    }
    for (var k = 0; k < distinct.length - 1; k++) {
      final a = widget.detents[distinct[k]].value;
      final b = widget.detents[distinct[k + 1]].value;
      if (value <= b) {
        final t = b == a ? 0.0 : (value - a) / (b - a);
        return _slotX(distinct[k], width) +
            (_slotX(distinct[k + 1], width) - _slotX(distinct[k], width)) * t;
      }
    }
    return _slotX(distinct.last, width);
  }

  int _valueForX(double x, double width) {
    final distinct = _distinct;
    if (distinct.isEmpty) return widget.min;
    // Magnet: a distinct detent within ±6 pt wins outright.
    for (final i in distinct) {
      if ((x - _slotX(i, width)).abs() <= SizingRail.magnet) {
        return widget.detents[i].value;
      }
    }
    if (x <= _slotX(distinct.first, width)) {
      return widget.detents[distinct.first].value;
    }
    for (var k = 0; k < distinct.length - 1; k++) {
      final xa = _slotX(distinct[k], width);
      final xb = _slotX(distinct[k + 1], width);
      if (x <= xb) {
        final t = xb == xa ? 0.0 : (x - xa) / (xb - xa);
        final a = widget.detents[distinct[k]].value;
        final b = widget.detents[distinct[k + 1]].value;
        return _quantise(a + (b - a) * t);
      }
    }
    return widget.detents[distinct.last].value;
  }

  /// Quantised to 0.5 bb and clamped to the legal window.
  int _quantise(double raw) {
    final q = SizingRail.quantumFor(widget.bigBlind);
    final snapped = (raw / q).round() * q;
    return snapped.clamp(widget.min, widget.max);
  }

  void _emit(double x, double width) {
    final next = _valueForX(x, width);
    if (next == widget.value) return;
    final magnetIndex = _distinct.firstWhere(
      (i) =>
          (x - _slotX(i, width)).abs() <= SizingRail.magnet &&
          widget.detents[i].value == next,
      orElse: () => -1,
    );
    if (magnetIndex >= 0 && magnetIndex != _lastMagnet) {
      _lastMagnet = magnetIndex;
      if (widget.enableHaptics) HapticFeedback.selectionClick();
    } else if (magnetIndex < 0) {
      _lastMagnet = null;
    }
    widget.onChanged(next);
  }

  void _step(int direction) {
    final q = SizingRail.quantumFor(widget.bigBlind);
    final next = (widget.value + direction * q).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (SizingRail.isDegenerate(widget.min, widget.max)) {
      return SizedBox(
        height: SizingRail.height,
        child: Center(
          child: Text(
            'Only one raise size — all-in '
            '${fmtBb(widget.max, widget.bigBlind)} bb',
            maxLines: 1,
            style: AllInText.body(13, color: c.textMuted),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final distinct = _distinct.toSet();
        final spacing =
            widget.detents.length > 1
                ? (width - _inset * 2) / (widget.detents.length - 1)
                : width;
        final showOptional = spacing >= SizingRail.labelSpacingFloor;
        final knobX = _xForValue(widget.value, width);
        final selected = widget.detents.indexWhere(
          (d) => d.value == widget.value,
        );

        return Semantics(
          slider: true,
          label: widget.semanticLabel ?? 'Raise size',
          value: '${fmtBb(widget.value, widget.bigBlind)} big blinds',
          increasedValue:
              '${fmtBb((widget.value + SizingRail.quantumFor(widget.bigBlind)).clamp(widget.min, widget.max), widget.bigBlind)} big blinds',
          decreasedValue:
              '${fmtBb((widget.value - SizingRail.quantumFor(widget.bigBlind)).clamp(widget.min, widget.max), widget.bigBlind)} big blinds',
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _emit(d.localPosition.dx, width),
              onHorizontalDragStart: (d) {
                setState(() => _dragging = true);
                _emit(d.localPosition.dx, width);
              },
              onHorizontalDragUpdate: (d) => _emit(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) {
                setState(() => _dragging = false);
                _lastMagnet = null;
                // Release never commits — it only reports the resting value.
                widget.onChangeEnd?.call(widget.value);
              },
              onHorizontalDragCancel: () {
                setState(() => _dragging = false);
                _lastMagnet = null;
              },
              child: SizedBox(
                height: SizingRail.height,
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Labels.
                    for (var i = 0; i < widget.detents.length; i++)
                      if (distinct.contains(i) &&
                          (!widget.detents[i].optionalLabel || showOptional))
                        Positioned(
                          left: _slotX(i, width) - 40,
                          top: 0,
                          width: 80,
                          child: Text(
                            widget.detents[i].label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: AllInText.body(
                              11,
                              weight: FontWeight.w600,
                              color: i == selected ? c.gold : c.textMuted,
                              height: 1.2,
                            ),
                          ),
                        ),
                    // Rail + ticks.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _labelRow,
                      bottom: 0,
                      child: CustomPaint(
                        painter: _RailPainter(
                          slots: [
                            for (var i = 0; i < widget.detents.length; i++)
                              _slotX(i, width),
                          ],
                          distinct: distinct,
                          knobX: knobX,
                          track: c.ink600,
                          fill: c.gold,
                          tick: c.textFaint,
                          knob: c.gold,
                          knobRing: c.ink900,
                        ),
                      ),
                    ),
                    // Readout above the knob while dragging (§4.5).
                    if (_dragging)
                      Positioned(
                        left: knobX - 40,
                        top: -2,
                        width: 80,
                        child: Text(
                          '${fmtBb(widget.value, widget.bigBlind)} bb',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: AllInText.mono(12, color: c.goldLight),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.slots,
    required this.distinct,
    required this.knobX,
    required this.track,
    required this.fill,
    required this.tick,
    required this.knob,
    required this.knobRing,
  });

  final List<double> slots;
  final Set<int> distinct;
  final double knobX;
  final Color track;
  final Color fill;
  final Color tick;
  final Color knob;
  final Color knobRing;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = slots.isEmpty ? 0.0 : slots.first;
    final right = slots.isEmpty ? size.width : slots.last;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, cy - 3, right, cy + 3),
        const Radius.circular(3),
      ),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, cy - 3, knobX.clamp(left, right), cy + 3),
        const Radius.circular(3),
      ),
      Paint()..color = fill.withValues(alpha: 0.65),
    );

    for (var i = 0; i < slots.length; i++) {
      if (!distinct.contains(i)) continue;
      canvas.drawCircle(
        Offset(slots[i], cy),
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tick,
      );
    }

    // Knob: 28 pt of paint, centred on the value.
    canvas.drawCircle(Offset(knobX, cy), 14, Paint()..color = knob);
    canvas.drawCircle(
      Offset(knobX, cy),
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = knobRing.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.knobX != knobX ||
      old.slots.length != slots.length ||
      !_sameSlots(old.slots) ||
      old.distinct.length != distinct.length;

  bool _sameSlots(List<double> other) {
    for (var i = 0; i < slots.length; i++) {
      if (other[i] != slots[i]) return false;
    }
    return true;
  }
}
