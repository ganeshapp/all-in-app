/// The shared component library (DESIGN.md §10). Every feature imports this
/// barrel; no feature re-implements a card, a pill or a matrix, and no
/// `features/*/widgets/` file may export a §10 name (§16.3).
///
/// ADD ONE ALPHABETISED EXPORT LINE PER WIDGET FILE, grouped by §10 section.
/// Keep the lines sorted so two agents editing this file rarely collide.
library;

// §10.1 Foundations — lib/widgets/foundations/
export 'foundations/all_in_button.dart';
export 'foundations/all_in_card.dart';
export 'foundations/all_in_dialog.dart';
export 'foundations/all_in_scaffold.dart';
export 'foundations/all_in_segmented.dart';
export 'foundations/all_in_sheet.dart';
export 'foundations/all_in_slider.dart';
export 'foundations/all_in_switch.dart';
export 'foundations/all_in_toast.dart';
export 'foundations/disclosure_row.dart';
export 'foundations/eyebrow.dart';
export 'foundations/progress_bar_thin.dart';
export 'foundations/stat_tile.dart';
export 'foundations/term_popover.dart';
export 'foundations/term_text.dart';
export 'foundations/text_fit.dart';

// §10.1 Chart primitives — lib/widgets/charts/
export 'charts/diverging_bar.dart';
export 'charts/heatmap_grid.dart';
export 'charts/line_chart.dart';
export 'charts/mini_bars.dart';
export 'charts/spark_line.dart';

// §10.2 Navigation & shell — lib/widgets/shell/
export 'shell/coach_card.dart';
export 'shell/goal_card.dart';
export 'shell/plan_card.dart';
// `SessionPill` and the tab-bar chrome ship inside app/shell/tab_scaffold.dart.

// §10.3 Table & cards — lib/widgets/table/
export 'table/action_row.dart';
export 'table/bet_pill.dart';
export 'table/board_row.dart';
export 'table/chip_stack.dart';
export 'table/coach_badge.dart';
export 'table/coach_chip.dart';
export 'table/felt_canvas.dart';
export 'table/hero_hand.dart';
export 'table/hero_strip.dart';
export 'table/playing_card_view.dart';
export 'table/pot_pill.dart';
export 'table/results_card.dart';
export 'table/seat_plate.dart';
export 'table/sizing_rail.dart';
export 'table/ticker.dart';
export 'table/turn_ring.dart';

// §10.4 Range — lib/widgets/range/
export 'range/combo_counter.dart';
export 'range/range_legend.dart';
export 'range/range_matrix.dart';
export 'range/range_matrix_loupe.dart';
export 'range/range_preset_row.dart';

// §10.5 Coach — lib/widgets/coach/
export 'coach/coach_note_view.dart';
export 'coach/coach_notes_list.dart';
export 'coach/equity_bar.dart';
export 'coach/explainer_sheet.dart';
export 'coach/verdict_badge.dart';

// §10.6 Drills — lib/widgets/drills/
export 'drills/answer_row.dart';
export 'drills/drill_table.dart';
export 'drills/feedback_panel.dart';
export 'drills/frame_scrubber.dart';
export 'drills/icm_banner.dart';
export 'drills/mode_chips.dart';
export 'drills/stacks_strip.dart';
export 'drills/stats_strip.dart';

// §10.7 Study — lib/widgets/study/
