/// `AllInSlider` — the single-thumb slider used by settings and every study
/// calculator (DESIGN.md §10.1, §6.5).
///
/// Gold fill, 16 pt thumb, a 44 pt hit band (§12) and a `selectionClick` each
/// time the value moves a step (§11). `detents` are magnet values the thumb
/// snaps to when it lands within half a step of one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

class AllInSlider extends StatefulWidget {
  const AllInSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.step = 0,
    this.detents = const <double>[],
    this.onChangeEnd,
    this.semanticLabel,
    this.semanticFormatter,
    this.enableHaptics = true,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;

  /// Quantum the value moves in; 0 means continuous.
  final double step;

  /// Values the thumb magnets to (rail detents, "1/2 pot", "pot"…).
  final List<double> detents;
  final String? semanticLabel;

  /// Announced value for screen readers ("7.5 big blinds").
  final String Function(double value)? semanticFormatter;
  final bool enableHaptics;

  static const double hitHeight = 44;

  @override
  State<AllInSlider> createState() => _AllInSliderState();
}

class _AllInSliderState extends State<AllInSlider> {
  double? _lastEmitted;

  double _snap(double raw) {
    var v = raw;
    if (widget.step > 0) {
      final steps = ((raw - widget.min) / widget.step).round();
      v = widget.min + steps * widget.step;
    }
    if (widget.detents.isNotEmpty) {
      final tolerance =
          widget.step > 0 ? widget.step / 2 : (widget.max - widget.min) * 0.02;
      for (final d in widget.detents) {
        if ((raw - d).abs() <= tolerance) {
          v = d;
          break;
        }
      }
    }
    return v.clamp(widget.min, widget.max);
  }

  void _handle(double raw) {
    final v = _snap(raw);
    if (_lastEmitted != null && (v - _lastEmitted!).abs() < 1e-9) return;
    _lastEmitted = v;
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final divisions =
        widget.step > 0 && widget.max > widget.min
            ? math.max(1, ((widget.max - widget.min) / widget.step).round())
            : null;

    return SizedBox(
      height: AllInSlider.hitHeight,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: c.gold,
          inactiveTrackColor: c.ink600,
          thumbColor: c.gold,
          overlayColor: c.gold.withValues(alpha: 0.12),
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
        child: Slider(
          value: widget.value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          divisions: divisions,
          label: widget.semanticFormatter?.call(widget.value),
          semanticFormatterCallback: widget.semanticFormatter,
          onChanged: _handle,
          onChangeEnd: (v) {
            _lastEmitted = null;
            widget.onChangeEnd?.call(_snap(v));
          },
        ),
      ),
    );
  }
}
