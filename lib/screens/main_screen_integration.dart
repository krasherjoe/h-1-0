import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

/// メイン画面統合
class MainScreenIntegration extends StatefulWidget {
  const MainScreenIntegration({super.key});

  @override
  State<MainScreenIntegration> createState() => _MainScreenIntegrationState();
}

class _MainScreenIntegrationState extends State<MainScreenIntegration> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  
  final List<Widget> _pages = [
    const InvoiceListPage(),
    const SearchPage(),
    const PerformancePage(),
    const SensorPage(),
  ];
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: _currentIndex == 0
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_pageController.page != 0) {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() {
                      _currentIndex = 0;
                    });
                  }
                },
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // ページの更新処理
            },
          ),
        ],
      ),
      drawer: const AppNavigationDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
  
  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'I1:請求書一覧';
      case 1:
        return 'S1:検索';
      case 2:
        return 'P1:パフォーマンス';
      case 3:
        return 'S2:センサー';
      default:
        return '会計管理アプリ';
    }
  }
}

/// 請求書一覧ページ
class InvoiceListPage extends StatelessWidget {
  const InvoiceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt, size: 64, color: Theme.of(context).colorScheme.primary),
          SizedBox(height: 16),
          Text(
            '請求書一覧',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('請求書の管理機能'),
        ],
      ),
    );
  }
}

/// 検索ページ
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          const Text(
            '検索機能',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('高速全文検索と高度検索'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.fastSearch);
                },
                icon: const Icon(Icons.search),
                label: const Text('高速検索'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.advancedSearch);
                },
                icon: const Icon(Icons.manage_search),
                label: const Text('高度検索'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// パフォーマンスページ
class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speed, size: 64, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(height: 16),
          const Text(
            'パフォーマンス最適化',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('アプリのパフォーマンスを最適化'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.performanceOptimization);
                },
                icon: const Icon(Icons.speed),
                label: const Text('最適化'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.uiPerformance);
                },
                icon: const Icon(Icons.monitor_heart),
                label: const Text('UI最適化'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// センサーページ
class SensorPage extends StatelessWidget {
  const SensorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors, size: 64, color: Theme.of(context).colorScheme.primaryContainer),
          const SizedBox(height: 16),
          const Text(
            'センサー機能',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('スマートフォンのセンサーを活用'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.sensorUtilization);
                },
                icon: const Icon(Icons.sensors),
                label: const Text('基本機能'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  NavigationService.instance.navigateTo(AppRoutes.enhancedSensor);
                },
                icon: const Icon(Icons.sensors_rounded),
                label: const Text('拡張機能'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
