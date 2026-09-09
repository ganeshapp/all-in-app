/// P8's seam, kept at its original import path.
///
/// The overlay itself (the card, the reveal rows, the read link, the P9
/// overflow and port §18's `revealNote`) lives in `results_overlay.dart`;
/// everything `TableScreen` imported from here is re-exported, so no call site
/// had to move.
library;

export 'results_overlay.dart'
    show
        HandOverContext,
        HandOverOverlayBuilder,
        ResultsCopy,
        ResultsOverlay,
        buildRevealRows,
        defaultHandOverOverlay,
        foldPhrase,
        kInlineRevealCap,
        resultsSummary,
        revealNote,
        tableOverlayBuilderProvider;
