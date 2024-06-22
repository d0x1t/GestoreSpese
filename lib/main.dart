import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/theme_notifier.dart';
import 'dart:async';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';

ThemeData initialTheme = ThemeData.dark(); // Tema predefinito scuro

void main() async {
  // Assicuriamo che i servizi dei plugin siano inizializzati
  WidgetsFlutterBinding.ensureInitialized();

  // Carichiamo il tema prima che l'app si avvii
  initialTheme = await loadThemePreference(); // carichiamo il tema prima che si avvii l'app

  // Inizializziamo le notifiche
  {
    WidgetsFlutterBinding.ensureInitialized();
    NotificationService notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestIOSPermissions();
    await notificationService.requestAndroidPermissions();
  }

  // Avviamo l'app
  runApp(const MyApp());
}

// Funzione per caricare le preferenze del tema
Future<ThemeData> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  bool isDarkMode = prefs.getBool('darkModeEnabled') ?? true;
  return isDarkMode ? ThemeData.dark() : ThemeData.light();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeNotifier(initialTheme),
      child: const MaterialAppWithTheme(),
    );
  }
}

class MaterialAppWithTheme extends StatelessWidget {
  const MaterialAppWithTheme({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'Gestione Spese',
      theme: themeNotifier.themeData,
      home: const DashboardScreen(),
    );
  }
}
