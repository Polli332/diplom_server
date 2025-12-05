import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BKM Service',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

// Конфигурация админа
class AdminConfig {
  static const String adminUsername = 'admin';
  static const String adminPassword = 'admin';
  static const String defaultApiUrl = 'http://localhost:3000';
}

// Конфигурация приложения
class AppConfig {
  static String apiUrl = 'http://localhost:3000';
  
  static void updateApiUrl(String newUrl) {
    apiUrl = newUrl;
  }
}