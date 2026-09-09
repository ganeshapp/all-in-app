/// X1 · About (DESIGN.md §9) — pushed from Settings at
/// `/stats/settings/about`.
///
/// The desktop page, adapted for a phone: the hero, the "How to use it"
/// cards, the honesty notes ("play-money trainer"; post-flop coaching is
/// pot-odds + Monte-Carlo, not a solver), the grading explanation, the mobile
/// roadmap, the credits and the footer. Copy lives in `content/about_copy.dart`
/// and is verbatim except for the edits §9 permits.
///
/// The desktop's passive GitHub release check is dropped (store channel) and
/// replaced by a "Rate All-In" row; external links open in the system browser
/// (`url_launcher`, external application mode).
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/app/routes.dart';
import 'package:allin/features/settings/content/about_copy.dart';
import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/theme/typography.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// The store listing behind "Rate All-In" (§9) — one of the two thin
  /// platform adapters this screen is allowed (§16.6).
  static String storeUrl(TargetPlatform platform) =>
      platform == TargetPlatform.iOS
          ? AboutCopy.appStoreUrl
          : AboutCopy.playStoreUrl;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final ok = await ref.read(urlOpenerProvider)(Uri.parse(url));
    if (ok || !context.mounted) return;
    AllInToast.show(
      context,
      AboutCopy.linkFailed,
      reducedMotion: ref.read(reducedMotionProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final version = ref.watch(appVersionProvider);

    return AllInScaffold(
      title: 'About',
      leading: _BackChevron(onTap: () => _pop(context)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AllInSpace.lg,
          AllInSpace.sm,
          AllInSpace.lg,
          AllInSpace.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Hero(
            version: version.maybeWhen(
              data: (v) => v,
              orElse: () => AppVersion.unknown,
            ),
          ),
          const SizedBox(height: AllInSpace.lg),

          // "Rate All-In" replaces the desktop's two download tiles (§15.5).
          AllInCard(
            variant: AllInCardVariant.gold,
            onTap:
                () => _open(context, ref, storeUrl(Theme.of(context).platform)),
            child: Row(
              children: [
                const _IconTile(
                  icon: Icons.star_rounded,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: AllInSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AboutCopy.rateTitle,
                        style: AllInText.display(16, color: c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AboutCopy.rateSubtitle,
                        style: AllInText.body(13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 18, color: c.gold),
              ],
            ),
          ),

          _Heading(AboutCopy.howToUseHeading),
          for (var i = 0; i < AboutCopy.modes.length; i++) ...[
            if (i > 0) const SizedBox(height: AllInSpace.md),
            _ModeCard(entry: AboutCopy.modes[i], icon: _kModeIcons[i]),
          ],

          _Heading(AboutCopy.goodToKnowHeading),
          AllInCard(
            child: Column(
              children: [
                for (var i = 0; i < AboutCopy.goodToKnow.length; i++) ...[
                  if (i > 0) const SizedBox(height: AllInSpace.md),
                  _Bullet(bullet: AboutCopy.goodToKnow[i]),
                ],
              ],
            ),
          ),

          _Heading(AboutCopy.gradingHeading),
          AllInCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AboutCopy.gradingIntro,
                  style: AllInText.body(14, color: c.textMuted),
                ),
                const SizedBox(height: AllInSpace.md),
                for (var i = 0; i < AboutCopy.grading.length; i++) ...[
                  if (i > 0) const SizedBox(height: AllInSpace.md),
                  _Bullet(bullet: AboutCopy.grading[i]),
                ],
              ],
            ),
          ),

          _Heading(AboutCopy.roadmapHeading),
          AllInCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AboutCopy.roadmapIntro,
                  style: AllInText.body(14, color: c.textMuted),
                ),
                const SizedBox(height: AllInSpace.md),
                for (final row in AboutCopy.roadmap)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AllInSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: c.gold,
                          ),
                        ),
                        const SizedBox(width: AllInSpace.sm),
                        Expanded(
                          child: Text(
                            row,
                            style: AllInText.body(14, color: c.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AllInSpace.xs),
                Text(
                  AboutCopy.roadmapFootnote,
                  style: AllInText.body(12.5, color: c.textFaint),
                ),
              ],
            ),
          ),

          _Heading(AboutCopy.builtByHeading),
          AllInCard(
            child: Column(
              children: [
                Text(
                  AboutCopy.author,
                  style: AllInText.display(24, color: c.goldLight),
                ),
                const SizedBox(height: AllInSpace.sm),
                Semantics(
                  button: true,
                  label: '${AboutCopy.authorLabel}, opens in your browser',
                  child: InkWell(
                    onTap: () => _open(context, ref, AboutCopy.authorUrl),
                    borderRadius: BorderRadius.circular(AllInRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AllInSpace.sm,
                        vertical: AllInSpace.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AboutCopy.authorLabel,
                            style: AllInText.body(
                              14,
                              weight: FontWeight.w600,
                              color: c.gold,
                            ),
                          ),
                          const SizedBox(width: AllInSpace.xs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: c.gold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  AboutCopy.builtByBody,
                  textAlign: TextAlign.center,
                  style: AllInText.body(13, color: c.textFaint),
                ),
              ],
            ),
          ),

          const SizedBox(height: AllInSpace.xl),
          Text(
            AboutCopy.footer,
            textAlign: TextAlign.center,
            style: AllInText.body(11.5, color: c.textFaint),
          ),
        ],
      ),
    );
  }

  static void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AllInRoutes.settingsPath);
    }
  }
}

const List<IconData> _kModeIcons = [
  Icons.style, // Play
  Icons.track_changes, // Drills
  Icons.menu_book, // Study
  Icons.insights, // Stats
];

class _Hero extends StatelessWidget {
  const _Hero({required this.version});

  final AppVersion version;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AllInSpace.lg,
        vertical: AllInSpace.xl,
      ),
      child: Column(
        children: [
          const _LogoMark(size: 64),
          const SizedBox(height: AllInSpace.md),
          Text(
            AboutCopy.appName,
            textAlign: TextAlign.center,
            style: AllInText.display(24, color: c.text),
          ),
          const SizedBox(height: AllInSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              AboutCopy.description,
              textAlign: TextAlign.center,
              style: AllInText.body(14, color: c.textMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: AllInSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AllInSpace.md,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: c.ink700,
              borderRadius: BorderRadius.circular(AllInRadius.pill),
            ),
            child: Text(
              version.label.toUpperCase(),
              style: AllInText.mono(11, color: c.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

/// The brand mark: the felt with a gold "A". The full logo is an SVG asset the
/// app cannot render without a vector package, so About draws the mark from
/// tokens instead of shipping a second dependency for one image.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AllInColors.feltLight, AllInColors.feltDark],
        ),
        borderRadius: BorderRadius.circular(AllInRadius.xl),
        border: Border.all(
          color: context.colors.gold.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Text(
        'A',
        style: AllInText.display(size * 0.5, color: context.colors.goldLight),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AllInSpace.xs,
      AllInSpace.xl,
      AllInSpace.xs,
      AllInSpace.md,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: AllInText.display(19, color: context.colors.text),
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.entry, required this.icon});

  final AboutEntry entry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AllInCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(icon: icon, size: 28, iconSize: 15),
              const SizedBox(width: AllInSpace.sm),
              Text(entry.title, style: AllInText.display(16, color: c.text)),
            ],
          ),
          const SizedBox(height: AllInSpace.sm),
          Text(
            entry.body,
            style: AllInText.body(14, color: c.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final gold = context.colors.gold;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AllInRadius.md),
      ),
      child: Icon(icon, size: iconSize, color: gold),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.bullet});

  final AboutBullet bullet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = bullet.good ? c.good : c.info;
    final body = AllInText.body(14, color: c.textMuted, height: 1.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            bullet.good ? Icons.check_rounded : Icons.info_outline,
            size: 15,
            color: tone,
          ),
        ),
        const SizedBox(width: AllInSpace.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (bullet.lead.isNotEmpty)
                  TextSpan(
                    text: bullet.lead,
                    style: body.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                TextSpan(text: bullet.body),
              ],
            ),
            style: body,
          ),
        ),
      ],
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.chevron_left_rounded,
          size: 28,
          color: context.colors.text,
        ),
      ),
    ),
  );
}
