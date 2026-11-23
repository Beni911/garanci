import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../models/warranty.dart';
import 'notification_service.dart';
import 'warranty_storage.dart';

class AppController extends ChangeNotifier {
  AppController({WarrantyStorage? storage, NotificationService? notifications})
    : _storage = storage ?? WarrantyStorage(),
      _notifications = notifications ?? NotificationService.instance;

  final WarrantyStorage _storage;
  final NotificationService _notifications;
  final Random _random = Random.secure();

  List<Warranty> warranties = [];
  ThemeMode themeMode = ThemeMode.system;
  bool loading = true;
  String? loadError;

  Future<void> initialize() async {
    try {
      final savedWarranties = await _storage.loadWarranties();
      final savedTheme = await _storage.loadTheme();
      warranties = savedWarranties;
      themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      loadError = null;
    } catch (error) {
      loadError = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.saveTheme(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    themeMode = mode;
    notifyListeners();
  }

  Future<Warranty> saveWarranty(Warranty draft, {Warranty? previous}) async {
    String? receiptPath = draft.receiptPath;
    if (receiptPath != null) {
      receiptPath = await _storage.persistReceipt(receiptPath);
    }

    final id =
        previous?.id ??
        (draft.id.trim().isNotEmpty
            ? draft.id
            : '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 24)}');
    final withReceipt = draft.copyWith(
      id: id,
      receiptPath: receiptPath,
      updatedAt: DateTime.now(),
    );
    late final List<int> reminderIds;
    try {
      reminderIds = await _notifications.scheduleWarrantyReminders(withReceipt);
    } catch (_) {
      if (receiptPath != null && receiptPath != previous?.receiptPath) {
        await _storage.deleteReceipt(receiptPath);
      }
      rethrow;
    }
    final saved = withReceipt.copyWith(notificationIds: reminderIds);
    final next = previous == null
        ? [saved, ...warranties]
        : warranties
              .map((item) => item.id == previous.id ? saved : item)
              .toList();

    try {
      await _storage.saveWarranties(next);
    } catch (_) {
      await _notifications.cancel(reminderIds);
      if (receiptPath != null && receiptPath != previous?.receiptPath) {
        await _storage.deleteReceipt(receiptPath);
      }
      rethrow;
    }

    warranties = next;
    notifyListeners();
    if (previous != null) {
      await _notifications.cancel(previous.notificationIds);
      if (previous.receiptPath != saved.receiptPath) {
        await _storage.deleteReceipt(previous.receiptPath);
      }
    }
    return saved;
  }

  Future<void> deleteWarranty(Warranty warranty) async {
    await _notifications.cancel(warranty.notificationIds);
    final next = warranties.where((item) => item.id != warranty.id).toList();
    await _storage.saveWarranties(next);
    await _storage.deleteReceipt(warranty.receiptPath);
    warranties = next;
    notifyListeners();
  }

  Future<void> refresh() {
    loading = true;
    loadError = null;
    notifyListeners();
    return initialize();
  }
}
