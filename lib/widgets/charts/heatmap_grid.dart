/// `HeatmapGrid` — the practice heatmap (DESIGN.md §10.1, §7.11): 16 weeks × 7,
/// column-major, oldest left, today the last cell of the last column; cells
/// 11 pt + 3 pt gap. Colours: `gold` (goal met) · gold @ 35 % over `ink600`
/// (active) · `ink700` (nothing).
///
/// **Cells are 11 pt, so the grid is drag-to-inspect, not tap-to-inspect**
/// (§7.11, §12): a 200 ms hold claims the pointer from the page scroll, a label
/// follows the finger, and the cell under it takes a 1 pt gold outline. A plain
/// tap does nothing — the grid is a picture of a habit, not a control. For
/// screen readers it is one summary node with one child per column, so nothing
/// is drag-only.
///
/// The Home mini-heatmap passes `inspectable: false`: it is a picture inside
/// one 72 pt tap target that opens Stats (§3.5).
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/persistence/goals_store.dart' show HeatmapCell;
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class HeatmapGrid extends StatefulWidget {
  const HeatmapGrid({
    super.key,
    required this.cells,
    this.weeks = 16,
    this.cellSize = 11,
    this.gap = 3,
    this.onTapCell,
    this.inspectable = true,
    this.labelBuilder,
    this.enableHaptics = true,
    this.reducedMotion = false,
    this.semanticLabel,
  });

  /// `GoalsStore.heatmapCells()` — oldest first, seven per column.
  final List<HeatmapCell> cells;

  final int weeks;
  final double cellSize;
  final double gap;

  /// Called with the cell under the finger while it is being inspected. Per
  /// §7.11 a plain tap never fires it.
  final ValueChanged<HeatmapCell>? onTapCell;

  /// False for the Home mini-heatmap: no gesture, no label.
  final bool inspectable;

  /// "2026-09-03: 24 reps · goal met" by default (desktop copy).
  final String Function(HeatmapCell cell)? labelBuilder;

  final bool enableHaptics;

  /// Accepted for API symmetry with the other charts; nothing here
  /// animates, so the strip is identical either way (§11).
  final bool reducedMotion;

  /// Overrides the summary node ("Practice heatmap, 41 active days…").
  final String? semanticLabel;

  static const int rows = 7;
  static const Duration holdToInspect = Duration(milliseconds: 200);
  static const Duration labelLinger = Duration(milliseconds: 1500);

  /// Days with any activity — the caption's "{n} active days" number.
  static int activeDays(List<HeatmapCell> cells) =>
      cells.where((c) => c.count > 0).length;

  @override
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid> {
  int? _index;
  String? _label;
  Timer? _clear;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  int get _columns =>
      widget.cells.isEmpty
          ? widget.weeks
          : (widget.cells.length + HeatmapGrid.rows - 1) ~/ HeatmapGrid.rows;

  double get _gridWidth =>
      _columns * widget.cellSize + (_columns - 1) * widget.gap;

  double get _gridHeight =>
      HeatmapGrid.rows * widget.cellSize + (HeatmapGrid.rows - 1) * widget.gap;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  int? _indexAt(Offset position) {
    final step = widget.cellSize + widget.gap;
    if (step <= 0) return null;
    final column = (position.dx / step).floor();
    final row = (position.dy / step).floor();
    if (column < 0 || row < 0 || row >= HeatmapGrid.rows) return null;
    final index = column * HeatmapGrid.rows + row;
    if (index < 0 || index >= widget.cells.length) return null;
    return index;
  }

  String _labelFor(HeatmapCell cell) =>
      widget.labelBuilder?.call(cell) ??
      '${cell.key}: ${cell.count} reps${cell.met ? ' · goal met' : ''}';

  void _inspect(Offset position) {
    final next = _indexAt(position);
    if (next == null || next == _index) return;
    _clear?.cancel();
    // §7.11: one selectionClick per cell, throttled to 30 ms.
    final now = DateTime.now();
    if (widget.enableHaptics &&
        now.difference(_lastTick).inMilliseconds >= 30) {
      _lastTick = now;
      HapticFeedback.selectionClick();
    }
    setState(() {
      _index = next;
      _label = _labelFor(widget.cells[next]);
    });
    widget.onTapCell?.call(widget.cells[next]);
  }

  void _end() {
    if (_index == null) return;
    setState(() => _index = null);
    _clear?.cancel();
    _clear = Timer(HeatmapGrid.labelLinger, () {
      if (mounted) setState(() => _label = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final grid = SizedBox(
      width: _gridWidth,
      height: _gridHeight,
      child: CustomPaint(
        painter: _HeatmapPainter(
          cells: widget.cells,
          columns: _columns,
          cellSize: widget.cellSize,
          gap: widget.gap,
          met: c.gold,
          active: Color.alphaBlend(c.gold.withValues(alpha: 0.35), c.ink600),
          empty: c.ink700,
          outline: c.gold,
          index: _index,
        ),
      ),
    );

    final body =
        widget.inspectable
            ? RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: HeatmapGrid.holdToInspect,
                        debugOwner: this,
                      ),
                      (recognizer) {
                        recognizer.onLongPressStart =
                            (d) => _inspect(d.localPosition);
                        recognizer.onLongPressMoveUpdate =
                            (d) => _inspect(d.localPosition);
                        recognizer.onLongPressEnd = (_) => _end();
                        recognizer.onLongPressCancel = _end;
                      },
                    ),
              },
              child: grid,
            )
            : grid;

    return Semantics(
      label: widget.semanticLabel ?? _summary(),
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.inspectable)
            SizedBox(
              height: 18,
              child:
                  _label == null
                      ? const SizedBox.shrink()
                      : Text(
                        _label!,
                        style: AllInText.mono(12, color: c.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
            ),
          Stack(
            children: [
              ExcludeSemantics(child: body),
              // One semantic child per column; the cells themselves are 11 pt
              // and are never individual nodes (§7.11).
              Positioned.fill(
                child: IgnorePointer(
                  child: Row(
                    children: [
                      for (var column = 0; column < _columns; column++)
                        Semantics(
                          label: _columnLabel(column),
                          child: SizedBox(
                            width:
                                column == _columns - 1
                                    ? widget.cellSize
                                    : widget.cellSize + widget.gap,
                            height: _gridHeight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _columnLabel(int column) {
    final start = column * HeatmapGrid.rows;
    if (start >= widget.cells.length) return 'empty week';
    final end =
        (start + HeatmapGrid.rows).clamp(0, widget.cells.length).toInt();
    final week = widget.cells.sublist(start, end);
    final active = week.where((c) => c.count > 0).length;
    return 'week of ${week.first.key}, $active active days';
  }

  String _summary() =>
      'Practice heatmap, ${HeatmapGrid.activeDays(widget.cells)} active days '
      'in the last ${widget.weeks} weeks';
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.cells,
    required this.columns,
    required this.cellSize,
    required this.gap,
    required this.met,
    required this.active,
    required this.empty,
    required this.outline,
    required this.index,
  });

  final List<HeatmapCell> cells;
  final int columns;
  final double cellSize;
  final double gap;
  final Color met;
  final Color active;
  final Color empty;
  final Color outline;
  final int? index;

  @override
  void paint(Canvas canvas, Size size) {
    final step = cellSize + gap;
    final radius = Radius.circular(cellSize <= 12 ? 2 : 3);
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < HeatmapGrid.rows; row++) {
        final i = column * HeatmapGrid.rows + row;
        final cell = i < cells.length ? cells[i] : null;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(column * step, row * step, cellSize, cellSize),
          radius,
        );
        final color =
            cell == null || cell.count == 0
                ? empty
                : cell.met
                ? met
                : active;
        canvas.drawRRect(rect, Paint()..color = color);
        if (index == i) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.index != index ||
      old.columns != columns ||
      old.cellSize != cellSize ||
      old.met != met ||
      !identical(old.cells, cells);
}
