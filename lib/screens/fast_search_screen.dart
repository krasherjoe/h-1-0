import 'dart:async';
import 'package:flutter/material.dart';
import '../services/full_text_search_service.dart';

/// 高速検索画面
class FastSearchScreen extends StatefulWidget {
  const FastSearchScreen({super.key});

  @override
  State<FastSearchScreen> createState() => _FastSearchScreenState();
}

class _FastSearchScreenState extends State<FastSearchScreen> {
  final FullTextSearchService _searchService = FullTextSearchService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  List<String> _suggestions = [];
  bool _isSearching = false;
  bool _isIndexing = false;
  String _selectedCategory = 'all';
  Timer? _searchTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeFts();
  }
  
  Future<void> _initializeFts() async {
    setState(() {
      _isIndexing = true;
    });

    try {
      await _searchService.createFtsTables();
      await _searchService.updateFtsIndex();
    } catch (e) {
      debugPrint('FTS初期化エラー: $e');
      // FTSが使えなくてもLIKE検索フォールバックで画面は利用可能
    } finally {
      if (mounted) {
        setState(() {
          _isIndexing = false;
        });
      }
    }
  }
  
  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    
    if (query.length < 2) {
      setState(() {
        _searchResults = {};
        _suggestions = [];
      });
      return;
    }
    
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }
  
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      final normalizedQuery = _searchService.normalizeForJapaneseSearch(query);
      final optimizedQuery = _searchService.optimizeSearchQuery(normalizedQuery);
      
      if (_selectedCategory == 'all') {
        final results = await _searchService.searchAll(optimizedQuery);
        final suggestions = await _searchService.getSuggestions(optimizedQuery);
        
        setState(() {
          _searchResults = results;
          _suggestions = suggestions;
        });
      } else {
        final results = await _searchService.advancedSearch(
          query: optimizedQuery,
          targetTypes: [_selectedCategory],
        );
        
        setState(() {
          _searchResults = results;
          _suggestions = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  Future<void> _rebuildIndex() async {
    setState(() {
      _isIndexing = true;
    });
    
    try {
      await _searchService.rebuildFtsIndex();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('検索インデックスを再構築しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インデックス再構築に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isIndexing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FS:高速検索'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _rebuildIndex,
            tooltip: 'インデックス再構築',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_suggestions.isNotEmpty) _buildSuggestions(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: '検索キーワード',
                      hintText: '顧客名、製品名、請求書番号など',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('すべて')),
                    DropdownMenuItem(value: 'customers', child: Text('顧客')),
                    DropdownMenuItem(value: 'products', child: Text('製品')),
                    DropdownMenuItem(value: 'invoices', child: Text('請求書')),
                    DropdownMenuItem(value: 'suppliers', child: Text('仕入先')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  },
                ),
              ],
            ),
            if (_isIndexing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('検索インデックスを構築中...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSuggestions() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () {
                _searchController.text = suggestion;
                _performSearch(suggestion);
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('検索結果がありません'),
            SizedBox(height: 8),
            Text('キーワードを入力してください'),
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
    if (results.isEmpty) {
      return const Center(
        child: Text('結果がありません'),
      );
    }
    
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
    
    final rank = result['rank'] as int? ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            Text(
              '関連度: ${rank}',
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
                      width: 100,
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
  
  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
