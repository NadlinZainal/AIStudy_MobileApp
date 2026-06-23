import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/social_provider.dart';
import '../models/social_models.dart';
import 'package:intl/intl.dart';
import '../utils/neumorphic_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: socialProvider == null
      ? const Center(child: NeumorphicLoader(label: 'Checking for updates…'))
          : RefreshIndicator(
              onRefresh: () => socialProvider.loadSocialData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (socialProvider.totalNotificationCount == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Column(
                          children: [
                            NeumorphicContainer(
                              padding: const EdgeInsets.all(20),
                              borderRadius: BorderRadius.circular(28),
                              child: Icon(Icons.notifications_off_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: 16),
                            const Text('No new notifications', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  if (socialProvider.pendingRequests.isNotEmpty) ...[
                    const _SectionHeader(title: 'Friend Requests'),
                    ...socialProvider.pendingRequests.map((req) => _FriendRequestTile(request: req)),
                    const SizedBox(height: 24),
                  ],
                  if (socialProvider.unreadMessageCount > 0) ...[
                    const _SectionHeader(title: 'Messages'),
                    _UnreadMessagesSummary(count: socialProvider.unreadMessageCount),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  final FriendRequest request;
  const _FriendRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.read<SocialProvider>();
    return NeumorphicContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Text(request.requesterUsername[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
        title: Text('${request.requesterName} wants to connect', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@${request.requesterUsername} • ${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(request.timestamp))}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => socialProvider.respondToRequest(request, true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => socialProvider.respondToRequest(request, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadMessagesSummary extends StatelessWidget {
  final int count;
  const _UnreadMessagesSummary({required this.count});

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          child: Icon(Icons.chat_bubble, color: Colors.white),
        ),
        title: Text('You have $count unread message${count > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Head to the Social tab to check your chats.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // In a real app, we'd navigate to the chat tab or a specific friend's chat
          // For now, let's just close notifications and let user navigate via bottom bar
          Navigator.pop(context);
        },
      ),
    );
  }
}
