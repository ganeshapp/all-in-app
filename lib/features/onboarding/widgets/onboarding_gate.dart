/// The §8 first-run gate: "First launch mounts **O0** as a full-screen modal
/// over the tab scaffold."
///
/// Wrap the app's routed child once, at the root:
///
/// ```dart
/// // lib/app/app.dart, inside MaterialApp.router's builder
/// return OnboardingGate(router: router, child: content);
/// ```
///
/// The router is passed in rather than read from an `InheritedGoRouter`,
/// because this widget is mounted *above* the routed subtree where that
/// inherited widget lives — and rather than from `routerProvider`, because
/// `app/router.dart` imports every feature and this one must not.
///
/// It reads `allin.onboarded.v1` once, on its first frame, and pushes
/// `/onboarding` when the tour has not been seen. It deliberately does **not**
/// react to later changes of the flag: Settings → "Run again" clears the flag
/// and pushes the route itself (§9), and a gate that also reacted would push
/// O0 twice. Storage that throws reports "seen" (`OnboardingStore`), so a
/// broken preferences file can never trap a user in the tour.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/features/onboarding/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.router, required this.child});

  /// The app's router — the same instance `MaterialApp.router` was given.
  final GoRouter router;

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePresent());
  }

  void _maybePresent() {
    if (!mounted) return;
    if (ref.read(onboardingSeenProvider)) return;
    widget.router.push(AllInRoutes.onboardingPath);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
