import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/pill_provider.dart';
import '../services/admob_service.dart';
import '../widgets/today_pills_widget.dart';
import '../widgets/calendar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdMobService _adMobService = AdMobService();
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    await _adMobService.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });
  }

  Future<void> _loadBannerAd() async {
    try {
      await _adMobService.loadBannerAd();
      if (mounted) {
        setState(() {
          _isBannerAdLoaded = _adMobService.isBannerAdLoaded;
        });
      }
    } catch (e) {
      // 광고 로드 실패 처리
    }
  }

  @override
  void dispose() {
    _adMobService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알약 알리미'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '오늘'),
                      Tab(text: '달력'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildTodayTab(), const CalendarWidget()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isBannerAdLoaded) _buildBannerAd(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPillDialog(context),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodayTab() {
    return Consumer<PillProvider>(
      builder: (context, pillProvider, child) {
        return FutureBuilder(
          future: pillProvider.loadPills(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
            }

            return const TodayPillsWidget();
          },
        );
      },
    );
  }

  Widget _buildBannerAd() {
    final bannerAd = _adMobService.bannerAd;
    if (bannerAd != null) {
      return Container(
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        child: AdWidget(ad: bannerAd),
      );
    }
    return const SizedBox.shrink();
  }

  void _showAddPillDialog(BuildContext context) {
    Navigator.pushNamed(context, '/add-pill');
  }
}
