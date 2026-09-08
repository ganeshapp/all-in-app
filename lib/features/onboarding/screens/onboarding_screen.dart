/// O0 · Onboarding tour → placement intro (DESIGN.md §8) — a full-screen
/// modal at `/onboarding` over everything else.
library;

import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AllInScaffold(
      title: 'Welcome',
      body: Center(
        child: Text(
          'Coming in Onboarding.',
          style: AllInText.body(15, color: context.colors.textMuted),
        ),
      ),
    );
  }
}
