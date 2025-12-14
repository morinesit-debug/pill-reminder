import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/pill_provider.dart';
import 'services/notification_service.dart';
import 'services/admob_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AdMob 초기화
  await AdMobService().initialize();
  
  // 알림 서비스 초기화
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PillProvider(),
      child: MaterialApp(
        title: '반려동물 알약 알람',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
