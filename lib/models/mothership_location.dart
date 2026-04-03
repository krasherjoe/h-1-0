class MothershipLocation {
  MothershipLocation({
    this.id,
    required this.host,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    required this.createdAt,
  });

  final int? id;
  final String host;
  final double latitude;
  final double longitude;
  final DateTime lastSeen;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'host': host,
        'latitude': latitude,
        'longitude': longitude,
        'last_seen': lastSeen.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory MothershipLocation.fromMap(Map<String, dynamic> map) {
    return MothershipLocation(
      id: map['id'] as int?,
      host: map['host'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lastSeen: DateTime.parse(map['last_seen'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  MothershipLocation copyWith({
    int? id,
    String? host,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return MothershipLocation(
      id: id ?? this.id,
      host: host ?? this.host,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
