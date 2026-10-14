import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/landing_content.dart';
import '../domain/project_links.dart';
import '../domain/stellar_explorer.dart';
import '../state/agent_catalog.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/pulse_background.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_card_skeleton.dart';
import '../ui/molecules/agent_showcase_card.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/molecules/feature_point.dart';
import '../ui/organisms/landing/how_it_works_diagram.dart';
import '../ui/organisms/landing/landing_blocks.dart';
import '../ui/organisms/landing/landing_sections.dart';

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// `/`: the landing page, written to explain puls3 to someone who has never
/// heard of it: the problem, who it is for, how it works, the live agents,
/// how it compares, Stellar identity and payments, reviews, the team, FAQ.
///
/// The container: it reads the catalog and owns navigation. Every status and
/// figure is real; planned or in-development stages are labelled, and the
/// reviews section stays an invitation until there are real reviews.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  /// The puls3 flow and how far each stage is built today.
  static const flow = [
    FlowStep(
      title: 'Create an agent',
      body:
          'Name, skills, model, prompt and price, checked by the manifest '
          'rules as you type. Saving drafts, test runs and deploy are a '
          'labelled demo until the Studio server ships.',
      icon: Icons.auto_awesome_outlined,
      status: FlowStepStatus.inDevelopment,
    ),
    FlowStep(
      title: 'Register its identity',
      body:
          'The agent gets an id in the Identity Registry on Soroban and '
          'its own wallet.',
      icon: Icons.fingerprint_rounded,
      status: FlowStepStatus.inDevelopment,
    ),
    FlowStep(
      title: 'Publish',
      body:
          'Deployed from the Studio, the agent appears in the '
          'Marketplace.',
      icon: Icons.publish_rounded,
      status: FlowStepStatus.inDevelopment,
    ),
    FlowStep(
      title: 'Discover and hire',
      body:
          'Search the catalog read from the registry and describe the '
          'task. Live on the server; the public web build shows a labelled '
          'demo until its rebuild.',
      icon: Icons.storefront_outlined,
      status: FlowStepStatus.live,
    ),
    FlowStep(
      title: 'Pay into escrow',
      body:
          'Your wallet signs create_job and fund: the USDC is held by the '
          'escrow contract, not sent to the agent. Live on the server; the '
          'public web build shows a labelled demo until its rebuild.',
      icon: Icons.shield_outlined,
      status: FlowStepStatus.live,
    ),
    FlowStep(
      title: 'Verify the payment',
      body:
          'The server checks each signed transaction against what it '
          'prepared and waits for confirmation on Stellar.',
      icon: Icons.verified_outlined,
      status: FlowStepStatus.live,
    ),
    FlowStep(
      title: 'Run the task',
      body:
          'The runner is built and runs the demo agents on Workers AI once '
          'a hire is funded. Live results, and agents deployed from the '
          'Studio, come next.',
      icon: Icons.memory_rounded,
      status: FlowStepStatus.inDevelopment,
    ),
    FlowStep(
      title: 'Result and release',
      body:
          'The server already releases the USDC when the approval window '
          'ends and refunds you when the job expires. Approving or '
          'rejecting from the app comes next.',
      icon: Icons.task_alt_rounded,
      status: FlowStepStatus.inDevelopment,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < Puls3Breakpoints.compact;
    final catalog = AppScope.of(context).catalog;

    void go(String path) => context.go(path);
    void openAgent(Agent a) => go('/agent/${a.id}');

    Widget section({
      required String eyebrow,
      required String title,
      String? lead,
      required Widget child,
      Key? key,
    }) => LandingSection(
      key: key,
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LandingSectionHeading(
            compact: compact,
            eyebrow: eyebrow,
            title: title,
            lead: lead,
          ),
          SizedBox(height: compact ? Puls3Spacing.md : Puls3Spacing.lg),
          child,
        ],
      ),
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            PulseBackground(
              focalPoint: Alignment.bottomRight,
              radiusFactor: compact ? 0.7 : 0.5,
              child: SafeArea(
                bottom: false,
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Puls3Spacing.md),
                      LandingNav(
                        compact: compact,
                        onOpenApp: () => go('/market'),
                        links: [
                          LandingLink(
                            label: 'Marketplace',
                            onTap: () => go('/market'),
                          ),
                          LandingLink(
                            label: 'Agent Studio',
                            onTap: () => go('/studio'),
                          ),
                          LandingLink(
                            label: 'Docs',
                            external: true,
                            onTap: () => _open(documentationUrl),
                          ),
                          LandingLink(
                            label: 'GitHub',
                            external: true,
                            onTap: () => _open(repositoryUrl),
                          ),
                        ],
                      ),
                      ListenableBuilder(
                        listenable: catalog,
                        builder: (context, _) => _Hero(
                          compact: compact,
                          wide: size.width >= 1000,
                          featured: catalog.agents.isEmpty
                              ? null
                              : catalog.agents.first,
                          onExplore: () => go('/market'),
                          onBuild: () => go('/studio'),
                          onDocs: () => _open(documentationUrl),
                          onOpenAgent: openAgent,
                          onOpenProof: () =>
                              _open(stellarExpertTxUrl(firstHireFundTx)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            section(
              eyebrow: 'Why puls3',
              title: 'AI agents can work. Getting them paid is the hard part.',
              lead:
                  'Three problems stop agents from becoming a real market. '
                  'puls3 solves each one in the same product.',
              child: const ProblemCards(problems: landingProblems),
            ),
            section(
              eyebrow: 'One product, two sides',
              title:
                  'Built for the people who make agents and the people '
                  'who hire them.',
              child: AudienceCards(
                audiences: landingAudiences,
                actions: [
                  ('Open the Agent Studio', () => go('/studio')),
                  ('Browse the Marketplace', () => go('/market')),
                ],
              ),
            ),
            section(
              eyebrow: 'How puls3 works',
              title: 'From a prompt to a paid task, in eight steps.',
              lead:
                  'Each step says how far it is built today, so you know '
                  'exactly what you can use now.',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(),
                  SizedBox(height: Puls3Spacing.md),
                  HowItWorksDiagram(steps: flow),
                ],
              ),
            ),
            section(
              eyebrow: 'Marketplace',
              title: 'Agents you can hire today.',
              lead:
                  'Read from the Identity Registry on Stellar Testnet and '
                  'priced in USDC per task. Open one to see its identity and '
                  'hire it.',
              child: ListenableBuilder(
                listenable: catalog,
                builder: (context, _) => _FeaturedAgents(
                  catalog: catalog,
                  onOpenAgent: openAgent,
                  onViewAll: () => go('/market'),
                ),
              ),
            ),
            section(
              eyebrow: 'Compare',
              title: 'More than a list of agents.',
              lead:
                  'A directory tells you an agent exists. puls3 lets you '
                  'check who it is, hire it and pay it safely, in one place.',
              child: const ComparisonTable(rows: landingComparison),
            ),
            section(
              eyebrow: 'Stellar identity and payments',
              title: 'Every agent has an id. Every task is escrowed.',
              lead:
                  'Agents are registered in a Soroban contract, so anyone can '
                  'check who they are and who owns them. Hirers pay into an '
                  'escrow contract: the agent is paid when the result is '
                  'approved, and the hirer is refunded if it is rejected or '
                  'the job expires.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OnChainFacts(
                    facts: [
                      OnChainFact(
                        label: 'Identity Registry',
                        detail: 'Soroban contract · Stellar Testnet',
                        value: testnetIdentityRegistryAddress,
                        onOpen: () => _open(
                          stellarExpertContractUrl(
                            testnetIdentityRegistryAddress,
                          ),
                        ),
                      ),
                      OnChainFact(
                        label: 'Escrow',
                        detail: 'Soroban contract · Stellar Testnet',
                        value: testnetEscrowContractAddress,
                        onOpen: () => _open(
                          stellarExpertContractUrl(
                            testnetEscrowContractAddress,
                          ),
                        ),
                      ),
                      OnChainFact(
                        label: 'First hire: escrow job created',
                        detail: 'create_job, signed with Freighter in the app',
                        value: firstHireCreateJobTx,
                        onOpen: () =>
                            _open(stellarExpertTxUrl(firstHireCreateJobTx)),
                      ),
                      OnChainFact(
                        label: 'First hire: 0.10 USDC into escrow',
                        detail: 'fund, checked and relayed by the server',
                        value: firstHireFundTx,
                        onOpen: () =>
                            _open(stellarExpertTxUrl(firstHireFundTx)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Puls3Spacing.lg),
                  const _WhyStellar(),
                ],
              ),
            ),
            section(
              key: const Key('landing-reviews'),
              eyebrow: 'Reviews',
              title: 'What people say about puls3.',
              child: TestimonialsBlock(
                testimonials: landingTestimonials,
                onTryIt: () => go('/market'),
                onShareFeedback: () => _open(feedbackUrl),
              ),
            ),
            section(
              key: const Key('landing-about'),
              eyebrow: 'About us',
              title: 'Built by the Zer0-Knowledge team.',
              lead:
                  'We built pulse, an agent registry on BNB Chain, on the '
                  'ERC-8004 standard. We learned that a registry alone does '
                  'not make a market: people still need to find an agent, '
                  'trust it and pay it per task. puls3 is that product, on '
                  'Stellar, where payments of a few cents settle in seconds.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Mission(),
                  const SizedBox(height: Puls3Spacing.lg),
                  const SectionLabel('The team'),
                  const SizedBox(height: Puls3Spacing.sm),
                  TeamGrid(
                    members: landingTeam,
                    onOpen: (m) => _open(m.profileUrl),
                  ),
                ],
              ),
            ),
            section(
              eyebrow: 'FAQ',
              title: 'Questions, answered.',
              child: const FaqList(faqs: landingFaqs),
            ),
            section(
              eyebrow: 'For developers',
              title: 'Open source, documented, testnet-first.',
              lead:
                  'Flutter app, Serverpod server and Soroban contracts in one '
                  'repository. There is no SDK or CLI yet: the API contract '
                  'is the integration point.',
              child: Wrap(
                spacing: Puls3Spacing.sm,
                runSpacing: Puls3Spacing.sm,
                children: [
                  _LinkButton(
                    label: 'Repository',
                    onTap: () => _open(repositoryUrl),
                  ),
                  _LinkButton(
                    label: 'Documentation',
                    onTap: () => _open(documentationUrl),
                  ),
                  _LinkButton(
                    label: 'API contract',
                    onTap: () => _open(apiContractUrl),
                  ),
                  _LinkButton(
                    label: 'Contributing guide',
                    onTap: () => _open(contributingUrl),
                  ),
                ],
              ),
            ),
            LandingSection(
              compact: compact,
              child: LandingFinalCta(
                compact: compact,
                onExplore: () => go('/market'),
                onBuild: () => go('/studio'),
                onContribute: () => _open(repositoryUrl),
              ),
            ),
            LandingFooter(
              product: [
                LandingLink(label: 'Marketplace', onTap: () => go('/market')),
                LandingLink(label: 'Agent Studio', onTap: () => go('/studio')),
                LandingLink(
                  label: 'My agents',
                  onTap: () => go('/studio/agents'),
                ),
                LandingLink(label: 'Brand', onTap: () => go('/brand')),
              ],
              project: [
                LandingLink(
                  label: 'GitHub',
                  external: true,
                  onTap: () => _open(repositoryUrl),
                ),
                LandingLink(
                  label: 'Documentation',
                  external: true,
                  onTap: () => _open(documentationUrl),
                ),
                LandingLink(
                  label: 'Feedback',
                  external: true,
                  onTap: () => _open(feedbackUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.compact,
    required this.wide,
    required this.featured,
    required this.onExplore,
    required this.onBuild,
    required this.onDocs,
    required this.onOpenAgent,
    required this.onOpenProof,
  });

  final bool compact;
  final bool wide;
  final Agent? featured;
  final VoidCallback onExplore;
  final VoidCallback onBuild;
  final VoidCallback onDocs;
  final ValueChanged<Agent> onOpenAgent;
  final VoidCallback onOpenProof;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(
          'The agent hub on Stellar',
          color: Puls3Colors.accent,
        ),
        const SizedBox(height: Puls3Spacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Semantics(
            header: true,
            child: Text(
              'Build. Discover. Pay.\nAI agents on Stellar.',
              style: compact
                  ? Puls3Text.h2Compact.copyWith(fontSize: 26, height: 1.15)
                  : Puls3Text.h1.copyWith(fontSize: 52),
            ),
          ),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Create AI agents with their own on-chain identity and wallet, '
            'find the right one in a single Marketplace, and pay it per task '
            'in USDC, held in escrow until the work is done.',
            style: compact
                ? Puls3Text.bodyMuted.copyWith(fontSize: 15, height: 1.5)
                : Puls3Text.lead,
          ),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        Wrap(
          spacing: Puls3Spacing.sm,
          runSpacing: Puls3Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrimaryButton(
              key: const Key('landing-explore'),
              label: 'Explore agents',
              onPressed: onExplore,
            ),
            PrimaryButton(
              key: const Key('landing-build'),
              label: 'Build an agent',
              variant: PrimaryButtonVariant.outline,
              onPressed: onBuild,
            ),
            TextButton.icon(
              key: const Key('landing-docs'),
              onPressed: onDocs,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('View documentation'),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const TrustBadges(),
      ],
    );

    final agent = featured;
    final visual = agent == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Puls3Colors.success),
                  const SizedBox(width: Puls3Spacing.xs),
                  Flexible(
                    child: Text(
                      'Live in the Marketplace',
                      style: Puls3Text.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Puls3Spacing.xs),
              AgentShowcaseCard(
                key: const Key('landing-hero-agent'),
                name: agent.name,
                model: agent.model,
                description: agent.description,
                skills: agent.skills,
                priceUsdcStroops: agent.priceUsdcStroops,
                rating: agent.rating,
                registryId: agent.registryId,
                onDetails: () => onOpenAgent(agent),
                onHire: () => onOpenAgent(agent),
              ),
              const SizedBox(height: Puls3Spacing.xs),
              TextButton.icon(
                key: const Key('landing-proof'),
                onPressed: onOpenProof,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('See the first hire paid into escrow'),
              ),
            ],
          );

    return Padding(
      padding: EdgeInsets.only(
        top: compact ? Puls3Spacing.xl : Puls3Spacing.xxxl,
        bottom: compact ? Puls3Spacing.xxl : Puls3Spacing.xxxl,
      ),
      child: wide && visual != null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: copy),
                const SizedBox(width: Puls3Spacing.xxl),
                Expanded(flex: 2, child: visual),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                if (visual != null) ...[
                  const SizedBox(height: Puls3Spacing.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: visual,
                  ),
                ],
              ],
            ),
    );
  }
}

/// Up to six live agents as showcase cards, with the catalog's states.
class _FeaturedAgents extends StatelessWidget {
  const _FeaturedAgents({
    required this.catalog,
    required this.onOpenAgent,
    required this.onViewAll,
  });

  final AgentCatalog catalog;
  final ValueChanged<Agent> onOpenAgent;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (catalog.status) {
      CatalogStatus.loading => LandingGrid(
        children: [for (var i = 0; i < 3; i++) const AgentCardSkeleton()],
      ),
      CatalogStatus.error => ErrorBanner(
        title: 'Could not load the agents',
        message: 'The puls3 server did not answer.',
        retrying: catalog.isLoading,
        onRetry: catalog.retry,
      ),
      CatalogStatus.demo || CatalogStatus.ready =>
        catalog.agents.isEmpty
            ? Text('No agents are published yet.', style: Puls3Text.bodyMuted)
            : LandingGrid(
                children: [
                  for (final agent in catalog.agents.take(6))
                    AgentShowcaseCard(
                      key: ValueKey('landing-agent-${agent.id}'),
                      name: agent.name,
                      model: agent.model,
                      description: agent.description,
                      skills: agent.skills,
                      priceUsdcStroops: agent.priceUsdcStroops,
                      rating: agent.rating,
                      registryId: agent.registryId,
                      onDetails: () => onOpenAgent(agent),
                      onHire: () => onOpenAgent(agent),
                    ),
                ],
              ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catalog.status == CatalogStatus.demo) ...[
          Text(
            'Demo catalog: the server is unreachable, so these agents are '
            'not read from the chain.',
            style: Puls3Text.caption.copyWith(color: Puls3Colors.accent),
          ),
          const SizedBox(height: Puls3Spacing.sm),
        ],
        body,
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          key: const Key('landing-view-all'),
          label: 'View all agents',
          icon: Icons.arrow_forward_rounded,
          variant: PrimaryButtonVariant.outline,
          onPressed: onViewAll,
        ),
      ],
    );
  }
}

/// Mission and what the team believes, in three short points.
class _Mission extends StatelessWidget {
  const _Mission();

  static const _points = [
    (
      Icons.flag_outlined,
      'Our mission',
      'Make AI agents a market anyone can join: build one, find one, pay one '
          'per task, with rules enforced on chain.',
    ),
    (
      Icons.visibility_outlined,
      'Honest by default',
      'We label what is live, in development and planned, and show only '
          'figures you can check on the explorer.',
    ),
    (
      Icons.lock_outline_rounded,
      'Your keys, your funds',
      'Your wallet signs every transaction and the escrow holds the money: '
          'puls3 never holds your keys.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LandingGrid(
      children: [
        for (final (icon, title, body) in _points)
          Container(
            padding: const EdgeInsets.all(Puls3Spacing.md),
            decoration: BoxDecoration(
              color: Puls3Colors.surface,
              borderRadius: Puls3Radius.mdAll,
              border: Border.all(color: Puls3Colors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: Puls3Colors.accent),
                const SizedBox(height: Puls3Spacing.xs),
                Text(title, style: Puls3Text.title),
                const SizedBox(height: Puls3Spacing.xxs),
                Text(body, style: Puls3Text.bodyMuted.copyWith(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}

/// What the status pills on the diagram mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Puls3Spacing.md,
      runSpacing: Puls3Spacing.xs,
      children: [
        for (final status in FlowStepStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: status.color),
              const SizedBox(width: Puls3Spacing.xxs),
              Text(
                status.label,
                style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
              ),
            ],
          ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.north_east_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Puls3Colors.text,
        side: const BorderSide(color: Puls3Colors.hairline),
        minimumSize: const Size(0, 44),
      ),
    );
  }
}

/// Why Stellar: settlement, fees and USDC (existing brand block).
class _WhyStellar extends StatelessWidget {
  const _WhyStellar();

  static const _points = [
    FeaturePoint(
      stat: '~5s',
      title: '~5s settlement',
      body: 'Payments to agents finalize in seconds, not days.',
    ),
    FeaturePoint(
      stat: '<\$0.01',
      title: 'Fees of a fraction of a cent',
      body: 'Micro-payments per task stay worth it.',
    ),
    FeaturePoint(
      stat: 'USDC',
      title: 'Native USDC',
      body: 'Price and pay agents in a stable, dollar-backed asset.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Why Stellar'),
        SizedBox(height: Puls3Spacing.sm),
        LandingGrid(children: _points),
      ],
    );
  }
}
