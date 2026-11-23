import 'dart:io';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/warranty.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  static const _channelId = 'garancia_emlekeztetok';
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Random _random = Random.secure();
  bool _initialized = false;

  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localZone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    final initialized = await _plugin.initialize(settings: settings);
    if (initialized != true) {
      throw StateError('A helyi értesítések inicializálása nem sikerült.');
    }
    _initialized = true;
  }

  Future<List<int>> scheduleWarrantyReminders(Warranty warranty) async {
    if (!warranty.remindersEnabled) return [];
    _ensureInitialized();
    if (!await _requestPermissions()) return [];

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Garanciaemlékeztetők',
        channelDescription: 'Értesítések a garanciák lejárata előtt.',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );

    final ids = <int>[];
    try {
      for (final daysBefore in [14, 3]) {
        final localDate = DateTime(
          warranty.expiryDate.year,
          warranty.expiryDate.month,
          warranty.expiryDate.day - daysBefore,
          9,
        );
        if (!localDate.isAfter(DateTime.now())) continue;

        final id = _newNotificationId();
        await _plugin.zonedSchedule(
          id: id,
          title: 'Hamarosan lejár a garancia',
          body: 'A(z) ${warranty.name} garanciája $daysBefore nap múlva lejár.',
          scheduledDate: timezone.TZDateTime.from(localDate, timezone.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: warranty.id,
        );
        ids.add(id);
      }
      return ids;
    } on Object {
      await cancel(ids);
      rethrow;
    }
  }

  Future<void> cancel(List<int> ids) async {
    if (ids.isEmpty) return;
    _ensureInitialized();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> sendTestNotification() async {
    _ensureInitialized();
    if (!await _requestPermissions()) {
      throw StateError('Az értesítési engedély nincs megadva.');
    }
    await _plugin.show(
      id: _newNotificationId(),
      title: 'GaranciaŐr teszt',
      body: 'A helyi értesítések megfelelően működnek.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Garanciaemlékeztetők',
          channelDescription: 'Értesítések a garanciák lejárata előtt.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  int _newNotificationId() => _random.nextInt(0x7ffffffe) + 1;

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Az értesítési szolgáltatás még nincs inicializálva.');
    }
  }
}
