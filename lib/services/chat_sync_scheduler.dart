import 'dart:async';

import 'package:flutter/widgets.dart';

import 'mothership_chat_client.dart';

class ChatSyncScheduler with WidgetsBindingObserver {
  ChatSyncScheduler({Duration? interval}) : _interval = interval ?? const Duration(seconds: 10);

  final Duration _interval;
  final MothershipChatClient _chatClient = MothershipChatClient();

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
    unawaited(_chatClient.sync().whenComplete(() {
      _syncing = false;
    }));
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
