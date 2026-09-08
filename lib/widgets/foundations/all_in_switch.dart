/// `AllInSwitch` — the adaptive switch (Cupertino on iOS, M3 elsewhere), gold
/// when on (DESIGN.md §10.1). Sits in a 44 pt band (§12) and clicks on toggle
/// (§11: light haptic on toggles).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

class AllInSwitch extends StatelessWidget {
  const AllInSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.enableHaptics = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Switch.adaptive(
            value: value,
            activeColor: c.gold,
            activeTrackColor: c.gold,
            inactiveTrackColor: c.ink600,
            onChanged:
                onChanged == null
                    ? null
                    : (v) {
                      if (enableHaptics) HapticFeedback.selectionClick();
                      onChanged!(v);
                    },
          ),
        ),
      ),
    );
  }
}
