import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/pill.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // 알림 탭 처리
  }

  Future<void> schedulePillNotification(
    Pill pill,
    DateTime scheduledTime,
  ) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'pill_reminder',
        '알약 알림',
        channelDescription: '알약 복용 시간을 알려주는 알림',
        importance: Importance.high,
        priority: Priority.high,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        pill.id ?? 0,
        '알약 복용 시간',
        '${pill.name} 복용 시간입니다.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: pill.id.toString(),
      );
    } catch (e) {
      // 알림 스케줄링 실패 처리
    }
  }

  Future<void> cancelPillNotification(int pillId) async {
    try {
      await _notifications.cancel(pillId);
    } catch (e) {
      // 알림 취소 실패 처리
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // 모든 알림 취소 실패 처리
    }
  }

  Future<void> scheduleTestNotification() async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'test',
        '테스트 알림',
        channelDescription: '테스트용 알림',
        importance: Importance.high,
        priority: Priority.high,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        999,
        '테스트 알림',
        '이것은 테스트 알림입니다.',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // 테스트 알림 스케줄링 실패 처리
    }
  }

  Future<void> scheduleDelayedTestNotification() async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'delayed_test',
        '지연 테스트 알림',
        channelDescription: '지연 테스트용 알림',
        importance: Importance.high,
        priority: Priority.high,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        998,
        '지연 테스트 알림',
        '이것은 지연 테스트 알림입니다.',
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // 지연 테스트 알림 스케줄링 실패 처리
    }
  }

  Future<void> scheduleAllPillNotifications(List<Pill> pills) async {
    for (final pill in pills) {
      if (!pill.isActive) continue;

      try {
        // 기존 알림 취소
        await cancelPillNotification(pill.id ?? 0);

        // 알람 시간들을 DateTime으로 변환
        final alarmTimes = pill.alarmTimes.map((timeStr) {
          final parts = timeStr.split(':');
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          );
        }).toList();

        // 시작일부터 90일간 알림 스케줄링
        final startDate = DateTime(
          pill.startDate.year,
          pill.startDate.month,
          pill.startDate.day,
        );

        for (int day = 0; day < 90; day++) {
          final currentDate = startDate.add(Duration(days: day));

          // 복용 주기에 따른 확인
          bool shouldTake = false;
          switch (pill.frequency) {
            case 'daily':
              shouldTake = true;
              break;
            case 'weekly':
              final daysSinceStart = currentDate.difference(startDate).inDays;
              shouldTake = daysSinceStart % 7 == 0;
              break;
            case 'monthly':
              shouldTake = currentDate.day == startDate.day;
              break;
            case 'custom':
              if (pill.customDays != null) {
                final daysSinceStart = currentDate.difference(startDate).inDays;
                shouldTake = daysSinceStart % pill.customDays! == 0;
              }
              break;
          }

          if (shouldTake) {
            for (final alarmTime in alarmTimes) {
              final scheduledTime = DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                alarmTime.hour,
                alarmTime.minute,
              );

              if (scheduledTime.isAfter(DateTime.now())) {
                await schedulePillNotification(pill, scheduledTime);
              }
            }
          }
        }
      } catch (e) {
        // 개별 알약 알림 스케줄링 실패 처리
      }
    }
  }

  Future<void> cancelNotificationsForDate(DateTime date) async {
    try {
      // 특정 날짜의 알림을 취소하는 로직
      // 여기서는 모든 알림을 취소하고 다시 스케줄링하는 방식 사용
      await cancelAllNotifications();
    } catch (e) {
      // 날짜별 알림 취소 실패 처리
    }
  }
}
