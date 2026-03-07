import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/sync_preferences.dart';
import 'app_settings_repository.dart';
import 'gmail_sync_client.dart';
import 'mothership_chat_client.dart';
import 'mothership_discovery_service.dart';

class ChatSyncScheduler with WidgetsBindingObserver {
  ChatSyncScheduler({Duration? interval}) : _interval = interval ?? const Duration(seconds: 10);

  final Duration _interval;
  final GmailSyncClient _gmailClient = GmailSyncClient();
  final MothershipChatClient _directClient = MothershipChatClient();
  final MothershipDiscoveryService _discovery = MothershipDiscoveryService();
  final AppSettingsRepository _settings = AppSettingsRepository();

  Timer? _timer;
  bool _started = false;
  bool _syncing = false;
  bool _appActive = true;

  void start() {
    if (_started) return;
    _started = true;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _appActive = _isActiveState(binding.lifecycleState);
    if (_appActive) {
      _scheduleImmediate();
    }
  }

  void stop() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void dispose() => stop();

  void _scheduleImmediate() {
    _timer?.cancel();
    _runSync();
    _timer = Timer.periodic(_interval, (_) => _runSync());
  }

  void _runSync() {
    if (!_appActive || _syncing) return;
    _syncing = true;
    unawaited(_executeSyncWithTransportSelection().whenComplete(() {
      _syncing = false;
    }));
  }

  Future<void> _executeSyncWithTransportSelection() async {
    final transportMode = await _settings.getSyncTransportMode();

    switch (transportMode) {
      case SyncTransportMode.gmailOnly:
        await _gmailClient.sync();
        break;

      case SyncTransportMode.directOnly:
        await _directClient.sync();
        break;

      case SyncTransportMode.auto:
        final autoDiscoveryEnabled = await _discovery.isAutoDiscoveryEnabled();
        bool useDirectConnection = false;

        if (autoDiscoveryEnabled) {
          final range = await _discovery.getDiscoveryRange();
          useDirectConnection = await _discovery.findNearbyMothership(rangeMeters: range);
        }

        if (useDirectConnection) {
          try {
            await _directClient.sync();
          } catch (err) {
            await _gmailClient.sync();
          }
        } else {
          await _gmailClient.sync();
        }
        break;
    }
  }

  bool _isActiveState(AppLifecycleState? state) {
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = _isActiveState(state);
    if (!_started) return;
    if (_appActive) {
      _scheduleImmediate();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}
