import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

// Classe che gestisce le notifiche locali
class NotificationService {
  // Singleton pattern per garantire un'unica istanza della classe
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  static const channelId = "1";

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Dettagli delle notifiche per Android
  static const AndroidNotificationDetails _androidNotificationDetails =
      AndroidNotificationDetails(
    channelId,
    "notifications",
    channelDescription:
        "This channel is responsible for all the local notifications",
    playSound: true,
    priority: Priority.high,
    importance: Importance.high,
  );

  // Dettagli delle notifiche per iOS
  static const DarwinNotificationDetails _iOSNotificationDetails =
      DarwinNotificationDetails();

  static const NotificationDetails notificationDetails = NotificationDetails(
    android: _androidNotificationDetails,
    iOS: _iOSNotificationDetails,
  );

  // Richiede il permesso per le notifiche (Android 13+)
  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      // Permesso già concesso
    } else {
      // Richiedi permesso
      await Permission.notification.request();
    }
  }

  // Inizializza le notifiche locali
  Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings("ic_notification");

    await requestNotificationPermission();

    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings(
          defaultPresentAlert: false,
          defaultPresentBadge: false,
          defaultPresentSound: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: iOSInitializationSettings,
        );

    tz.initializeTimeZones();

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings
    );
  }

  // Richiede permessi specifici per Android
  Future<void> requestAndroidPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Richiede permessi specifici per iOS
  Future<void> requestIOSPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Pianifica una notifica periodica
  Future<void> schedulePeriodicNotification(
      {int id = 0,
      String? title,
      String? body,
      required RepeatInterval interval,
      String? payLoad}) async {
    await flutterLocalNotificationsPlugin.periodicallyShow(
      0,
      title,
      body,
      interval,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }
}
