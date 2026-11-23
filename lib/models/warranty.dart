const warrantyCategories = <String>[
  'Műszaki',
  'Ruha/Cipő',
  'Háztartás',
  'Egyéb',
];

enum WarrantyStatus { active, expiring, expired }

class Warranty {
  const Warranty({
    required this.id,
    required this.name,
    required this.storeName,
    required this.category,
    required this.purchaseDate,
    required this.warrantyMonths,
    required this.expiryDate,
    required this.price,
    required this.note,
    required this.receiptPath,
    required this.remindersEnabled,
    required this.notificationIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String storeName;
  final String category;
  final DateTime purchaseDate;
  final int? warrantyMonths;
  final DateTime expiryDate;
  final double? price;
  final String note;
  final String? receiptPath;
  final bool remindersEnabled;
  final List<int> notificationIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  int daysRemaining([DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final expiry = DateTime.utc(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return expiry.difference(today).inDays;
  }

  WarrantyStatus get status {
    final remaining = daysRemaining();
    if (remaining < 0) return WarrantyStatus.expired;
    if (remaining <= 30) return WarrantyStatus.expiring;
    return WarrantyStatus.active;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'storeName': storeName,
    'category': category,
    'purchaseDate': _dateKey(purchaseDate),
    'warrantyMonths': warrantyMonths,
    'expiryDate': _dateKey(expiryDate),
    'price': price,
    'note': note,
    'receiptPath': receiptPath,
    'remindersEnabled': remindersEnabled,
    'notificationIds': notificationIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Warranty.fromJson(Map<String, Object?> json) => Warranty(
    id: json['id'] as String,
    name: json['name'] as String,
    storeName: json['storeName'] as String? ?? '',
    category: warrantyCategories.contains(json['category'])
        ? json['category'] as String
        : 'Egyéb',
    purchaseDate: DateTime.parse(json['purchaseDate'] as String),
    warrantyMonths: (json['warrantyMonths'] as num?)?.toInt(),
    expiryDate: DateTime.parse(json['expiryDate'] as String),
    price: (json['price'] as num?)?.toDouble(),
    note: json['note'] as String? ?? '',
    receiptPath: json['receiptPath'] as String?,
    remindersEnabled: json['remindersEnabled'] as bool? ?? false,
    notificationIds: (json['notificationIds'] as List<Object?>? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Warranty copyWith({
    String? id,
    String? receiptPath,
    List<int>? notificationIds,
    DateTime? updatedAt,
  }) => Warranty(
    id: id ?? this.id,
    name: name,
    storeName: storeName,
    category: category,
    purchaseDate: purchaseDate,
    warrantyMonths: warrantyMonths,
    expiryDate: expiryDate,
    price: price,
    note: note,
    receiptPath: receiptPath ?? this.receiptPath,
    remindersEnabled: remindersEnabled,
    notificationIds: notificationIds ?? this.notificationIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static DateTime calculateExpiry(DateTime start, int months) {
    final monthIndex = start.month - 1 + months;
    final year = start.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, start.day > lastDay ? lastDay : start.day);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
