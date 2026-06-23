import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../providers/auth_provider.dart';
import 'social_screen.dart';
import 'deck_list_screen.dart';
import 'flashcard_list_screen.dart';
import 'analytics_screen.dart';
import '../widgets/chat_action_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final deckProvider = context.watch<DeckProvider>();
    final authProvider = context.watch<AuthProvider>();
    final decks = deckProvider.decks;
    final streakDays = authProvider.dailyCheckInStreak;
    final dailyTarget = deckProvider.dailyTarget;
    final dailyCompleted = deckProvider.dailyCompleted;

    final progress = dailyTarget > 0
        ? (dailyCompleted / dailyTarget).clamp(0.0, 1.0)
        : 0.0;

    final dailyDescription = dailyTarget > 0
        ? dailyCompleted >= dailyTarget
            ? 'You already completed your daily challenge. Great work!'
            : 'Complete $dailyTarget cards today and keep your learning flow alive. Small daily wins become lasting habits.'
        : 'Add flashcards to unlock your personalized daily challenge.';

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : const Color(0xFFF5F0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, authProvider, theme),
              const SizedBox(height: 22),
              _DailyChallengeCard(
                description: dailyDescription,
                streakDays: streakDays,
                dailyCompleted: dailyCompleted,
                dailyTarget: dailyTarget,
                progress: progress,
                theme: theme,
              ),
              const SizedBox(height: 28),
              _buildDecksSection(context, decks, theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider authProvider,
    ThemeData theme,
  ) {
    final name = authProvider.user?.name ?? 'Learner';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,\n$name 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your study dashboard is ready.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ActionIconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
          ),
          backgroundColor: theme.colorScheme.secondaryContainer,
          icon: Icon(
            Icons.bar_chart_rounded,
            color: theme.colorScheme.onSecondaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        ActionIconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocialScreen()),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
          icon: Icon(
            Icons.message_rounded,
            color: theme.colorScheme.onPrimaryContainer,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildDecksSection(
    BuildContext context,
    List decks,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Decks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeckListScreen()),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all →'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (decks.isEmpty)
          _EmptyDecksCard(theme: theme)
        else
          ...decks.take(3).map(
                (deck) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeckCard(deck: deck, theme: theme),
                ),
              ),
      ],
    );
  }
}

// ─── Daily Challenge Card ────────────────────────────────────────────────────

class _DailyChallengeCard extends StatelessWidget {
  final String description;
  final int streakDays;
  final int dailyCompleted;
  final int dailyTarget;
  final double progress;
  final ThemeData theme;

  const _DailyChallengeCard({
    required this.description,
    required this.streakDays,
    required this.dailyCompleted,
    required this.dailyTarget,
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.indigo.shade900, 0.6)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Daily Challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.bolt_rounded, color: Colors.white70, size: 24),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Build a streak with consistent practice.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          if (dailyTarget > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$dailyCompleted / $dailyTarget',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBadge(label: 'STREAK', value: '$streakDays days 🔥'),
              const SizedBox(width: 10),
              _StatBadge(
                label: 'TODAY',
                value: dailyTarget > 0
                    ? '$dailyCompleted / $dailyTarget'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Deck Card ───────────────────────────────────────────────────────────────

class _DeckCard extends StatelessWidget {
  final dynamic deck;
  final ThemeData theme;

  const _DeckCard({required this.deck, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FlashcardListScreen(deck: deck)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.style_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    deck.description.isEmpty
                        ? 'Tap to review the deck'
                        : deck.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FutureBuilder<int>(
              future: context.read<DeckProvider>().getDueCount(deck.id),
              builder: (context, snapshot) {
                final dueCount = snapshot.data ?? 0;
                if (dueCount == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark 
                        ? const Color(0xFF451A1A) 
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark 
                          ? const Color(0xFFB91C1C) 
                          : Colors.red[200]!,
                    ),
                  ),
                  child: Text(
                    '$dueCount due',
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark 
                          ? Colors.red[300] 
                          : Colors.red[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyDecksCard extends StatelessWidget {
  final ThemeData theme;

  const _EmptyDecksCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.style_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No decks yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create one from the deck tab to start your study flow.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}