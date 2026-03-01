import 'dart:convert';
import 'dart:io';

class ClientStatus {
  ClientStatus({
    required this.clientId,
    required this.lastSync,
    required this.lastHash,
    required this.remainingLifespan,
  });

  final String clientId;
  final DateTime? lastSync;
  final String? lastHash;
  final Duration? remainingLifespan;

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'lastSync': lastSync?.toIso8601String(),
        'lastHash': lastHash,
        'remainingLifespanSeconds': remainingLifespan?.inSeconds,
      };
}

class MothershipDataStore {
  MothershipDataStore(this.rootDir);

  final Directory rootDir;
  final Map<String, ClientStatus> _statuses = {};

  Future<void> init() async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    await _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final statusFile = File('${rootDir.path}/status.json');
    if (await statusFile.exists()) {
      final decoded = jsonDecode(await statusFile.readAsString()) as List<dynamic>;
      for (final entry in decoded) {
        final map = Map<String, dynamic>.from(entry as Map);
        _statuses[map['clientId'] as String] = ClientStatus(
          clientId: map['clientId'] as String,
          lastSync: map['lastSync'] != null ? DateTime.tryParse(map['lastSync'] as String) : null,
          lastHash: map['lastHash'] as String?,
          remainingLifespan: map['remainingLifespanSeconds'] != null
              ? Duration(seconds: map['remainingLifespanSeconds'] as int)
              : null,
        );
      }
    }
  }

  Future<void> _persistStatuses() async {
    final statusFile = File('${rootDir.path}/status.json');
    final list = _statuses.values.map((e) => e.toJson()).toList();
    await statusFile.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
  }

  Future<void> recordHeartbeat({
    required String clientId,
    required Duration? remaining,
  }) async {
    final existing = _statuses[clientId];
    _statuses[clientId] = ClientStatus(
      clientId: clientId,
      lastSync: DateTime.now().toUtc(),
      lastHash: existing?.lastHash,
      remainingLifespan: remaining,
    );
    await _persistStatuses();
  }

  Future<void> recordHash({
    required String clientId,
    required String hash,
  }) async {
    final existing = _statuses[clientId];
    _statuses[clientId] = ClientStatus(
      clientId: clientId,
      lastSync: DateTime.now().toUtc(),
      lastHash: hash,
      remainingLifespan: existing?.remainingLifespan,
    );
    await _persistStatuses();
  }

  List<ClientStatus> listStatuses() => _statuses.values.toList()
    ..sort((a, b) => (a.clientId).compareTo(b.clientId));
}
