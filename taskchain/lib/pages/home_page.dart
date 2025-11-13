import 'package:flutter/material.dart';
import '../widgets/stat_tile.dart';
import '../widgets/chain_card_with_badge.dart';
import 'settings_page.dart';
import 'chain_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // Gradient header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF7B61FF), const Color(0xFFFF6EC7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Welcome back",
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined),
                      color: Colors.white,
                      iconSize: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Keep those chains alive!",
                  style: text.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department,
                        value: "42",
                        label: "Total Days",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.group,
                        value: "9",
                        label: "Friends Active",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.show_chart,
                        value: "78%",
                        label: "Avg Progress",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Your Chains header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                Text(
                  "Your Chains",
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock_open),
                  label: const Text("3 Active"),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),

               // Chain cards
               SliverList.list(
                 children: [
                   ChainCardWithBadge(
                     chainId: "chain_1",
                     progress: .85,
                     title: "Daily Reading",
                     days: "12 days",
                     members: "4 members",
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => const ChainDetailPage(
                             chainId: "chain_1",
                             chainTitle: "Daily Reading",
                             members: "4 members",
                             progress: .85,
                           ),
                         ),
                       );
                     },
                   ),
                   ChainCardWithBadge(
                     chainId: "chain_2",
                     progress: .60,
                     title: "Morning Workout",
                     days: "7 days",
                     members: "3 members",
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => const ChainDetailPage(
                             chainId: "chain_2",
                             chainTitle: "Morning Workout",
                             members: "3 members",
                             progress: .60,
                           ),
                         ),
                       );
                     },
                   ),
                   ChainCardWithBadge(
                     chainId: "chain_3",
                     progress: .40,
                     title: "Learn Spanish",
                     days: "5 days",
                     members: "2 members",
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => const ChainDetailPage(
                             chainId: "chain_3",
                             chainTitle: "Learn Spanish",
                             members: "2 members",
                             progress: .40,
                           ),
                         ),
                       );
                     },
                   ),
            const SizedBox(height: 8),
          ],
        ),

        // Recent Achievements header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              "Recent Achievements",
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),

        // Achievements row
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: const [
                _Achieve(
                  icon: Icons.emoji_events,
                  title: "Streak x10",
                  subtitle: "Nice consistency!",
                ),
                _Achieve(
                  icon: Icons.business_rounded,
                  title: "Goal Hit",
                  subtitle: "3 goals this week",
                ),
                _Achieve(
                  icon: Icons.shield_moon,
                  title: "Night Owl",
                  subtitle: "Tasks after 10pm",
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Achieve extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Achieve({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const Spacer(),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    );
  }
}
