import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/warranty.dart';

class WarrantyStorage {
  static const _warrantiesKey = 'garanciaor.warranties.v1';
  static const _themeKey = 'garanciaor.theme.v1';
  static const _geminiKey = 'garanciaor.geminiApiKey.v1';
  static final _random = Random.secure();

  Future<List<Warranty>> loadWarranties() async {
    final preferences = await SharedPreferences.getInstance();
    final contents = preferences.getString(_warrantiesKey);
    if (contents == null || contents.isEmpty) return [];

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('A mentett garanciák formátuma érvénytelen.');
    }

    try {
      return decoded
          .map(
            (item) => Warranty.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
    } on Object {
      throw const FormatException(
        'A mentett garanciák adatai nem olvashatók. Exportálás előtt ne töröld az alkalmazás adatait.',
      );
    }
  }

  Future<void> saveWarranties(List<Warranty> warranties) async {
    final preferences = await SharedPreferences.getInstance();
    final contents = jsonEncode(
      warranties.map((item) => item.toJson()).toList(),
    );
    if (!await preferences.setString(_warrantiesKey, contents)) {
      throw StateError('A garanciákat nem sikerült elmenteni a készülékre.');
    }
  }

  Future<String> persistReceipt(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'A kiválasztott számlakép már nem érhető el.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final receipts = Directory(
      '${documents.path}${Platform.pathSeparator}receipts',
    );
    await receipts.create(recursive: true);
    final receiptPrefix = '${receipts.path}${Platform.pathSeparator}';
    if (sourcePath.startsWith(receiptPrefix)) return sourcePath;

    final sourceName = source.uri.pathSegments.isEmpty
        ? 'szamla.jpg'
        : source.uri.pathSegments.last;
    final extension = sourceName.contains('.')
        ? sourceName.substring(sourceName.lastIndexOf('.'))
        : '.jpg';
    final destination = File(
      '${receipts.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}$extension',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> deleteReceipt(String? path) async {
    if (path == null || path.isEmpty) return;
    final documents = await getApplicationDocumentsDirectory();
    final receiptPrefix =
        '${documents.path}${Platform.pathSeparator}receipts${Platform.pathSeparator}';
    if (!path.startsWith(receiptPrefix)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<String> loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_themeKey) ?? 'system';
  }

  Future<void> saveTheme(String theme) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_themeKey, theme)) {
      throw StateError('A témabeállítást nem sikerült elmenteni.');
    }
  }

  Future<String?> loadGeminiApiKey() async {
    final preferences = await SharedPreferences.getInstance();
    final key = preferences.getString(_geminiKey)?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  Future<void> saveGeminiApiKey(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = key.trim();
    if (normalized.isEmpty) {
      await preferences.remove(_geminiKey);
    } else if (!await preferences.setString(_geminiKey, normalized)) {
      throw StateError('A Gemini API-kulcsot nem sikerült elmenteni.');
    }
  }
}
