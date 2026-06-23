import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/social_provider.dart';
import '../providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'analytics_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final deckProvider = context.watch<DeckProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Profile',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.onPrimary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          Consumer<SocialProvider?>(
            builder: (context, social, child) {
              final count = social?.totalNotificationCount ?? 0;
              return IconButton(
                icon: Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.white,
                  textColor: colorScheme.secondary,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 100, bottom: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.brightness == Brightness.dark
                          ? const [Color(0xFF0B0F19), Color(0xFF1E1B4B)]
                          : [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              colorScheme.onSurface.withValues(alpha: 0.2),
                          backgroundImage: user.profileImageUrl != null &&
                                  File(user.profileImageUrl!).existsSync()
                              ? FileImage(File(user.profileImageUrl!))
                              : null,
                          child: user.profileImageUrl == null ||
                                  !File(user.profileImageUrl!).existsSync()
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      FutureBuilder<Map<String, int>>(
                        future: deckProvider.getTotalStats(),
                        builder: (context, snapshot) {
                          final stats = snapshot.data ??
                              {'totalCards': 0, 'masteredCards': 0};
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                  child: _buildStatCard(
                                      context,
                                      'Decks',
                                      deckProvider.decks.length.toString(),
                                      Icons.style)),
                              Expanded(
                                  child: _buildStatCard(
                                      context,
                                      'Cards',
                                      stats['totalCards'].toString(),
                                      Icons.copy)),
                              Expanded(
                                  child: _buildStatCard(
                                      context,
                                      'Mastered',
                                      stats['masteredCards'].toString(),
                                      Icons.auto_awesome)),
                            ],
                          );
                        },
                      ),
                      _buildProfileOption(
                        context,
                        icon: Icons.edit_outlined,
                        title: 'Edit Profile',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EditProfileScreen()),
                          );
                        },
                      ),
                      _buildProfileOption(
                        context,
                        icon: Icons.bar_chart_rounded,
                        title: 'Learning Analytics',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AnalyticsScreen()),
                          );
                        },
                      ),

                      _buildProfileOption(
                        context,
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () => _showHelpSheet(context),
                      ),
                      SwitchListTile(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) => themeProvider.setDarkMode(value),
                        activeThumbColor: colorScheme.primary,
                        title: const Text('Dark Theme',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            themeProvider.isDarkMode
                                ? 'Dark mode is enabled'
                                : 'Light mode is enabled',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                        secondary: const Icon(Icons.dark_mode_outlined),
                      ),
                      _buildProfileOption(
                        context,
                        icon: Icons.logout,
                        title: 'Logout',
                        titleColor: Colors.red,
                        onTap: () => _showLogoutDialog(context, authProvider),
                      ),
                      const SizedBox(
                          height: 100), // Space for floating bottom nav
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.secondary),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: titleColor ?? colorScheme.onSurface),
      title: Text(title,
          style: TextStyle(
              color: titleColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showHelpSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.help_outline_rounded,
                      color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help & Support',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Frequently asked questions',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // About card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    Color.lerp(
                        colorScheme.primary, Colors.indigo.shade900, 0.5)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About AI Study',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'AI Study is a smart flashcard app that helps you learn more effectively using spaced repetition and AI-powered study assistance. '
                    'Built as a Final Year Project to explore how AI can enhance the learning experience.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FAQ section
            Text('Common Questions',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            _HelpFaqTile(
              question: 'How do I create flashcards?',
              answer:
                  'Go to the Deck Library tab, create a new deck, then tap on it to add flashcards. '
                  'You can also use the AI assistant to generate flashcards automatically from your notes.',
            ),
            _HelpFaqTile(
              question: 'What is spaced repetition?',
              answer:
                  'Spaced repetition is a learning technique where you review cards at increasing intervals. '
                  'Cards you find difficult appear more often, while mastered cards show up less frequently.',
            ),
            _HelpFaqTile(
              question: 'How does the AI assistant work?',
              answer:
                  'The AI assistant uses Google\'s Gemini model to help you study. It can explain concepts, '
                  'quiz you on your flashcards, and generate new cards from your study materials.',
            ),
            _HelpFaqTile(
              question: 'How do I share decks with friends?',
              answer:
                  'Open a deck from your library, tap the menu (⋮) and select "Share". '
                  'You can share directly with friends, export as a PDF, or generate a share link.',
            ),
            _HelpFaqTile(
              question: 'What is the daily challenge?',
              answer:
                  'The daily challenge sets a target number of cards to review each day. '
                  'Completing it builds your study streak and helps maintain consistent learning habits.',
            ),
            _HelpFaqTile(
              question: 'Is my data stored securely?',
              answer:
                  'Yes. Your data is stored locally on your device and synced securely via Firebase. '
                  'Your account is protected by Firebase Authentication.',
            ),

            const SizedBox(height: 24),

            // Version footer
            Center(
              child: Text(
                'AI Study · v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.logout();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _HelpFaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpFaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(Icons.quiz_outlined,
              size: 20,
              color: theme.colorScheme.primary.withValues(alpha: 0.6)),
          title: Text(
            question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              answer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
