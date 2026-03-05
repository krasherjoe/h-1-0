import 'package:flutter/material.dart';

typedef ModuleCardAction = Future<void> Function(BuildContext context);

class ModuleDashboardCard {
  const ModuleDashboardCard({
    required this.id,
    required this.route,
    required this.title,
    required this.description,
    required this.iconName,
    required this.onTap,
    this.requiresUnlock = false,
  });

  final String id;
  final String route;
  final String title;
  final String description;
  final String iconName;
  final ModuleCardAction onTap;
  final bool requiresUnlock;
}

abstract class FeatureModule {
  String get key;
  bool get isEnabled;
  List<ModuleDashboardCard> get dashboardCards;

  ModuleDashboardCard? cardByRoute(String route) {
    try {
      return dashboardCards.firstWhere((card) => card.route == route);
    } catch (_) {
      return null;
    }
  }
}
