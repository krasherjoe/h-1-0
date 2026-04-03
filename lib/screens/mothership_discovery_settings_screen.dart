import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/mothership_location.dart';
import '../services/mothership_discovery_service.dart';

/// お局様検出設定画面
class MothershipDiscoverySettingsScreen extends StatefulWidget {
  const MothershipDiscoverySettingsScreen({super.key});

  @override
  State<MothershipDiscoverySettingsScreen> createState() => _MothershipDiscoverySettingsScreenState();
}

class _MothershipDiscoverySettingsScreenState extends State<MothershipDiscoverySettingsScreen> {
  final _discovery = MothershipDiscoveryService();
  bool _autoDiscoveryEnabled = true;
  double _discoveryRange = 500.0;
  List<MothershipLocation> _locations = [];
  bool _loading = true;
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final enabled = await _discovery.isAutoDiscoveryEnabled();
    final range = await _discovery.getDiscoveryRange();
    final locations = await _discovery.getRecordedLocations();
    setState(() {
      _autoDiscoveryEnabled = enabled;
      _discoveryRange = range;
      _locations = locations;
      _loading = false;
    });
  }

  Future<void> _toggleAutoDiscovery(bool value) async {
    await _discovery.setAutoDiscoveryEnabled(value);
    setState(() => _autoDiscoveryEnabled = value);
  }

  Future<void> _updateRange(double value) async {
    await _discovery.setDiscoveryRange(value);
    setState(() => _discoveryRange = value);
  }

  Future<void> _recordCurrentLocation() async {
    setState(() => _discovering = true);
    try {
      final success = await _discovery.discoverAndRecord();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お局様の位置を記録しました')),
        );
        await _loadSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お局様への接続に失敗しました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _discovering = false);
      }
    }
  }

  Future<void> _deleteLocation(int id) async {
    await _discovery.deleteLocation(id);
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('位置情報を削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SD:お局様検出設定'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.radar, color: Colors.green),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '自動検出設定',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('GPS位置ベースの自動検出'),
                          subtitle: const Text('記憶した場所に近づいたら自動で直接通信を試行'),
                          value: _autoDiscoveryEnabled,
                          onChanged: _toggleAutoDiscovery,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '検出範囲: ${_discoveryRange.toStringAsFixed(0)} m',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _discoveryRange,
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          label: '${_discoveryRange.toStringAsFixed(0)}m',
                          onChanged: (value) {
                            setState(() => _discoveryRange = value);
                          },
                          onChangeEnd: _updateRange,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'この範囲内に記憶された場所があれば、お局様への直接通信を優先します',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '現在地で登録',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'お局様が設定されている場合、現在地とお局様のIPアドレスを紐づけて記憶します',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _discovering ? null : _recordCurrentLocation,
                            icon: _discovering
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add_location),
                            label: Text(_discovering ? '検出中...' : 'この場所を記憶'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storage, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '記憶された場所',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_locations.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'まだ場所が記憶されていません',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ..._locations.map((location) => _buildLocationTile(location)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildLocationTile(MothershipLocation location) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.place, color: Colors.green),
        title: Text(
          location.host,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '位置: (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})\n'
          '最終接続: ${dateFormat.format(location.lastSeen)}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('削除確認'),
                content: Text('${location.host} の位置情報を削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
            if (confirm == true && location.id != null) {
              await _deleteLocation(location.id!);
            }
          },
        ),
      ),
    );
  }
}
