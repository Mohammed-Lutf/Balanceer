import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:home_widget/home_widget.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize TimeZone
    tz.initializeTimeZones();
    
    // Set local timezone based on device offset
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = (offset.inMinutes % 60).abs();
    final sign = offset.isNegative ? '-' : '+';
    final offsetName = 'Etc/GMT${offset.isNegative ? '+' : '-'}${hours.abs()}';
    
    try {
      tz.setLocalLocation(tz.getLocation(offsetName));
    } catch (e) {
      // Fallback to UTC if location not found
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap logic here if needed
      },
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel',
      'إشعارات عامة',
      channelDescription: 'قناة الإشعارات الأساسية للتطبيق',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> scheduleDailyReminder({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'تذكيرات يومية',
          channelDescription: 'تذكيرات يومية لتسجيل النفقات',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    // Get the local timezone location
    final String timeZoneName = DateTime.now().timeZoneName;
    tz.Location location;
    
    try {
      // Try to get the local timezone
      location = tz.getLocation(timeZoneName);
    } catch (e) {
      // Fallback to UTC offset-based calculation
      location = tz.local;
    }
    
    final tz.TZDateTime now = tz.TZDateTime.now(location);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  Future<void> showPersistentSummary({
    required double totalBudget,
    required double totalSpent,
    required String currency,
  }) async {
    final double remaining = totalBudget - totalSpent;
    final String status = remaining >= 0 ? 'متبقي' : 'متجاوز بـ';
    final String amount = (remaining.abs()).toStringAsFixed(2);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'persistent_summary_channel',
      'ملخص الميزانية المستمر',
      channelDescription: 'يظهر الرصيد المتبقي في لوحة الإشعارات',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      999, // Static ID for the persistent notification
      'مــيزانيتي: $status $amount $currency',
      'إجمالي المصاريف: ${totalSpent.toStringAsFixed(2)} $currency',
      platformDetails,
    );

    // Update Home Widget data as well
    await updateHomeWidget(
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      currency: currency,
    );
  }

  Future<void> updateHomeWidget({
    required double totalBudget,
    required double totalSpent,
    required String currency,
  }) async {
    final double remaining = totalBudget - totalSpent;
    final String amountLabel = remaining.toStringAsFixed(2);

    await HomeWidget.saveWidgetData<String>('amount', amountLabel);
    await HomeWidget.saveWidgetData<String>('currency', currency);
    await HomeWidget.updateWidget(
      androidName: 'BalanceerWidget',
    );
  }

  Future<void> cancelPersistentSummary() async {
    await _notificationsPlugin.cancel(999);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> checkAndNotifyBudgetThreshold({
    required double currentSpent,
    required double totalBudget,
    required String categoryName,
  }) async {
    if (totalBudget <= 0) return;

    double ratio = currentSpent / totalBudget;

    if (ratio >= 1.0) {
      await showNotification(
        id: categoryName.hashCode,
        title: 'تنبيه الميزانية: $categoryName ⚠️',
        body: 'لقد تجاوزت الميزانية المحددة لـ $categoryName!',
      );
    } else if (ratio >= 0.8) {
      await showNotification(
        id: categoryName.hashCode,
        title: 'تنبيه الميزانية: $categoryName 🔔',
        body: 'لقد استهلكت أكثر من 80% من ميزانية $categoryName.',
      );
    }
  }
}
