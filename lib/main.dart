import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for modern edge-to-edge look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize KhubSojaDoc primary directory immediately on launch
  try {
    await StorageService().getAppDirectory();
  } catch (_) {}

  runApp(const KhubSojaDocApp());
}

class KhubSojaDocApp extends StatelessWidget {
  const KhubSojaDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhubSojaDoc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
