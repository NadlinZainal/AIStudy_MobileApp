import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../providers/deck_provider.dart';
import '../providers/auth_provider.dart';
import '../models/deck.dart';
import '../models/quiz_session.dart';
import '../models/flashcard.dart';
import '../services/ai_service.dart';
import '../utils/neumorphic_widgets.dart';
import 'flashcard_list_screen.dart';
import 'quiz_screen.dart';

class TopicPerformance {
  final Deck deck;
  final double accuracy;
  final int totalSessions;
  final int totalDuration;

  TopicPerformance({
    required this.deck,
    required this.accuracy,
    required this.totalSessions,
    required this.totalDuration,
  });
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final deckProvider = context.watch<DeckProvider>();
    final authProvider = context.watch<AuthProvider>();

    final streak = authProvider.dailyCheckInStreak;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Learning Analytics'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: deckProvider.getDetailedCardStats(),
        builder: (context, detailedStatsSnapshot) {
          if (detailedStatsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = detailedStatsSnapshot.data ?? {
            'totalCards': 0,
            'masteredCards': 0,
            'learningCards': 0,
            'dueCards': 0,
          };

          final totalCards = stats['totalCards'] ?? 0;
          final masteredCards = stats['masteredCards'] ?? 0;
          final learningCards = stats['learningCards'] ?? 0;
          final dueCards = stats['dueCards'] ?? 0;
          final newCards = (totalCards - masteredCards - learningCards).clamp(0, totalCards);

          return FutureBuilder<List<QuizSession>>(
            future: deckProvider.getQuizSessionsForUser(),
            builder: (context, sessionsSnapshot) {
              if (sessionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final sessions = sessionsSnapshot.data ?? [];
              
              // Calculate average accuracy and total study time
              double avgScore = 0.0;
              int totalStudySeconds = 0;
              if (sessions.isNotEmpty) {
                int totalScore = 0;
                int totalQuizCards = 0;
                for (var s in sessions) {
                  totalScore += s.score;
                  totalQuizCards += s.totalCards;
                  totalStudySeconds += s.duration;
                }
                avgScore = totalQuizCards > 0 ? totalScore / totalQuizCards : 0.0;
              }

              final weeklyActivity = _getWeeklyActivityData(sessions);

              // Compile topic (deck) performances
              final List<TopicPerformance> performances = [];
              for (var deck in deckProvider.decks) {
                final deckSessions = sessions.where((s) => s.deckId == deck.id).toList();
                if (deckSessions.isEmpty) continue;

                int scoreSum = 0;
                int totalCardsSum = 0;
                int durationSum = 0;
                for (var s in deckSessions) {
                  scoreSum += s.score;
                  totalCardsSum += s.totalCards;
                  durationSum += s.duration;
                }
                final accuracy = totalCardsSum > 0 ? scoreSum / totalCardsSum : 0.0;
                performances.add(TopicPerformance(
                  deck: deck,
                  accuracy: accuracy,
                  totalSessions: deckSessions.length,
                  totalDuration: durationSum,
                ));
              }

              TopicPerformance? weakestTopic;
              if (performances.isNotEmpty) {
                final sorted = List<TopicPerformance>.from(performances)
                  ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
                weakestTopic = sorted.first;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Stats Grid
                    _buildStatsGrid(context, totalCards, masteredCards, totalStudySeconds, streak, avgScore),
                    const SizedBox(height: 24),

                    // Weekly Activity Chart
                    Text(
                      'Weekly Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NeumorphicContainer(
                      padding: const EdgeInsets.all(20),
                      child: WeeklyActivityChart(data: weeklyActivity),
                    ),
                    const SizedBox(height: 24),

                    // Card Mastery Breakdown
                    Text(
                      'Card Mastery Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMasteryBreakdown(context, totalCards, masteredCards, learningCards, newCards),
                    const SizedBox(height: 24),

                    // Strengths & Weaknesses
                    Text(
                      'AI Topic Recommendations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTopicInsights(context, performances),
                    const SizedBox(height: 24),

                    // AI Personalized Action Plan
                    _buildAIActionPlan(context, weakestTopic),

                    // AI study coach card
                    AICoachSection(
                      totalCards: totalCards,
                      masteredCards: masteredCards,
                      dueCards: dueCards,
                      streak: streak,
                      avgScore: avgScore,
                    ),
                    const SizedBox(height: 24),

                    // Decks Progress list
                    Text(
                      'Deck Performance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDecksProgressList(context, deckProvider.decks),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper: Grid of top statistics
  Widget _buildStatsGrid(
    BuildContext context,
    int totalCards,
    int masteredCards,
    int totalStudySeconds,
    int streak,
    double avgScore,
  ) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.45,
      children: [
        _buildMiniStatCard(
          context,
          'Cards Studied',
          '$totalCards',
          Icons.library_books_rounded,
          theme.colorScheme.primary,
        ),
        _buildMiniStatCard(
          context,
          'Cards Mastered',
          '$masteredCards',
          Icons.workspace_premium_rounded,
          Colors.green,
        ),
        _buildMiniStatCard(
          context,
          'Study Time',
          _formatDuration(totalStudySeconds),
          Icons.hourglass_empty_rounded,
          Colors.orange,
        ),
        _buildMiniStatCard(
          context,
          'Quiz Accuracy',
          '${(avgScore * 100).toInt()}%',
          Icons.ads_click_rounded,
          theme.colorScheme.secondary,
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    return NeumorphicContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicInsights(BuildContext context, List<TopicPerformance> performances) {
    final theme = Theme.of(context);
    
    final strong = performances.where((p) => p.accuracy >= 0.8).toList();
    final weak = performances.where((p) => p.accuracy < 0.6).toList();

    if (performances.isEmpty) {
      return NeumorphicContainer(
        child: const Center(
          child: Text('Complete quiz sessions to reveal strength & weakness metrics!'),
        ),
      );
    }

    return NeumorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Strong Topics (>=80%)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (strong.isEmpty)
            Text(
              'No topics above 80% accuracy yet. Keep studying!',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: strong.map((p) => Chip(
                avatar: const Icon(Icons.check, color: Colors.green, size: 14),
                label: Text('${p.deck.title} (${(p.accuracy * 100).toInt()}%)'),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: BorderSide.none,
              )).toList(),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Weak Topics (<60%)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (weak.isEmpty)
            Text(
              'Excellent work! You have no weak topics under 60% accuracy.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weak.map((p) => Chip(
                avatar: const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                label: Text('${p.deck.title} (${(p.accuracy * 100).toInt()}%)'),
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                side: BorderSide.none,
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAIActionPlan(BuildContext context, TopicPerformance? weakestTopic) {
    if (weakestTopic == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final deckProvider = context.read<DeckProvider>();

    return FutureBuilder<List<Flashcard>>(
      future: deckProvider.getFlashcardsForDeck(weakestTopic.deck.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final cards = snapshot.data!;
        final unmasteredCards = cards.where((c) => !c.isMastered).toList();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: NeumorphicContainer(
            backgroundColor: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.insights_rounded, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Action Plan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Targeted study recommendation',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    children: [
                      const TextSpan(text: 'We noticed you struggle with '),
                      TextSpan(
                        text: weakestTopic.deck.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' (Accuracy: ${(weakestTopic.accuracy * 100).toInt()}% across ${weakestTopic.totalSessions} sessions).',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unmasteredCards.isEmpty
                      ? 'All cards are currently mastered! Study the deck again to reinforce your knowledge.'
                      : 'Review the ${unmasteredCards.length} unmastered cards to boost your retention.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: NeumorphicButton(
                    backgroundColor: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            deck: weakestTopic.deck,
                            flashcards: unmasteredCards.isEmpty ? cards : unmasteredCards,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        unmasteredCards.isEmpty ? 'Review All Cards' : 'Review ${unmasteredCards.length} Weak Cards',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper: Card Mastery Breakdown circular chart
  Widget _buildMasteryBreakdown(
    BuildContext context,
    int total,
    int mastered,
    int learning,
    int newCards,
  ) {
    final theme = Theme.of(context);
    final double masteredRatio = total > 0 ? mastered / total : 0.0;
    final double learningRatio = total > 0 ? learning / total : 0.0;
    final double newRatio = total > 0 ? newCards / total : 0.0;

    final masteredColor = theme.colorScheme.primary;
    final learningColor = theme.colorScheme.secondary;
    final newColor = theme.brightness == Brightness.dark 
        ? const Color(0xFF334155) 
        : const Color(0xFFE2E8F0);

    return NeumorphicContainer(
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(110, 110),
                    painter: DonutChartPainter(
                      masteredRatio: masteredRatio,
                      learningRatio: learningRatio,
                      newRatio: newRatio,
                      masteredColor: masteredColor,
                      learningColor: learningColor,
                      newColor: newColor,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(masteredRatio * 100).toInt()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mastered',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Mastered', mastered, masteredColor),
                const SizedBox(height: 8),
                _buildLegendItem(context, 'Learning', learning, learningColor),
                const SizedBox(height: 8),
                _buildLegendItem(context, 'New / Unstudied', newCards, newColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, int count, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Helper: Deck Performance progress list
  Widget _buildDecksProgressList(BuildContext context, List<Deck> decks) {
    final theme = Theme.of(context);

    if (decks.isEmpty) {
      return NeumorphicContainer(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Center(
          child: Text(
            'No decks available to evaluate yet.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeumorphicContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: FutureBuilder<double>(
              future: context.read<DeckProvider>().getDeckProgress(deck.id),
              builder: (context, progressSnapshot) {
                final progress = progressSnapshot.data ?? 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            deck.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}% mastered',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FutureBuilder<int>(
                          future: context.read<DeckProvider>().getDueCount(deck.id),
                          builder: (context, dueSnapshot) {
                            final due = dueSnapshot.data ?? 0;
                            return Text(
                              due > 0 ? '$due cards due for review' : 'All caught up!',
                              style: TextStyle(
                                fontSize: 11,
                                color: due > 0 ? Colors.redAccent : Colors.grey,
                                fontWeight: due > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FlashcardListScreen(deck: deck)),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Study →', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Calculate study stats in last 7 days from QuizSessions
  List<Map<String, dynamic>> _getWeeklyActivityData(List<QuizSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    List<Map<String, dynamic>> weeklyData = [];
    
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final daySessions = sessions.where((s) {
        final localDate = s.createdAt.toLocal();
        return localDate.year == day.year &&
               localDate.month == day.month &&
               localDate.day == day.day;
      });
      
      int totalCardsStudied = 0;
      for (var s in daySessions) {
        totalCardsStudied += s.totalCards;
      }
      
      final dayName = DateFormat('E').format(day);
      weeklyData.add({
        'day': dayName,
        'date': day,
        'cards': totalCardsStudied,
      });
    }
    
    return weeklyData;
  }
}

// ─── Weekly Activity Chart Widget ──────────────────────────────────────────

class WeeklyActivityChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;

  const WeeklyActivityChart({super.key, required this.data});

  @override
  State<WeeklyActivityChart> createState() => _WeeklyActivityChartState();
}

class _WeeklyActivityChartState extends State<WeeklyActivityChart> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCards = widget.data.map<int>((d) => d['cards'] as int).fold<int>(0, (m, e) => math.max(m, e));
    final maxChartVal = maxCards == 0 ? 10 : maxCards;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.data.length, (index) {
              final dayData = widget.data[index];
              final cards = dayData['cards'] as int;
              final ratio = cards / maxChartVal;
              final isHovered = hoveredIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => hoveredIndex = index),
                  onTapUp: (_) => setState(() => hoveredIndex = null),
                  onTapCancel: () => setState(() => hoveredIndex = null),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => hoveredIndex = index),
                    onExit: (_) => setState(() => hoveredIndex = null),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isHovered && cards > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$cards',
                              style: TextStyle(
                                color: theme.colorScheme.surface,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          height: (ratio * 100).clamp(6.0, 100.0),
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isHovered
                                  ? [theme.colorScheme.secondary, theme.colorScheme.primary]
                                  : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: widget.data.map((dayData) {
            return Expanded(
              child: Center(
                child: Text(
                  dayData['day'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Custom Donut Chart Painter ──────────────────────────────────────────────

class DonutChartPainter extends CustomPainter {
  final double masteredRatio;
  final double learningRatio;
  final double newRatio;
  final Color masteredColor;
  final Color learningColor;
  final Color newColor;

  DonutChartPainter({
    required this.masteredRatio,
    required this.learningRatio,
    required this.newRatio,
    required this.masteredColor,
    required this.learningColor,
    required this.newColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 14.0;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    if (masteredRatio == 0 && learningRatio == 0 && newRatio == 0) {
      final paint = Paint.from(basePaint)..color = Colors.grey.withValues(alpha: 0.2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * math.pi,
        false,
        paint,
      );
      return;
    }

    // Mastered segment
    if (masteredRatio > 0) {
      final paint = Paint.from(basePaint)..color = masteredColor;
      final sweepAngle = masteredRatio * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Learning segment
    if (learningRatio > 0) {
      final paint = Paint.from(basePaint)..color = learningColor;
      final sweepAngle = learningRatio * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // New segment
    if (newRatio > 0) {
      final paint = Paint.from(basePaint)..color = newColor;
      final sweepAngle = newRatio * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.masteredRatio != masteredRatio ||
        oldDelegate.learningRatio != learningRatio ||
        oldDelegate.newRatio != newRatio;
  }
}

// ─── AI Study Recommendations Coach Section ──────────────────────────────────

class AICoachSection extends StatefulWidget {
  final int totalCards;
  final int masteredCards;
  final int dueCards;
  final int streak;
  final double avgScore;

  const AICoachSection({
    super.key,
    required this.totalCards,
    required this.masteredCards,
    required this.dueCards,
    required this.streak,
    required this.avgScore,
  });

  @override
  State<AICoachSection> createState() => _AICoachSectionState();
}

class _AICoachSectionState extends State<AICoachSection> {
  String? _recommendations;
  bool _isLoading = false;
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _loadCachedTips();
  }

  Future<void> _loadCachedTips() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recommendations = prefs.getString('ai_study_tips');
    });
  }

  Future<void> _generateTips() async {
    setState(() {
      _isLoading = true;
    });

    final statsSummary = 'Total Cards: ${widget.totalCards}, '
        'Mastered Cards: ${widget.masteredCards}, '
        'Due Cards: ${widget.dueCards}, '
        'Study Streak: ${widget.streak} days, '
        'Average Quiz Score: ${(widget.avgScore * 100).toInt()}%';

    try {
      final tips = await _aiService.getStudyRecommendations(statsSummary);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_study_tips', tips);
      setState(() {
        _recommendations = tips;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to AI Coach: $e')),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeumorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Study Coach',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Actionable insight for your studies',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_recommendations != null && _recommendations!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recommendations!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.65,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _generateTips,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Tips', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get personalized study advice based on your learning metrics and quiz performance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: NeumorphicButton(
                    onPressed: _generateTips,
                    backgroundColor: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Center(
                      child: Text(
                        'Generate AI Study Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
