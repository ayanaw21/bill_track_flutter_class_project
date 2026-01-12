import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  Future<void> scheduleBillReminder(String id, String category, DateTime dueDate) async {
    // Calculate 2 days before the due date at 9:00 AM
    final scheduleDate = dueDate.subtract(const Duration(days: 2));
    final finalTime = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day, 9, 0);

    // Ensure we don't schedule in the past
    if (finalTime.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id.hashCode, // Unique ID for the notification
      'Bill Reminder: $category',
      'Your bill of is due in 2 days!',
      tz.TZDateTime.from(finalTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders', 'Bill Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}