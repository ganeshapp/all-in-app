/// Route names, paths and deep-link builders for every screen in
/// DESIGN.md §16.1 (names are the §2.2 screen IDs).
///
/// Where one screen is hosted by several branches — P10 (four hosts), P11
/// (five) and S1 (two) — the host is appended to the id, because `go_router`
/// requires route names to be unique. The id itself is always the prefix, so
/// `AllInRoutes.summaryStats` is still "P10".
library;

class AllInRoutes {
  const AllInRoutes._();

  // ---------------------------------------------------------------- branches
  /// H0 · Today (home branch root).
  static const String today = 'H0';
  static const String todayPath = '/home';

  /// P0 · Play lobby (play branch root).
  static const String lobby = 'P0';
  static const String lobbyPath = '/play';

  /// D0 · Drills (drills branch root).
  static const String drills = 'D0';
  static const String drillsPath = '/drills';

  /// S0 · Study (study branch root).
  static const String study = 'S0';
  static const String studyPath = '/study';

  /// T0 · Progress (stats branch root).
  static const String progress = 'T0';
  static const String progressPath = '/stats';

  // ------------------------------------------------------------- home branch
  /// P10 · Session summary, read-only copy in the home branch.
  static const String summaryHome = 'P10-home';

  /// P11 · Replayer under the home branch's session summary.
  static const String replayerHome = 'P11-home';

  // ------------------------------------------------------------- play branch
  /// P10 · Session summary, read-only copy in the play branch.
  static const String summaryPlay = 'P10-play';

  /// P11 · Replayer under the play branch's session summary.
  static const String replayerPlay = 'P11-play';

  // ------------------------------------------------------------ study branch
  /// S1 · Lesson reader as a study-branch push.
  static const String lesson = 'S1';

  /// S3 · Tool screen.
  static const String tool = 'S3';

  /// S4 · Quick reference + glossary.
  static const String quickReference = 'S4';

  // ------------------------------------------------------------ stats branch
  /// T2 · All hands.
  static const String allHands = 'T2';

  /// P11 · Replayer in the stats branch.
  static const String replayerStats = 'P11-stats';

  /// P10 · Session summary, read-only copy in the stats branch.
  static const String summaryStats = 'P10-stats';

  /// P11 · Replayer under the stats branch's session summary.
  static const String replayerStatsSession = 'P11-stats-session';

  /// X0 · Settings (the one canonical path, §16.1).
  static const String settings = 'X0';
  static const String settingsPath = '/stats/settings';

  /// X1 · About.
  static const String about = 'X1';
  static const String aboutPath = '/stats/settings/about';

  // --------------------------------------------------------------- top level
  /// P1 · Table (root-level full-screen modal).
  static const String table = 'P1';
  static const String tablePath = '/table';

  /// P7 · Read range (modal over the table).
  static const String readRange = 'P7';

  /// P11 · Replayer pushed inside the table modal.
  static const String replayerTable = 'P11-table';

  /// P10 · Session summary over the table.
  static const String summaryTable = 'P10-table';
  static const String summaryTablePath = '/table/summary';

  /// P11 · Replayer under the summary that sits over the table.
  static const String replayerSummary = 'P11-summary';

  /// S1 · Lesson reader as a root-level modal ("Done" instead of `‹`).
  static const String lessonModal = 'S1-modal';

  /// D5 · Placement test.
  static const String placement = 'D5';
  static const String placementPath = '/placement';

  /// O0 · Onboarding tour.
  static const String onboarding = 'O0';
  static const String onboardingPath = '/onboarding';

  /// S6 · Range editor (returns the set via `pop(result)`).
  static const String rangeEditor = 'S6';
  static const String rangeEditorPath = '/study/range-editor';

  // ------------------------------------------------------------ path helpers
  /// `/drills?mode=…&set=…` — D0 in a given mode (§2.6).
  static String drillsWith({String? mode, int? set}) {
    final q = <String, String>{
      if (mode != null) 'mode': mode,
      if (set != null) 'set': '$set',
    };
    return q.isEmpty
        ? drillsPath
        : Uri(path: drillsPath, queryParameters: q).toString();
  }

  /// `/study/lesson/:id` — the branch push used by Home, Study and placement.
  static String lessonPath(String id) => '$studyPath/lesson/$id';

  /// `/lesson/:id` — the root-level modal used by drill feedback.
  static String lessonModalPath(String id) => '/lesson/$id';

  /// `/study/tools/:tool`.
  static String toolPath(String tool) => '$studyPath/tools/$tool';

  /// `/study/glossary?term=:termId` — a QUERY, never a fragment (§16.1).
  static String glossaryPath({String? term}) =>
      Uri(
        path: '$studyPath/glossary',
        queryParameters: term == null ? null : {'term': term},
      ).toString();

  /// `/stats/hands?filter=…&tag=…`.
  static String allHandsPath({String? filter, String? tag}) {
    final q = <String, String>{
      if (filter != null) 'filter': filter,
      if (tag != null) 'tag': tag,
    };
    final path = '$progressPath/hands';
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  /// `/stats/hand/:startedAt` — P11 in the Stats branch.
  static String statsHandPath(int startedAt) => '$progressPath/hand/$startedAt';

  /// `/table/hand/:startedAt` — P11 inside the table modal.
  static String tableHandPath(int startedAt) => '$tablePath/hand/$startedAt';

  /// `/table/summary/hand/:startedAt`.
  static String summaryHandPath(int startedAt) =>
      '$summaryTablePath/hand/$startedAt';

  /// `/{branch}/session/:id` — the read-only summary for a given host branch.
  static String sessionPath(String branchPath, String id) =>
      '$branchPath/session/$id';

  /// `/{branch}/session/:id/hand/:startedAt`.
  static String sessionHandPath(String branchPath, String id, int startedAt) =>
      '$branchPath/session/$id/hand/$startedAt';

  /// `/table/read/:seat` — P7 for one seat.
  static String readRangePath(int seat) => '$tablePath/read/$seat';

  /// `/stats/settings?section=data` (§2.6).
  static String settingsSection(String section) =>
      Uri(path: settingsPath, queryParameters: {'section': section}).toString();
}
