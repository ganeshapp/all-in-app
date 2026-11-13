/// Small decaying public evidence table. No cards or private bot parameters.
class OpponentMemory {
  OpponentMemory([Map<String, List<double>>? values]) : values = values ?? {};

  /// key -> [positive observations, opportunities]. Counts can be fractional.
  final Map<String, List<double>> values;

  void observe(String key, double value) {
    final counts = values.putIfAbsent(key, () => [0, 0]);
    counts[0] += value.clamp(0.0, 1.0);
    counts[1] += 1;
  }

  double estimate(String key, double prior, {double strength = 10}) {
    final counts = values[key] ?? const [0.0, 0.0];
    return (counts[0] + prior * strength) / (counts[1] + strength);
  }

  /// Context evidence from OTHER opponents supplies the prior for this pair.
  /// Subtract the pair first so an observation is never counted twice.
  double against(String context, int seat, double prior) {
    final all = values[context] ?? const [0.0, 0.0];
    final pair = values['$context@$seat'] ?? const [0.0, 0.0];
    final pooled = (all[0] - pair[0] + prior * 16) / (all[1] - pair[1] + 16);
    return (pair[0] + pooled * 8) / (pair[1] + 8);
  }

  void decay(double factor) {
    for (final c in values.values) {
      c[0] *= factor;
      c[1] *= factor;
    }
    values.removeWhere((_, c) => c[1] < .01);
  }

  OpponentMemory clone() =>
      OpponentMemory({for (final e in values.entries) e.key: List.of(e.value)});
  Map<String, Object?> toJson() => {
    for (final e in values.entries) e.key: List.of(e.value),
  };
  static OpponentMemory fromJson(Map<String, Object?> json) => OpponentMemory({
    for (final e in json.entries)
      if (e.value is List && (e.value as List).length == 2)
        e.key: (e.value as List).map((v) => (v as num).toDouble()).toList(),
  });
}
