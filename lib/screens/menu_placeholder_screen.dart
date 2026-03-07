import 'package:flutter/material.dart';

import '../constants/dashboard_icons.dart';
import '../models/dashboard_menu_item.dart';
import '../widgets/screen_id_title.dart';

class MenuPlaceholderScreen extends StatelessWidget {
  const MenuPlaceholderScreen({super.key, required this.item});

  final DashboardMenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = item.description ?? 'Coming soon';
    return Scaffold(
      appBar: AppBar(
        title: ScreenAppBarTitle(
          screenId: item.id.toUpperCase(),
          title: item.title,
          caption: item.category,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: theme.colorScheme.primary,
              child: Icon(_iconData, size: 28),
            ),
            const SizedBox(height: 16),
            Text(item.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route: ${item.route}'),
                    Text('Screen ID: ${item.id.toUpperCase()}'),
                    Text('Category: ${item.category}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('実装予定: イベントソーシング連動の詳細画面を準備中です。'),
          ],
        ),
      ),
    );
  }

  IconData get _iconData {
    final name = item.iconName ?? 'menu';
    return kDashboardIcons[name] ?? Icons.apps;
  }
}
