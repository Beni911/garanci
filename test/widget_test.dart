import 'package:flutter_test/flutter_test.dart';
import 'package:garancia_or/models/warranty.dart';

void main() {
  group('Warranty', () {
    test('calculates month-end expiry dates without overflowing', () {
      expect(
        Warranty.calculateExpiry(DateTime(2025, 1, 31), 1),
        DateTime(2025, 2, 28),
      );
      expect(
        Warranty.calculateExpiry(DateTime(2024, 1, 31), 1),
        DateTime(2024, 2, 29),
      );
    });

    test('round-trips warranty data through JSON', () {
      final warranty = Warranty(
        id: 'test-id',
        name: 'Kávéfőző',
        storeName: 'Minta üzlet',
        category: 'Háztartás',
        purchaseDate: DateTime(2025, 1, 10),
        warrantyMonths: 24,
        expiryDate: DateTime(2027, 1, 10),
        price: 49990,
        note: 'Teszt megjegyzés',
        receiptPath: null,
        remindersEnabled: true,
        notificationIds: [17, 18],
        createdAt: DateTime(2025, 1, 10, 12),
        updatedAt: DateTime(2025, 1, 11, 12),
      );

      final decoded = Warranty.fromJson(warranty.toJson());
      expect(decoded.toJson(), warranty.toJson());
    });

    test('counts expiry days by calendar date', () {
      final warranty = Warranty(
        id: 'test-id',
        name: 'Telefon',
        storeName: '',
        category: 'Műszaki',
        purchaseDate: DateTime(2025, 1, 1),
        warrantyMonths: 12,
        expiryDate: DateTime(2025, 2, 11),
        price: null,
        note: '',
        receiptPath: null,
        remindersEnabled: false,
        notificationIds: const [],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(warranty.daysRemaining(DateTime(2025, 2, 10, 23, 59)), 1);
      expect(warranty.daysRemaining(DateTime(2025, 2, 11, 0, 1)), 0);
      expect(warranty.daysRemaining(DateTime(2025, 2, 12)), -1);
    });
  });
}
