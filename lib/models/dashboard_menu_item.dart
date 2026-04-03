class DashboardMenuItem {
  final String id;
  final String title;
  final String route;
  final String category;
  final bool enabled;
  final String? iconName;
  final String? description;
  final String? customIconPath;

  const DashboardMenuItem({
    required this.id,
    required this.title,
    required this.route,
    required this.category,
    this.enabled = true,
    this.iconName,
    this.description,
    this.customIconPath,
  });

  DashboardMenuItem copyWith({
    String? id,
    String? title,
    String? route,
    String? category,
    bool? enabled,
    String? iconName,
    String? description,
    String? customIconPath,
  }) {
    return DashboardMenuItem(
      id: id ?? this.id,
      title: title ?? this.title,
      route: route ?? this.route,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      iconName: iconName ?? this.iconName,
      description: description ?? this.description,
      customIconPath: customIconPath ?? this.customIconPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'route': route,
        'category': category,
        'enabled': enabled,
        'iconName': iconName,
        'description': description,
        'customIconPath': customIconPath,
      };

  factory DashboardMenuItem.fromJson(Map<String, dynamic> json) {
    return DashboardMenuItem(
      id: json['id'] as String,
      title: json['title'] as String,
      route: json['route'] as String,
      category: (json['category'] as String?) ?? '01. マスタ管理',
      enabled: (json['enabled'] as bool?) ?? true,
      iconName: json['iconName'] as String?,
      description: json['description'] as String?,
      customIconPath: json['customIconPath'] as String?,
    );
  }
}
