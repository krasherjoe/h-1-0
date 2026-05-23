import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/time_log_model.dart';
import '../services/time_log_repository.dart';

/// TI:工数管理（タイマー付き）
class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({super.key});
  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  final _repo = TimeLogRepository();
  final _df = DateFormat('yyyy/MM/dd');
  final _nf = NumberFormat('#,##0.0');

  List<TimeLog> _logs = [];
  bool _loading = true;
  bool _timerRunning = false;
  DateTime? _timerStart;
  Timer? _timerTick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _repo.getAll();
    if (!mounted) return;
    setState(() { _logs = logs; _loading = false; });
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTick?.cancel();
      setState(() => _timerRunning = false);
    } else {
      _timerStart = DateTime.now();
      _elapsed = Duration.zero;
      _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = DateTime.now().difference(_timerStart!));
      });
      setState(() => _timerRunning = true);
    }
  }

  String get _elapsedDisplay {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60);
    final s = _elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TI:工数管理'),
        actions: [
          TextButton.icon(
            onPressed: _timerRunning ? _toggleTimer : null,
            icon: const Icon(Icons.stop),
            label: Text(_elapsedDisplay, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTimer,
        icon: Icon(_timerRunning ? Icons.stop : Icons.play_arrow),
        label: Text(_timerRunning ? 'ストップ' : 'タイマー開始'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_timerRunning)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.green.withValues(alpha: 0.1),
                    child: Text('計測中: $_elapsedDisplay',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade700, fontFamily: 'monospace')),
                  ),
                Expanded(
                  child: _logs.isEmpty
                      ? const Center(child: Text('工数記録がありません'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          itemBuilder: (_, i) {
                            final log = _logs[i];
                            return Dismissible(
                              key: ValueKey(log.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: cs.error,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await _repo.delete(log.id);
                                _load();
                              },
                              child: Card(
                                child: ListTile(
                                  title: Text('${_nf.format(log.hours)}h', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${_df.format(log.date)}${log.memo != null ? " / ${log.memo}" : ""}'),
                                  trailing: Text('合計: ${_nf.format(log.hours)}h'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
