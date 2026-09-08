/// `RangeMatrix` — the 13×13 starting-hand grid (DESIGN.md §10.4).
///
/// Width-driven: the caller passes the box the grid may occupy and the widget
/// solves for the cell with the one formula of §4.9
/// (`cell = floor((W − H − 12g) / 13)`, `grid = H + 13·cell + 12g ≤ W`).
/// Finger-painting, header selectors, the loupe and the 20-deep undo are §4.9;
/// the eager pan recognizer that beats an enclosing `Scrollable` is §6.5.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../engine/notation.dart';
import '../../engine/types.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../foundations/term_text.dart' show HitSlop;
import 'range_matrix_loupe.dart';

/// Which of the three §10.4 constructors built the matrix.
enum RangeMatrixMode { readOnly, editable, compare }

/// What one cell is showing. Drives both the fill and the semantics string.
enum RangeCellState {
  /// Nothing to say about this hand (`ink700`, faint label).
  off,

  /// Painted by the user (`.editable`) — kind colour.
  painted,

  /// In the highlighted set (`.readOnly`) — kind colour.
  highlighted,

  /// `.compare`: painted **and** actually in the range.
  correct,

  /// `.compare`: in the range but not painted.
  missed,

  /// `.compare`: painted but not in the range.
  extra,
}

/// A grid coordinate. Row = the higher rank, column = the lower rank; above the
/// diagonal is suited, below it offsuit (`labelAt` in engine/notation.dart).
@immutable
class RangeCell {
  const RangeCell(this.row, this.col);

  final int row;
  final int col;

  HandLabel get label => labelAt(row, col);

  @override
  bool operator ==(Object other) =>
      other is RangeCell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 13 + col;

  @override
  String toString() => 'RangeCell($row, $col) ${labelAt(row, col)}';
}

/// The 20-deep stroke history behind Undo (§4.9). One entry per *stroke*: a
/// drag, a tap, a header selector, a preset or Clear.
///
/// The matrix records the set as it was **before** the stroke; the screen that
/// applies a preset or Clear records one entry itself, then feeds
/// [undo]'s result back into its own state.
class UndoController extends ChangeNotifier {
  UndoController({this.depth = 20}) : assert(depth > 0);

  /// How many strokes are kept (§4.9: 20).
  final int depth;

  final List<Set<HandLabel>> _stack = <Set<HandLabel>>[];

  bool get canUndo => _stack.isNotEmpty;
  int get length => _stack.length;

  /// Push the pre-stroke snapshot. Call this once per stroke, before mutating.
  void record(Set<HandLabel> before) {
    _stack.add(<HandLabel>{...before});
    while (_stack.length > depth) {
      _stack.removeAt(0);
    }
    notifyListeners();
  }

  /// Pop the last snapshot, or null when there is nothing to undo.
  Set<HandLabel>? undo() {
    if (_stack.isEmpty) return null;
    final restored = _stack.removeLast();
    notifyListeners();
    return restored;
  }

  void clear() {
    if (_stack.isEmpty) return;
    _stack.clear();
    notifyListeners();
  }
}

/// The solved geometry of one matrix — the whole of the §4.9 arithmetic, pulled
/// out of the widget so call sites and tests can check a box before laying out.
@immutable
class RangeMatrixGeometry {
  const RangeMatrixGeometry({
    required this.width,
    required this.headerWidth,
    required this.gap,
    required this.cell,
    required this.hairline,
    required this.showHeaders,
  });

  /// The box the grid was allowed to occupy.
  final double width;

  /// Row-header column width (0 when [showHeaders] is false). The column-header
  /// row is the same size, so the grid stays square.
  final double headerWidth;

  /// 0 (hairline), 1 or 2 (§4.9).
  final double gap;

  /// The solved cell edge.
  final double cell;
  final bool hairline;
  final bool showHeaders;

  static const int n = 13;

  /// Below this the in-cell label is omitted entirely (§4.9).
  static const double labelFloorCell = 20;

  double get headerHeight => headerWidth;
  double get cellsExtent => n * cell + (n - 1) * gap;
  double get gridWidth => headerWidth + cellsExtent;
  double get gridHeight => headerHeight + cellsExtent;

  /// In-cell label size, `min(11, cell × 0.40)`; 0 below [labelFloorCell].
  double get labelSize =>
      cell < labelFloorCell ? 0 : math.min(11.0, cell * 0.40);

  /// `cell = floor((W − H − 12g) / 13)`.
  ///
  /// [textScale] > 1.3 widens the row header and switches the grid to
  /// [hairline] (gap 0 with a 1 pt divider painted inside each cell), which is
  /// the sanctioned way to buy the point back (§4.9 note 2).
  static RangeMatrixGeometry solve({
    required double width,
    double headerWidth = 20,
    double gap = 1,
    bool hairline = false,
    bool showHeaders = true,
    double textScale = 1,
  }) {
    final useHairline = hairline || textScale > 1.3;
    final g = useHairline ? 0.0 : gap;
    final h =
        showHeaders
            ? headerWidth * (textScale > 1 ? math.min(textScale, 1.5) : 1.0)
            : 0.0;
    final raw = (width - h - (n - 1) * g) / n;
    final cell = math.max(1.0, raw.floorToDouble());
    return RangeMatrixGeometry(
      width: width,
      headerWidth: h,
      gap: g,
      cell: cell,
      hairline: useHairline,
      showHeaders: showHeaders,
    );
  }

  Rect rectFor(int row, int col) => Rect.fromLTWH(
    headerWidth + col * (cell + gap),
    headerHeight + row * (cell + gap),
    cell,
    cell,
  );

  Rect columnHeaderRect(int col) =>
      Rect.fromLTWH(headerWidth + col * (cell + gap), 0, cell, headerHeight);

  Rect rowHeaderRect(int row) =>
      Rect.fromLTWH(0, headerHeight + row * (cell + gap), headerWidth, cell);

  /// Cell under [p] (grid coordinates, headers included), or null outside.
  RangeCell? cellAt(Offset p) {
    final x = p.dx - headerWidth;
    final y = p.dy - headerHeight;
    if (x < 0 || y < 0) return null;
    final col = (x / (cell + gap)).floor();
    final row = (y / (cell + gap)).floor();
    if (row < 0 || row > 12 || col < 0 || col > 12) return null;
    return RangeCell(row, col);
  }

  /// Like [cellAt] but clamped, for drags that leave the grid mid-stroke.
  RangeCell clampedCellAt(Offset p) {
    final col = ((p.dx - headerWidth) / (cell + gap)).floor().clamp(0, 12);
    final row = ((p.dy - headerHeight) / (cell + gap)).floor().clamp(0, 12);
    return RangeCell(row, col);
  }
}

/// Publishes the grid's bounds as an Android system-gesture exclusion rect
/// (§4.9). The framework has no API for `View.setSystemGestureExclusionRects`,
/// so the host app installs a thin platform adapter here (§16.6); `null` means
/// "clear the rect".
typedef SystemGestureExclusionReporter = void Function(Rect? bounds);

class RangeMatrix extends StatefulWidget {
  /// Read-only view of [highlight] (an assumed range, a chart, a peek result).
  /// Publishes no gesture-exclusion rect: nothing is lost if a stray drag pops
  /// a viewer (§4.9).
  const RangeMatrix.readOnly({
    super.key,
    this.highlight = const <HandLabel>{},
    required this.width,
    this.gap = 1,
    this.headerWidth = 20,
    this.hairline = false,
    this.showHeaders = true,
    this.loupe = false,
    this.gestureExclusion = false,
    this.hatchWhenNoColour = false,
    this.ring = const <HandLabel>{},
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : mode = RangeMatrixMode.readOnly,
       value = const <HandLabel>{},
       onChanged = null,
       undoController = null,
       painted = const <HandLabel>{},
       actual = const <HandLabel>{};

  /// The finger-painting surface (§4.9). [onChanged] fires per painted cell.
  const RangeMatrix.editable({
    super.key,
    this.value = const <HandLabel>{},
    required this.onChanged,
    this.undoController,
    required this.width,
    this.gap = 1,
    this.headerWidth = 20,
    this.hairline = false,
    this.showHeaders = true,
    this.loupe = true,
    this.gestureExclusion = true,
    this.hatchWhenNoColour = false,
    this.ring = const <HandLabel>{},
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : mode = RangeMatrixMode.editable,
       highlight = const <HandLabel>{},
       painted = const <HandLabel>{},
       actual = const <HandLabel>{};

  /// Peek / grading colouring: `good` correct · `warn` missed · `bad` extra.
  const RangeMatrix.compare({
    super.key,
    required this.painted,
    required this.actual,
    required this.width,
    this.gap = 1,
    this.headerWidth = 20,
    this.hairline = false,
    this.showHeaders = true,
    this.loupe = false,
    this.gestureExclusion = true,
    this.hatchWhenNoColour = false,
    this.ring = const <HandLabel>{},
    this.semanticLabel,
    this.enableHaptics = true,
    this.reducedMotion = false,
  }) : mode = RangeMatrixMode.compare,
       highlight = const <HandLabel>{},
       value = const <HandLabel>{},
       onChanged = null,
       undoController = null;

  final RangeMatrixMode mode;

  /// `.readOnly` — the cells to fill in their kind colour.
  final Set<HandLabel> highlight;

  /// `.editable` — the painted set (controlled: the parent owns it).
  final Set<HandLabel> value;
  final ValueChanged<Set<HandLabel>>? onChanged;
  final UndoController? undoController;

  /// `.compare` — what the user painted and what the range actually is.
  final Set<HandLabel> painted;
  final Set<HandLabel> actual;

  /// The box the grid may occupy (§4.9); the grid is centred inside it.
  final double width;

  /// 1 or 2; forced to 0 when [hairline].
  final double gap;
  final double headerWidth;

  /// Gap 0 with a 1 pt divider inside each cell — the tight-box fallback.
  final bool hairline;
  final bool showHeaders;

  /// 56 pt magnifier under the finger while painting (§4.9 mechanism 3).
  final bool loupe;

  /// Publish [exclusionReporter] rects while this matrix is on screen.
  final bool gestureExclusion;

  /// Hatch missed / dot extra (compare) and hatch suited / dot offsuit (kind)
  /// so the grid reads without colour (§13). Also on when the OS asks for high
  /// contrast.
  final bool hatchWhenNoColour;

  /// Cells ringed in gold — the seat's actual hand on the P8 compare grid
  /// (§4.12).
  final Set<HandLabel> ring;

  final String? semanticLabel;
  final bool enableHaptics;
  final bool reducedMotion;

  /// Cell-fill animation (§11: "Range paint · cell fill · 80 ms").
  static const Duration fillDuration = Duration(milliseconds: 80);

  /// §11: `selectionClick` per painted cell, ≥ 30 ms apart.
  static const Duration hapticThrottle = Duration(milliseconds: 30);

  /// Platform adapter for `View.setSystemGestureExclusionRects` (§4.9, §16.6).
  static SystemGestureExclusionReporter? exclusionReporter;

  /// Fill for one cell — the single source of truth shared by the painter, the
  /// loupe and the tests.
  static Color fillColor(
    AllInColors colors,
    RangeCellState state,
    ComboKind kind,
  ) {
    switch (state) {
      case RangeCellState.off:
        return colors.ink700;
      case RangeCellState.painted:
      case RangeCellState.highlighted:
        return kindColor(colors, kind);
      case RangeCellState.correct:
        return colors.good;
      case RangeCellState.missed:
        return colors.warn;
      case RangeCellState.extra:
        return colors.bad;
    }
  }

  static Color kindColor(AllInColors colors, ComboKind kind) {
    switch (kind) {
      case ComboKind.pair:
        return AllInColors.comboPair;
      case ComboKind.suited:
        return AllInColors.comboSuited;
      case ComboKind.offsuit:
        return colors.comboOffsuit;
    }
  }

  /// Label colour on top of [fill] — light text on dark fills, dark on light,
  /// `textFaint` on empty cells. Both are palette tokens; no literal hex.
  static Color labelColor(
    AllInColors colors,
    RangeCellState state,
    Color fill,
  ) {
    if (state == RangeCellState.off) return colors.textFaint;
    return fill.computeLuminance() > 0.5
        ? AllInColors.light.text
        : AllInColors.dark.text;
  }

  /// The state of one cell in each mode — pure, so tests do not need pixels.
  static RangeCellState stateFor({
    required RangeMatrixMode mode,
    required HandLabel label,
    Set<HandLabel> highlight = const <HandLabel>{},
    Set<HandLabel> value = const <HandLabel>{},
    Set<HandLabel> painted = const <HandLabel>{},
    Set<HandLabel> actual = const <HandLabel>{},
  }) {
    switch (mode) {
      case RangeMatrixMode.compare:
        final inPainted = painted.contains(label);
        final inActual = actual.contains(label);
        if (inPainted && inActual) return RangeCellState.correct;
        if (inActual) return RangeCellState.missed;
        if (inPainted) return RangeCellState.extra;
        return RangeCellState.off;
      case RangeMatrixMode.readOnly:
        return highlight.contains(label)
            ? RangeCellState.highlighted
            : RangeCellState.off;
      case RangeMatrixMode.editable:
        return value.contains(label)
            ? RangeCellState.painted
            : RangeCellState.off;
    }
  }

  @override
  State<RangeMatrix> createState() => _RangeMatrixState();
}

class _LoupeData {
  const _LoupeData(this.globalPosition, this.cell);
  final Offset globalPosition;
  final RangeCell cell;
}

class _RangeMatrixState extends State<RangeMatrix>
    with SingleTickerProviderStateMixin {
  /// The set as it is mid-stroke (the parent may rebuild a frame later).
  Set<HandLabel>? _stroke;
  bool _addMode = true;
  bool _painting = false;
  RangeCell? _last;
  Duration _lastHaptic = Duration.zero;
  final Stopwatch _clock = Stopwatch()..start();
  PointerDeviceKind _pointerKind = PointerDeviceKind.touch;

  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: RangeMatrix.fillDuration,
  );
  final Set<HandLabel> _animating = <HandLabel>{};

  final ValueNotifier<_LoupeData?> _loupe = ValueNotifier<_LoupeData?>(null);
  OverlayEntry? _loupeEntry;

  ScrollPosition? _scroll;
  Rect? _publishedRect;

  Set<HandLabel> get _current => _stroke ?? widget.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_scheduleExclusion);
      _scroll = position;
      _scroll?.addListener(_scheduleExclusion);
    }
    _scheduleExclusion();
  }

  @override
  void didUpdateWidget(RangeMatrix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gestureExclusion != widget.gestureExclusion) {
      _scheduleExclusion();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_scheduleExclusion);
    _hideLoupe();
    _loupe.dispose();
    _fill.dispose();
    if (_publishedRect != null) {
      RangeMatrix.exclusionReporter?.call(null);
      _publishedRect = null;
    }
    _clock.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------- exclusion

  void _scheduleExclusion() {
    if (RangeMatrix.exclusionReporter == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishExclusion());
  }

  void _publishExclusion() {
    final reporter = RangeMatrix.exclusionReporter;
    if (reporter == null || !mounted) return;
    Rect? rect;
    if (widget.gestureExclusion && widget.mode != RangeMatrixMode.readOnly) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.attached) {
        rect = box.localToGlobal(Offset.zero) & box.size;
        // Inside a scroll view only the visible part is excluded (§4.9).
        final viewport = _viewportRect();
        if (viewport != null) rect = rect.intersect(viewport);
        if (rect.isEmpty) rect = null;
      }
    }
    if (rect == _publishedRect) return;
    _publishedRect = rect;
    reporter(rect);
  }

  Rect? _viewportRect() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return null;
    final box = scrollable.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ------------------------------------------------------------------ editing

  void _beginStroke(Set<HandLabel> before) {
    widget.undoController?.record(before);
  }

  void _emit(Set<HandLabel> next, Iterable<HandLabel> changed) {
    setState(() {
      _stroke = next;
      _animating
        ..clear()
        ..addAll(changed);
    });
    if (!widget.reducedMotion) {
      _fill.forward(from: 0);
    }
    widget.onChanged?.call(next);
  }

  void _haptic() {
    if (!widget.enableHaptics) return;
    final now = _clock.elapsed;
    if (now - _lastHaptic < RangeMatrix.hapticThrottle) return;
    _lastHaptic = now;
    HapticFeedback.selectionClick();
  }

  /// Apply the stroke mode to one cell; no-op when it is already there.
  void _apply(HandLabel label) {
    final current = _current;
    if (current.contains(label) == _addMode) return;
    final next = <HandLabel>{...current};
    if (_addMode) {
      next.add(label);
    } else {
      next.remove(label);
    }
    _haptic();
    _emit(next, <HandLabel>[label]);
  }

  void _replace(Set<HandLabel> next, {required bool record}) {
    final before = _current;
    if (record) _beginStroke(before);
    final changed = <HandLabel>{
      ...next.difference(before),
      ...before.difference(next),
    };
    if (changed.isEmpty) return;
    _haptic();
    _emit(next, changed);
  }

  void _toggleRow(int row) {
    final labels = <HandLabel>[for (var c = 0; c < 13; c++) labelAt(row, c)];
    _toggleAll(labels);
  }

  void _toggleColumn(int col) {
    final labels = <HandLabel>[for (var r = 0; r < 13; r++) labelAt(r, col)];
    _toggleAll(labels);
  }

  void _togglePairs() {
    _toggleAll(<HandLabel>[for (var i = 0; i < 13; i++) labelAt(i, i)]);
  }

  /// Mode = the majority state inverted (§4.9 mechanism 5).
  void _toggleAll(List<HandLabel> labels) {
    if (widget.mode != RangeMatrixMode.editable) return;
    final current = _current;
    final on = labels.where(current.contains).length;
    final add = on * 2 <= labels.length;
    final next = <HandLabel>{...current};
    if (add) {
      next.addAll(labels);
    } else {
      next.removeAll(labels);
    }
    _replace(next, record: true);
  }

  /// Long-press a row header: that pair and every better pair ("9" → 99+).
  void _rowAndBetter(int row) {
    if (widget.mode != RangeMatrixMode.editable) return;
    final next = <HandLabel>{
      ..._current,
      for (var i = 0; i <= row; i++) labelAt(i, i),
    };
    _replace(next, record: true);
  }

  /// Long-press a column header: the suited runs down to that kicker
  /// ("9" → AKs–A9s, KQs–K9s, … — the "A9s+ style" of §4.9 mechanism 5).
  void _columnAndBetter(int col) {
    if (widget.mode != RangeMatrixMode.editable) return;
    final next = <HandLabel>{..._current};
    for (var r = 0; r < col; r++) {
      for (var c = r + 1; c <= col; c++) {
        next.add(labelAt(r, c));
      }
    }
    _replace(next, record: true);
  }

  // ----------------------------------------------------------------- painting

  void _onDown(DragDownDetails d, RangeMatrixGeometry geo) {
    final cell = geo.clampedCellAt(
      d.localPosition + Offset(geo.headerWidth, geo.headerHeight),
    );
    final label = cell.label;
    _painting = true;
    _last = cell;
    _addMode = !_current.contains(label);
    _beginStroke(_current);
    _apply(label);
    _showLoupe(d.globalPosition, cell);
  }

  void _onUpdate(DragUpdateDetails d, RangeMatrixGeometry geo) {
    if (!_painting) return;
    final cell = geo.clampedCellAt(
      d.localPosition + Offset(geo.headerWidth, geo.headerHeight),
    );
    final from = _last;
    if (from != null && from != cell) {
      for (final step in _interpolate(from, cell)) {
        _apply(step.label);
      }
    }
    _last = cell;
    _showLoupe(d.globalPosition, cell);
  }

  void _endStroke() {
    _painting = false;
    _last = null;
    if (_stroke != null && mounted) {
      setState(() => _stroke = null);
    } else {
      _stroke = null;
    }
    _hideLoupe();
  }

  /// Bresenham over cell indices so a fast diagonal never skips a cell (§4.9).
  static List<RangeCell> _interpolate(RangeCell a, RangeCell b) {
    final out = <RangeCell>[];
    var r = a.row;
    var c = a.col;
    final dr = (b.row - r).abs();
    final dc = (b.col - c).abs();
    final sr = r < b.row ? 1 : -1;
    final sc = c < b.col ? 1 : -1;
    var err = dc - dr;
    while (true) {
      if (r != a.row || c != a.col) out.add(RangeCell(r, c));
      if (r == b.row && c == b.col) break;
      final e2 = 2 * err;
      if (e2 > -dr) {
        err -= dr;
        c += sc;
      }
      if (e2 < dc) {
        err += dc;
        r += sr;
      }
    }
    return out;
  }

  // -------------------------------------------------------------------- loupe

  void _showLoupe(Offset global, RangeCell cell) {
    if (!widget.loupe || _pointerKind != PointerDeviceKind.touch) return;
    _loupe.value = _LoupeData(global, cell);
    if (_loupeEntry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _loupeEntry = OverlayEntry(builder: _buildLoupe);
    overlay.insert(_loupeEntry!);
  }

  void _hideLoupe() {
    _loupe.value = null;
    _loupeEntry?.remove();
    _loupeEntry = null;
  }

  Widget _buildLoupe(BuildContext overlayContext) {
    return ValueListenableBuilder<_LoupeData?>(
      valueListenable: _loupe,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        const size = 56.0;
        const height = size + RangeMatrixLoupe.labelHeight + 8;
        final media = MediaQuery.of(context);
        final bounds =
            _viewportRect() ??
            (Offset.zero & media.size)
                .deflate(0)
                .intersect(
                  Rect.fromLTWH(0, 0, media.size.width, media.size.height),
                );
        var top = data.globalPosition.dy - 48 - height;
        if (top < bounds.top + 4) top = data.globalPosition.dy + 48;
        final left =
            (data.globalPosition.dx - size / 2)
                .clamp(
                  bounds.left + 4,
                  math.max(bounds.left + 4, bounds.right - size - 4),
                )
                .toDouble();
        top =
            top
                .clamp(
                  bounds.top + 4,
                  math.max(bounds.top + 4, bounds.bottom - height - 4),
                )
                .toDouble();
        final colors = Theme.of(context).extension<AllInTheme>()?.colors;
        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: RangeMatrixLoupe(
              row: data.cell.row,
              col: data.cell.col,
              size: size,
              fillFor:
                  (r, c) => _fillFor(
                    colors ?? AllInColors.dark,
                    labelAt(r.clamp(0, 12), c.clamp(0, 12)),
                  ),
            ),
          ),
        );
      },
    );
  }

  Color _fillFor(AllInColors colors, HandLabel label) => RangeMatrix.fillColor(
    colors,
    RangeMatrix.stateFor(
      mode: widget.mode,
      label: label,
      highlight: widget.highlight,
      value: _current,
      painted: widget.painted,
      actual: widget.actual,
    ),
    kindOf(label),
  );

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(10) / 10;
    final geo = RangeMatrixGeometry.solve(
      width: widget.width,
      headerWidth: widget.headerWidth,
      gap: widget.gap,
      hairline: widget.hairline,
      showHeaders: widget.showHeaders,
      textScale: scale,
    );
    assert(
      geo.gridWidth <= widget.width + 0.5,
      'RangeMatrix: grid ${geo.gridWidth} exceeds its box ${widget.width} '
      '(cell ${geo.cell}, header ${geo.headerWidth}, gap ${geo.gap}).',
    );
    _fill.duration = AllInMotion.of(
      context,
      RangeMatrix.fillDuration,
      reduced: widget.reducedMotion,
    );
    final editable = widget.mode == RangeMatrixMode.editable;
    final hatch = widget.hatchWhenNoColour || media.highContrast;

    final grid = SizedBox(
      width: geo.gridWidth,
      height: geo.gridHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _fill,
                builder:
                    (context, _) => CustomPaint(
                      painter: _RangeMatrixPainter(
                        geometry: geo,
                        colors: colors,
                        mode: widget.mode,
                        highlight: widget.highlight,
                        value: _current,
                        painted: widget.painted,
                        actual: widget.actual,
                        ring: widget.ring,
                        hatch: hatch,
                        animating: _animating,
                        t: _fill.isAnimating ? _fill.value : 1,
                      ),
                      size: Size(geo.gridWidth, geo.gridHeight),
                    ),
              ),
            ),
          ),
          for (var r = 0; r < 13; r++) _semanticRow(r, geo, editable),
          if (geo.showHeaders) ..._headerTargets(geo, editable),
          if (editable)
            Positioned(
              left: geo.headerWidth,
              top: geo.headerHeight,
              width: geo.cellsExtent,
              height: geo.cellsExtent,
              child: Listener(
                onPointerDown: (e) => _pointerKind = e.kind,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    _EagerPanGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _EagerPanGestureRecognizer
                        >(() => _EagerPanGestureRecognizer(), (r) {
                          r.onDown = (d) {
                            _onDown(d, geo);
                          };
                          r.onUpdate = (d) {
                            _onUpdate(d, geo);
                          };
                          r.onEnd = (_) {
                            _endStroke();
                          };
                          r.onCancel = _endStroke;
                        }),
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      child: SizedBox(
        width: widget.width,
        height: geo.gridHeight,
        child: Center(child: grid),
      ),
    );
  }

  Widget _semanticRow(int row, RangeMatrixGeometry geo, bool editable) {
    return Positioned(
      left: geo.headerWidth,
      top: geo.headerHeight + row * (geo.cell + geo.gap),
      width: geo.cellsExtent,
      height: geo.cell,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: '${_rankName(kRanksDesc[row])} row',
        customSemanticsActions:
            editable
                ? <CustomSemanticsAction, VoidCallback>{
                  const CustomSemanticsAction(label: 'Toggle row'):
                      () => _toggleRow(row),
                }
                : null,
        child: Row(
          children: <Widget>[
            for (var col = 0; col < 13; col++) ...<Widget>[
              if (col > 0) SizedBox(width: geo.gap),
              SizedBox(
                width: geo.cell,
                child: Semantics(
                  container: true,
                  label: _cellSemantics(row, col),
                  customSemanticsActions:
                      editable
                          ? <CustomSemanticsAction, VoidCallback>{
                            const CustomSemanticsAction(label: 'Toggle column'):
                                () => _toggleColumn(col),
                          }
                          : null,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _headerTargets(RangeMatrixGeometry geo, bool editable) {
    final targets = <Widget>[];
    for (var col = 0; col < 13; col++) {
      final rect = geo.columnHeaderRect(col);
      targets.add(
        Positioned.fromRect(
          rect: rect,
          child: HitSlop(
            minSize: Size(rect.width, 44),
            child: _HeaderTarget(
              label: 'Toggle column ${_rankName(kRanksDesc[col])}',
              onTap: editable ? () => _toggleColumn(col) : null,
              onLongPress: editable ? () => _columnAndBetter(col) : null,
              enableHaptics: widget.enableHaptics,
            ),
          ),
        ),
      );
    }
    for (var row = 0; row < 13; row++) {
      final rect = geo.rowHeaderRect(row);
      targets.add(
        Positioned.fromRect(
          rect: rect,
          child: HitSlop(
            minSize: Size(44, rect.height),
            child: _HeaderTarget(
              label: 'Toggle row ${_rankName(kRanksDesc[row])}',
              onTap: editable ? () => _toggleRow(row) : null,
              onLongPress: editable ? () => _rowAndBetter(row) : null,
              enableHaptics: widget.enableHaptics,
            ),
          ),
        ),
      );
    }
    targets.add(
      Positioned.fromRect(
        rect: Rect.fromLTWH(0, 0, geo.headerWidth, geo.headerHeight),
        child: HitSlop(
          minSize: const Size(44, 44),
          child: _HeaderTarget(
            label: 'Toggle all pairs',
            onTap: editable ? _togglePairs : null,
            onLongPress: null,
            enableHaptics: widget.enableHaptics,
          ),
        ),
      ),
    );
    return targets;
  }

  String _cellSemantics(int row, int col) {
    final label = labelAt(row, col);
    final name = _spokenLabel(label);
    switch (RangeMatrix.stateFor(
      mode: widget.mode,
      label: label,
      highlight: widget.highlight,
      value: _current,
      painted: widget.painted,
      actual: widget.actual,
    )) {
      case RangeCellState.off:
        return widget.mode == RangeMatrixMode.compare
            ? '$name, not in their range'
            : '$name, not painted';
      case RangeCellState.painted:
        return '$name, painted';
      case RangeCellState.highlighted:
        return '$name, in range';
      case RangeCellState.correct:
        return '$name, correct';
      case RangeCellState.missed:
        return '$name, missed';
      case RangeCellState.extra:
        return '$name, extra';
    }
  }
}

String _spokenLabel(HandLabel label) {
  final hi = _rankName(label[0]);
  switch (kindOf(label)) {
    case ComboKind.pair:
      return '$hi pair';
    case ComboKind.suited:
      return '$hi ${_rankName(label[1])} suited';
    case ComboKind.offsuit:
      return '$hi ${_rankName(label[1])} offsuit';
  }
}

String _rankName(String rank) {
  switch (rank) {
    case 'A':
      return 'Ace';
    case 'K':
      return 'King';
    case 'Q':
      return 'Queen';
    case 'J':
      return 'Jack';
    case 'T':
      return 'Ten';
    case '9':
      return 'Nine';
    case '8':
      return 'Eight';
    case '7':
      return 'Seven';
    case '6':
      return 'Six';
    case '5':
      return 'Five';
    case '4':
      return 'Four';
    case '3':
      return 'Three';
    default:
      return 'Two';
  }
}

/// Tap / long-press only: a *drag* on a header is never claimed, which is what
/// lets an embedded matrix scroll its page from the margins (§6.5).
class _HeaderTarget extends StatelessWidget {
  const _HeaderTarget({
    required this.label,
    required this.onTap,
    required this.onLongPress,
    required this.enableHaptics,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) {
      return const SizedBox.expand();
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            onTap == null
                ? null
                : () {
                  if (enableHaptics) HapticFeedback.selectionClick();
                  onTap!();
                },
        onLongPress:
            onLongPress == null
                ? null
                : () {
                  if (enableHaptics) HapticFeedback.selectionClick();
                  onLongPress!();
                },
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Declares victory on touch-down and never yields to an enclosing
/// `Scrollable` (§6.5: "the grid claims every drag that starts inside its
/// cells").
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);

  @override
  String get debugDescription => 'range matrix paint';
}

class _RangeMatrixPainter extends CustomPainter {
  _RangeMatrixPainter({
    required this.geometry,
    required this.colors,
    required this.mode,
    required this.highlight,
    required this.value,
    required this.painted,
    required this.actual,
    required this.ring,
    required this.hatch,
    required this.animating,
    required this.t,
  });

  final RangeMatrixGeometry geometry;
  final AllInColors colors;
  final RangeMatrixMode mode;
  final Set<HandLabel> highlight;
  final Set<HandLabel> value;
  final Set<HandLabel> painted;
  final Set<HandLabel> actual;
  final Set<HandLabel> ring;
  final bool hatch;
  final Set<HandLabel> animating;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = geometry;
    final radius = Radius.circular(geo.cell >= 20 ? 3 : 2);
    final labelSize = geo.labelSize;

    for (var row = 0; row < 13; row++) {
      for (var col = 0; col < 13; col++) {
        final label = labelAt(row, col);
        final kind = kindOf(label);
        final state = RangeMatrix.stateFor(
          mode: mode,
          label: label,
          highlight: highlight,
          value: value,
          painted: painted,
          actual: actual,
        );
        final target = RangeMatrix.fillColor(colors, state, kind);
        var fill = target;
        if (animating.contains(label) && t < 1) {
          final from =
              state == RangeCellState.off
                  ? RangeMatrix.kindColor(colors, kind)
                  : colors.ink700;
          fill = Color.lerp(from, target, t) ?? target;
        }
        var rect = geo.rectFor(row, col);
        if (geo.hairline) {
          rect = Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width - 1,
            rect.height - 1,
          );
        }
        final rrect = RRect.fromRectAndRadius(rect, radius);
        canvas.drawRRect(rrect, Paint()..color = fill);

        final ink = RangeMatrix.labelColor(colors, state, fill);
        if (hatch) _paintTexture(canvas, rect, state, kind, ink);
        if (ring.contains(label)) {
          canvas.drawRRect(
            rrect.deflate(0.75),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = colors.gold,
          );
        }
        if (labelSize > 0) {
          _text(
            canvas,
            label,
            rect,
            AllInText.mono(
              labelSize,
              weight: FontWeight.w600,
              color:
                  state == RangeCellState.off
                      ? ink.withValues(alpha: 0.92)
                      : ink,
            ),
          );
        }
      }
    }

    if (!geo.showHeaders) return;
    final headerStyle = AllInText.mono(
      math.min(11.0, math.max(8.0, geo.headerWidth * 0.55)),
      weight: FontWeight.w600,
      color: colors.textMuted,
    );
    for (var i = 0; i < 13; i++) {
      _text(canvas, kRanksDesc[i], geo.columnHeaderRect(i), headerStyle);
      _text(canvas, kRanksDesc[i], geo.rowHeaderRect(i), headerStyle);
    }
  }

  /// Diagonal hatching / centre dots so the grid reads without colour (§13).
  void _paintTexture(
    Canvas canvas,
    Rect rect,
    RangeCellState state,
    ComboKind kind,
    Color ink,
  ) {
    final bool hatched;
    final bool dotted;
    switch (state) {
      case RangeCellState.missed:
        hatched = true;
        dotted = false;
      case RangeCellState.extra:
        hatched = false;
        dotted = true;
      case RangeCellState.painted:
      case RangeCellState.highlighted:
        hatched = kind == ComboKind.suited;
        dotted = kind == ComboKind.offsuit;
      case RangeCellState.off:
      case RangeCellState.correct:
        hatched = false;
        dotted = false;
    }
    if (!hatched && !dotted) return;
    final paint =
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..strokeWidth = 1;
    if (hatched) {
      canvas.save();
      canvas.clipRect(rect);
      for (var x = rect.left - rect.height; x < rect.right; x += 5) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          paint,
        );
      }
      canvas.restore();
    } else {
      canvas.drawCircle(rect.center, math.max(1.0, rect.width * 0.08), paint);
    }
  }

  void _text(Canvas canvas, String text, Rect rect, TextStyle style) {
    final key = '$text|${style.fontSize}|${style.color?.toARGB32()}';
    final tp = _textCache.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (_textCache.length > 600) _textCache.clear();
      return painter;
    });
    tp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      ),
    );
  }

  static final Map<String, TextPainter> _textCache = <String, TextPainter>{};

  @override
  bool shouldRepaint(_RangeMatrixPainter old) =>
      old.geometry.cell != geometry.cell ||
      old.geometry.gap != geometry.gap ||
      old.geometry.headerWidth != geometry.headerWidth ||
      old.colors != colors ||
      old.mode != mode ||
      old.hatch != hatch ||
      old.t != t ||
      !setEquals(old.value, value) ||
      !setEquals(old.highlight, highlight) ||
      !setEquals(old.painted, painted) ||
      !setEquals(old.actual, actual) ||
      !setEquals(old.ring, ring);
}
