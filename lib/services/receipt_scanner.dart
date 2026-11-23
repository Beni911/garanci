import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/warranty.dart';
import 'warranty_storage.dart';

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.productName,
    required this.storeName,
    required this.purchaseDate,
    required this.price,
    required this.suggestedCategory,
    required this.suggestedWarrantyMonths,
  });

  final String productName;
  final String storeName;
  final DateTime? purchaseDate;
  final double? price;
  final String suggestedCategory;
  final int suggestedWarrantyMonths;
}

class ReceiptScanner {
  ReceiptScanner({WarrantyStorage? storage, http.Client? client})
    : _storage = storage ?? WarrantyStorage(),
      _client = client ?? http.Client();

  static const _environmentKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const _legacyEnvironmentKey = String.fromEnvironment(
    'EXPO_PUBLIC_GEMINI_API_KEY',
    defaultValue: '',
  );
  static const _model = 'gemini-2.5-flash';

  final WarrantyStorage _storage;
  final http.Client _client;

  static const _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'productName': {
        'type': 'STRING',
        'description': 'A fő megvásárolt termék rövid neve; több tételnél a legdrágább vagy legjellemzőbb tartós cikk.',
      },
      'storeName': {'type': 'STRING'},
      'purchaseDate': {
        'type': 'STRING',
        'nullable': true,
        'description': 'YYYY-MM-DD dátum vagy null, ha nem olvasható ki.',
      },
      'price': {
        'type': 'NUMBER',
        'nullable': true,
        'description': 'A termék ára egész forintban vagy null.',
      },
      'suggestedCategory': {'type': 'STRING', 'enum': warrantyCategories},
      'suggestedWarrantyMonths': {
        'type': 'INTEGER',
        'description': 'A terméktípus és az ár alapján becsült hónapok száma.',
      },
    },
    'required': [
      'productName',
      'storeName',
      'purchaseDate',
      'price',
      'suggestedCategory',
      'suggestedWarrantyMonths',
    ],
  };

  static const _prompt = '''
Olvasd le a mellékelt magyar nyelvű blokkot vagy számlát. Csak a kért JSON-sémának megfelelő adatokat add vissza.
A productName a fő megvásárolt termék rövid neve legyen. Több tétel esetén a legdrágább vagy legjellemzőbb műszaki/tartós cikket válaszd, ne a blokk végösszegét.
A storeName az üzlet vagy webshop neve legyen; ha nem olvasható, üres szöveg.
A purchaseDate csak egyértelműen olvasható vásárlási dátum esetén legyen YYYY-MM-DD, egyébként null.
A price a kiválasztott termék ára legyen egész forintban, ne a blokk végösszege, ha a tételár azonosítható; bizonytalanság esetén null.
A suggestedCategory kizárólag Műszaki, Ruha/Cipő, Háztartás vagy Egyéb lehet.
A suggestedWarrantyMonths a termék ára és típusa szerinti magyarországi gyakorlat alapján adott becslés legyen, például 12, 24 vagy 36 hónap. Ez csak becslés, nem jogi tanács.
Ha a kép nem nyugta/számla vagy nem olvasható, a productName legyen üres szöveg, storeName legyen üres szöveg, purchaseDate és price legyen null, a kategória Egyéb, a becslés pedig 12 hónap.
''';

  Future<ReceiptScanResult> scan(String imagePath) async {
    final storedKey = await _storage.loadGeminiApiKey();
    final apiKey = (storedKey?.trim().isNotEmpty ?? false)
        ? storedKey!.trim()
        : _environmentKey.trim().isNotEmpty
        ? _environmentKey.trim()
        : _legacyEnvironmentKey.trim();
    if (apiKey.isEmpty) {
      throw const ReceiptScanException(
        'Nincs Gemini API-kulcs beállítva. Add meg a Beállításokban, vagy buildeld az alkalmazást '
        '--dart-define=GEMINI_API_KEY=... kapcsolóval.',
      );
    }

    late final String base64Image;
    try {
      final bytes = await File(imagePath).readAsBytes();
      if (bytes.isEmpty) {
        throw const ReceiptScanException(
          'A kiválasztott kép üres. Készíts vagy válassz egy jól látható blokkfotót.',
        );
      }
      base64Image = base64Encode(bytes);
    } on ReceiptScanException {
      rethrow;
    } on FileSystemException {
      throw const ReceiptScanException(
        'A képet nem sikerült beolvasni. Válassz ki egy másik fotót.',
      );
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inlineData': {
                        'mimeType': _mimeType(imagePath),
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
                'responseSchema': _responseSchema,
              },
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const ReceiptScanException(
        'Az elemzés túl sokáig tartott. Ellenőrizd a kapcsolatot, majd próbáld újra.',
      );
    } on SocketException {
      throw const ReceiptScanException(
        'Nem sikerült kapcsolódni az AI-szolgáltatáshoz. Ellenőrizd az internetkapcsolatot.',
      );
    } on http.ClientException {
      throw const ReceiptScanException(
        'Nem sikerült kapcsolódni az AI-szolgáltatáshoz. Ellenőrizd az internetkapcsolatot.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ReceiptScanException(
        'A Gemini API-kulcs érvénytelen vagy nem használható. Ellenőrizd a Beállításokban.',
      );
    }
    if (response.statusCode == 429) {
      throw const ReceiptScanException(
        'Az AI-szolgáltatás elérte a használati korlátot. Próbáld újra később.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ReceiptScanException(
        'A blokk elemzése nem sikerült. Próbáld újra egy élesebb képpel.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final text = _responseText(decoded);
      if (text == null) {
        throw const ReceiptScanException(
          'A blokk adatai nem voltak kiolvashatók. Próbálj élesebb, teljes blokkfotót készíteni.',
        );
      }
      final result = jsonDecode(text);
      return _validateResult(result);
    } on ReceiptScanException {
      rethrow;
    } on FormatException {
      throw const ReceiptScanException(
        'Az AI válasza nem volt feldolgozható. Próbáld újra egy élesebb képpel.',
      );
    }
  }

  String _mimeType(String path) {
    final extension = path.split('?').first.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  String? _responseText(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) return null;
    final content = candidate['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    return parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .join()
        .trim();
  }

  ReceiptScanResult _validateResult(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ReceiptScanException(
        'A blokk adatai nem megfelelő formátumban érkeztek.',
      );
    }
    final productName = (value['productName'] as String? ?? '').trim();
    if (productName.isEmpty) {
      throw const ReceiptScanException(
        'A termék nem volt olvasható a képen. Próbálj élesebb, teljes blokkfotót készíteni.',
      );
    }

    final category = value['suggestedCategory'];
    if (category is! String || !warrantyCategories.contains(category)) {
      throw const ReceiptScanException(
        'A blokk elemzése nem adott érvényes termékkategóriát. Próbáld újra.',
      );
    }

    final months = value['suggestedWarrantyMonths'];
    if (months is! num || months.toInt() < 1 || months.toInt() > 120) {
      throw const ReceiptScanException(
        'A jótállás becsült időtartama nem volt érvényes. Ellenőrizd kézzel a mezőt.',
      );
    }

    final dateText = value['purchaseDate'];
    final parsedDate = dateText is String ? DateTime.tryParse(dateText) : null;
    final purchaseDate = parsedDate != null && _dateKey(parsedDate) == dateText
        ? DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
        : null;
    final priceValue = value['price'];
    final price = priceValue is num && priceValue >= 0
        ? priceValue.toDouble()
        : null;

    return ReceiptScanResult(
      productName: productName,
      storeName: (value['storeName'] as String? ?? '').trim(),
      purchaseDate: purchaseDate,
      price: price,
      suggestedCategory: category,
      suggestedWarrantyMonths: months.toInt(),
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
