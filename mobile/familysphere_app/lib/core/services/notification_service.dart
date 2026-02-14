import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final result = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = result ?? false;
      
      // Request permissions on Android 13+
      if (_initialized) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Shows a download complete notification
  Future<void> showDownloadNotification({
    required String fileName,
    required String filePath,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'File download notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      enableLights: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '✅ Download Complete',
        'Saved: $fileName',
        notificationDetails,
        payload: filePath,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Shows a file deletion notification
  Future<void> showDeleteNotification(String fileName) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'file_operations',
      'File Operations',
      channelDescription: 'File operation notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🗑️ File Deleted',
        fileName,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Shows a file rename notification
  Future<void> showRenameNotification(String oldName, String newName) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'file_operations',
      'File Operations',
      channelDescription: 'File operation notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '✏️ File Renamed',
        '$oldName → $newName',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
