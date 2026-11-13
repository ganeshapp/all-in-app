import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/replay_equity.dart';
import '../../../services/equity_service.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../providers/replay_model.dart';
import '../stats_copy.dart';
import 'replay_felt.dart';

final replayEquityRunnerProvider = Provider((ref) => runReplayEquity);

/// One simulation at a time. Scrubbing replaces the pending position; old
/// results never flash on a newer board. The bounded cache dies with the route.
class ReplayBroadcast extends ConsumerStatefulWidget {
  const ReplayBroadcast({
    super.key,
    required this.model,
    required this.index,
    required this.fourColorDeck,
    required this.reducedMotion,
    required this.onNext,
    required this.onPrevious,
  });
  final ReplayModel model;
  final int index;
  final bool fourColorDeck;
  final bool reducedMotion;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  ConsumerState<ReplayBroadcast> createState() => _ReplayBroadcastState();
}

class _ReplayBroadcastState extends ConsumerState<ReplayBroadcast> {
  bool _enabled = true;
  bool _running = false;
  final _cache = <String, ReplayEquity>{};
  late ReplayEquityRequest _request;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant ReplayBroadcast oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    final frame = widget.model.frameAt(widget.index);
    _request = ReplayEquityRequest(
      holes: widget.model.hand.holes,
      activeSeats: [
        for (final s in widget.model.seats)
          if (!frame.folded.contains(s.seat)) s.seat,
      ],
      board: frame.board,
    );
    _load();
  }

  Future<void> _load() async {
    if (_running || !_enabled || _cache.containsKey(_request.key)) return;
    final request = _request;
    final runner = ref.read(replayEquityRunnerProvider);
    _running = true;
    ReplayEquity result;
    try {
      result = await runner(request);
    } catch (_) {
      result = const ReplayEquity(null);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      if (_cache.length >= 40) _cache.remove(_cache.keys.first);
      _cache[request.key] = result;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _cache[_request.key];
    final status =
        !_enabled
            ? StatsCopy.equityHidden
            : result == null
            ? StatsCopy.equityCalculating
            : result.shares == null
            ? StatsCopy.equityUnknown
            : result.exact
            ? StatsCopy.equityExact
            : StatsCopy.equityEstimated;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 6),
            child: LayoutBuilder(
              builder:
                  (context, constraints) => ReplayFelt(
                    model: widget.model,
                    frameIndex: widget.index,
                    height: constraints.maxHeight.clamp(180.0, 360.0),
                    fourColorDeck: widget.fourColorDeck,
                    reducedMotion: widget.reducedMotion,
                    onNext: widget.onNext,
                    onPrevious: widget.onPrevious,
                    broadcast: _enabled,
                    equities: result?.shares,
                  ),
            ),
          ),
        ),
        Row(
          children: [
            Semantics(
              label: StatsCopy.equityToggle,
              child: Switch.adaptive(
                value: _enabled,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  _load();
                },
              ),
            ),
            Expanded(
              child: Text(
                status,
                style: AllInText.body(12, color: context.colors.textMuted),
              ),
            ),
            IconButton(
              tooltip: StatsCopy.equityHelpTitle,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text(StatsCopy.equityHelpTitle),
                          content: const SingleChildScrollView(
                            child: Text(StatsCopy.equityHelp),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
