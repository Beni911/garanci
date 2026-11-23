import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_controller.dart';
import '../services/notification_service.dart';
import '../services/warranty_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = WarrantyStorage();
  final _apiKeyController = TextEditingController();
  bool _loadingKey = true;
  bool _savingKey = false;
  bool _showKey = false;
  bool _testingNotification = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Text(
            'Beállítások',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Személyre szabás és adatkezelés',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Megjelenés',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Rendszer'),
                        icon: Icon(Icons.settings_suggest_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Világos'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Sötét'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {widget.controller.themeMode},
                    onSelectionChanged: (selection) =>
                        _changeTheme(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI blokkfelismerés',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A Gemini API-kulcsot helyben mentjük. Az elemzéshez a blokk képe a Google Gemini szolgáltatásához kerül továbbításra.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loadingKey)
                    const LinearProgressIndicator()
                  else
                    TextField(
                      controller: _apiKeyController,
                      obscureText: !_showKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Gemini API-kulcs',
                        hintText: 'AIza...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _showKey ? 'Elrejtés' : 'Megjelenítés',
                          onPressed: () => setState(() => _showKey = !_showKey),
                          icon: Icon(
                            _showKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _loadingKey || _savingKey ? null : _saveApiKey,
                      child: Text(
                        _savingKey ? 'Mentés...' : 'API-kulcs mentése',
                      ),
                    ),
                  ),
                  Text(
                    'Ha a kulcsot build-időben adod meg, a --dart-define=GEMINI_API_KEY=... kapcsoló használható.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Értesítések',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ellenőrizd, hogy a készülék engedélyezi-e a GaranciaŐr értesítéseit.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testingNotification
                          ? null
                          : _sendTestNotification,
                      icon: _testingNotification
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: const Text('Tesztértesítés küldése'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biztonsági mentés',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Exportáld a mentett garanciákat JSON-fájlba. A blokkfotók és az API-kulcs nem kerülnek bele az exportba.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportData,
                      icon: _exporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: const Text('Adatok exportálása JSON-be'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'GaranciaŐr · 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadApiKey() async {
    try {
      final key = await _storage.loadGeminiApiKey();
      if (mounted) _apiKeyController.text = key ?? '';
    } on Object catch (error) {
      if (mounted) _showMessage('A kulcs betöltése nem sikerült: $error');
    } finally {
      if (mounted) setState(() => _loadingKey = false);
    }
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    try {
      await widget.controller.setThemeMode(mode);
    } on Object catch (error) {
      if (mounted) _showMessage('A téma mentése nem sikerült: $error');
    }
  }

  Future<void> _saveApiKey() async {
    setState(() => _savingKey = true);
    try {
      await _storage.saveGeminiApiKey(_apiKeyController.text);
      if (mounted) {
        _showMessage(
          _apiKeyController.text.trim().isEmpty
              ? 'A helyben mentett API-kulcs törölve.'
              : 'A Gemini API-kulcs helyben elmentve.',
        );
      }
    } on Object catch (error) {
      if (mounted) _showMessage('A kulcs mentése nem sikerült: $error');
    } finally {
      if (mounted) setState(() => _savingKey = false);
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _testingNotification = true);
    try {
      await NotificationService.instance.sendTestNotification();
      if (mounted) _showMessage('A tesztértesítés elküldve.');
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Az értesítés nem küldhető el: $error');
      }
    } finally {
      if (mounted) setState(() => _testingNotification = false);
    }
  }

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'garanciaor-mentes-${DateTime.now().microsecondsSinceEpoch}.json',
      );
      final data = {
        'formatVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'warranties': widget.controller.warranties.map((warranty) {
          final json = warranty.toJson();
          json.remove('receiptPath');
          json.remove('notificationIds');
          return json;
        }).toList(),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          title: 'GaranciaŐr biztonsági mentés',
          text: 'Mentett garanciák JSON-exportja.',
          files: [
            XFile(
              file.path,
              mimeType: 'application/json',
              name: 'garanciaor-mentes.json',
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) _showMessage('Az exportálás nem sikerült: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
