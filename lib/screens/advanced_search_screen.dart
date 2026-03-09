import 'package:flutter/material.dart';
import '../services/advanced_search_service.dart';
import '../services/full_text_search_service.dart';

/// 高速検索拡張画面
class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final AdvancedSearchService _advancedSearchService = AdvancedSearchService.instance;
  final FullTextSearchService _ftsService = FullTextSearchService.instance;
  
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  Map<String, dynamic>? _searchStats;
  Map<String, dynamic>? _performanceMetrics;
  bool _isSearching = false;
  bool _isOptimizing = false;
  String _selectedSearchType = 'normal';
  String _selectedTable = 'all';
  double _fuzzyThreshold = 0.6;
  bool _useCache = true;
  int _resultLimit = 50;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      await _advancedSearchService.optimizeIndexes();
      _loadStatistics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初期化に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _loadStatistics() async {
    final stats = await _advancedSearchService.getSearchStatistics();
    setState(() {
      _searchStats = stats;
    });
  }
  
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _searchResults = {};
    });
    
    try {
      // パフォーマンス測定
      final metrics = await _advancedSearchService.measureSearchPerformance(query);
      
      List<Map<String, dynamic>> results;
      
      switch (_selectedSearchType) {
        case 'normal':
          results = await _advancedSearchService.searchWithCache(
            query,
            table: _selectedTable == 'all' ? null : _selectedTable,
            limit: _resultLimit,
          );
          break;
        case 'fuzzy':
          results = await _advancedSearchService.fuzzySearch(
            query,
            table: _selectedTable == 'all' ? null : _selectedTable,
            threshold: _fuzzyThreshold,
            limit: _resultLimit,
          );
          break;
        case 'fts':
          final ftsResults = await _ftsService.searchAll(query);
          results = ftsResults.values.expand((e) => e).take(_resultLimit).toList();
          break;
        default:
          results = [];
      }
      
      // 結果をテーブルごとに分類
      final categorizedResults = <String, List<Map<String, dynamic>>>{};
      for (final result in results) {
        String? table;
        if (result.containsKey('display_name')) {
          table = 'customers';
        } else if (result.containsKey('name') && result.containsKey('category')) {
          table = 'products';
        } else if (result.containsKey('document_number')) {
          table = 'invoices';
        } else if (result.containsKey('contact_person')) {
          table = 'suppliers';
        }
        
        if (table != null) {
          categorizedResults[table] ??= [];
          categorizedResults[table]!.add(result);
        }
      }
      
      setState(() {
        _searchResults = categorizedResults;
        _performanceMetrics = metrics;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _optimizeIndexes() async {
    setState(() {
      _isOptimizing = true;
    });
    
    try {
      await _advancedSearchService.optimizeIndexes();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('インデックス最適化が完了しました'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadStatistics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('最適化に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isOptimizing = false;
      });
    }
  }
  
  void _clearCache() {
    _advancedSearchService.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('検索キャッシュをクリアしました'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3:高度検索'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '統計更新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchConfiguration(),
          _buildSearchBar(),
          if (_searchStats != null) _buildStatistics(),
          if (_performanceMetrics != null) _buildPerformanceMetrics(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }
  
  Widget _buildSearchConfiguration() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検索設定',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSearchType,
                    decoration: const InputDecoration(
                      labelText: '検索タイプ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('通常検索')),
                      DropdownMenuItem(value: 'fuzzy', child: Text('あいまい検索')),
                      DropdownMenuItem(value: 'fts', child: Text('全文検索')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSearchType = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTable,
                    decoration: const InputDecoration(
                      labelText: '検索対象',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('すべて')),
                      DropdownMenuItem(value: 'customers', child: Text('顧客')),
                      DropdownMenuItem(value: 'products', child: Text('製品')),
                      DropdownMenuItem(value: 'invoices', child: Text('請求書')),
                      DropdownMenuItem(value: 'suppliers', child: Text('仕入先')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTable = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedSearchType == 'fuzzy') ...[
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _fuzzyThreshold,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '類似度: ${(_fuzzyThreshold * 100).toStringAsFixed(0)}%',
                      onChanged: (value) {
                        setState(() {
                          _fuzzyThreshold = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${(_fuzzyThreshold * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _resultLimit.toDouble(),
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: '件数: $_resultLimit',
                    onChanged: (value) {
                      setState(() {
                        _resultLimit = value.toInt();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_resultLimit件',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: _useCache,
                  onChanged: (value) {
                    setState(() {
                      _useCache = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('キャッシュを使用'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isOptimizing ? null : _optimizeIndexes,
                  icon: _isOptimizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed),
                  label: Text(_isOptimizing ? '最適化中...' : 'インデックス最適化'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'キャッシュクリア',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '検索キーワード',
                  hintText: '入力して検索',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = {};
                              _performanceMetrics = null;
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSearching ? null : _performSearch,
              child: _isSearching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('検索'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatistics() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'データ統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatChip('顧客', '${_searchStats!['customers_count'] ?? 0}件', Icons.person),
                _buildStatChip('製品', '${_searchStats!['products_count'] ?? 0}件', Icons.inventory),
                _buildStatChip('請求書', '${_searchStats!['invoices_count'] ?? 0}件', Icons.receipt),
                _buildStatChip('仕入先', '${_searchStats!['suppliers_count'] ?? 0}件', Icons.business),
                _buildStatChip('キャッシュ', '${_searchStats!['cache_size'] ?? 0}件', Icons.memory),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatChip(String label, String value, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      backgroundColor: Colors.blue.shade50,
    );
  }
  
  Widget _buildPerformanceMetrics() {
    if (_performanceMetrics == null) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'パフォーマンス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMetricRow('通常検索', _performanceMetrics!['normal_search']),
            _buildMetricRow('あいまい検索', _performanceMetrics!['fuzzy_search']),
            _buildMetricRow('全文検索', _performanceMetrics!['fts_search']),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow(String label, Map<String, dynamic> metric) {
    final time = metric['time_ms'] as int? ?? 0;
    final count = metric['results_count'] as int? ?? 0;
    
    Color color = Colors.green;
    if (time > 100) {
      color = Colors.orange;
    }
    if (time > 500) {
      color = Colors.red;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Text(
            '${time}ms',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(' / '),
          Text(
            '$count件',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (time > 0)
            Text(
              '${(count * 1000 / time).toStringAsFixed(0)}件/秒',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('検索結果がありません'),
            SizedBox(height: 8),
            Text('キーワードを入力して検索してください'),
          ],
        ),
      );
    }
    
    return DefaultTabController(
      length: _searchResults.keys.length,
      child: Column(
        children: [
          TabBar(
            tabs: _searchResults.keys.map((key) {
              String label;
              switch (key) {
                case 'customers':
                  label = '顧客';
                  break;
                case 'products':
                  label = '製品';
                  break;
                case 'invoices':
                  label = '請求書';
                  break;
                case 'suppliers':
                  label = '仕入先';
                  break;
                default:
                  label = key;
              }
              return Tab(
                text: '$label (${_searchResults[key]!.length})',
              );
            }).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: _searchResults.entries.map((entry) {
                return _buildResultList(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultList(String category, List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultItem(category, result);
      },
    );
  }
  
  Widget _buildResultItem(String category, Map<String, dynamic> result) {
    String title;
    String subtitle;
    IconData icon;
    
    switch (category) {
      case 'customers':
        title = result['display_name'] ?? '不明';
        subtitle = result['tel'] ?? '';
        icon = Icons.person;
        break;
      case 'products':
        title = result['name'] ?? '不明';
        subtitle = result['category'] ?? '';
        icon = Icons.inventory;
        break;
      case 'invoices':
        title = result['document_number'] ?? '不明';
        subtitle = result['subject'] ?? '';
        icon = Icons.receipt;
        break;
      case 'suppliers':
        title = result['name'] ?? '不明';
        subtitle = result['tel'] ?? '';
        icon = Icons.business;
        break;
      default:
        title = '不明';
        subtitle = '';
        icon = Icons.help;
    }
    
    final fuzzyScore = result['_fuzzy_score'] as double?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Icon(icon, color: Colors.indigo),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            if (fuzzyScore != null)
              Text(
                '類似度: ${(fuzzyScore * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          _showResultDetails(category, result);
        },
      ),
    );
  }
  
  void _showResultDetails(String category, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getResultTitle(category)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: result.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Text(': '),
                    Expanded(
                      child: Text(
                        entry.value?.toString() ?? '',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
  
  String _getResultTitle(String category) {
    switch (category) {
      case 'customers':
        return '顧客詳細';
      case 'products':
        return '製品詳細';
      case 'invoices':
        return '請求書詳細';
      case 'suppliers':
        return '仕入先詳細';
      default:
        return '詳細';
    }
  }
}
