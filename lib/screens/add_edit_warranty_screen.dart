import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/warranty.dart';
import '../services/app_controller.dart';
import '../services/receipt_scanner.dart';
import '../utils/formatters.dart';

class AddEditWarrantyScreen extends StatefulWidget {
  const AddEditWarrantyScreen({
    required this.controller,
    this.existing,
    super.key,
  });

  final AppController controller;
  final Warranty? existing;

  @override
  State<AddEditWarrantyScreen> createState() => _AddEditWarrantyScreenState();
}

class _AddEditWarrantyScreenState extends State<AddEditWarrantyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _scanner = ReceiptScanner();
  late final TextEditingController _nameController;
  late final TextEditingController _storeController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late DateTime _purchaseDate;
  late String _category;
  late bool _remindersEnabled;
  String? _receiptPath;
  String? _scanError;
  DateTime? _customExpiryDate;
  int? _warrantyMonths;
  bool _isScanning = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _storeController = TextEditingController(text: existing?.storeName ?? '');
    _priceController = TextEditingController(
      text: existing?.price?.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _purchaseDate = existing?.purchaseDate ?? DateTime.now();
    _category = existing?.category ?? warrantyCategories.first;
    _remindersEnabled = existing?.remindersEnabled ?? true;
    _receiptPath = existing?.receiptPath;
    _warrantyMonths = existing?.warrantyMonths ?? 12;
    if (existing?.warrantyMonths == null && existing != null) {
      _customExpiryDate = existing.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _expiryDate =>
      _customExpiryDate ??
      Warranty.calculateExpiry(_purchaseDate, _warrantyMonths ?? 12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Új garancia' : 'Szerkesztés'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _sectionTitle(context, 'Számlakép'),
            const SizedBox(height: 10),
            if (_receiptPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 190,
                  child: Image.file(
                    File(_receiptPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text(
                        'A kép nem érhető el. Válassz másikat.',
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _receiptPath = null;
                    _scanError = null;
                  }),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Kép eltávolítása'),
                ),
              ),
            ] else
              Container(
                height: 128,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: const Center(
                  child: Icon(Icons.receipt_long_outlined, size: 42),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving || _isScanning
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Fotózás'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving || _isScanning
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galéria'),
                  ),
                ),
              ],
            ),
            if (_receiptPath != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _isScanning || _isSaving ? null : _scanReceipt,
                icon: _isScanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isScanning
                      ? 'Blokk elemzése folyamatban...'
                      : 'Adatok kiolvasása AI-val',
                ),
              ),
            ],
            if (_scanError != null) ...[
              const SizedBox(height: 8),
              _InlineMessage(message: _scanError!, isError: true),
            ],
            const SizedBox(height: 24),
            _sectionTitle(context, 'Termék adatai'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Termék neve *',
                hintText: 'Például: vezeték nélküli porszívó',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add meg a termék nevét.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _storeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Bolt / üzlet neve',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownMenu<String>(
              initialSelection: _category,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Kategória'),
              dropdownMenuEntries: warrantyCategories
                  .map(
                    (category) =>
                        DropdownMenuEntry(value: category, label: category),
                  )
                  .toList(),
              onSelected: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d., ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Vételár',
                suffixText: 'Ft',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return _parsePrice(value) == null
                    ? 'Adj meg egy érvényes összeget.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Vásárlás dátuma',
              value: formatHungarianDate(_purchaseDate),
              onPressed: _selectPurchaseDate,
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Garancia időtartama'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, months) in const [
                  ('6 hó', 6),
                  ('1 év', 12),
                  ('2 év', 24),
                  ('3 év', 36),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected:
                        _customExpiryDate == null && _warrantyMonths == months,
                    onSelected: (_) => setState(() {
                      _warrantyMonths = months;
                      _customExpiryDate = null;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Egyedi dátum'),
                  selected: _customExpiryDate != null,
                  onSelected: (_) => _selectExpiryDate(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DateButton(
              label: 'Garancia lejárata',
              value: formatHungarianDate(_expiryDate),
              onPressed: _customExpiryDate == null ? null : _selectExpiryDate,
            ),
            const SizedBox(height: 6),
            Text(
              _customExpiryDate == null
                  ? 'A lejárati dátum automatikusan, a vásárlás napjától számolódik.'
                  : 'Egyedi lejárati dátum van beállítva.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emlékeztetők a lejárat előtt'),
              subtitle: const Text('Értesítés 14 és 3 nappal korábban'),
              value: _remindersEnabled,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _remindersEnabled = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Megjegyzés',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Mentés...' : 'Garancia mentése'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800),
  );

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 88);
      if (image == null || !mounted) return;
      setState(() {
        _receiptPath = image.path;
        _scanError = null;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _scanError = 'A kép nem érhető el. Ellenőrizd a kamera vagy a fotókönyvtár engedélyeit.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _scanError = 'A képet nem sikerült megnyitni: $error');
    }
  }

  Future<void> _scanReceipt() async {
    final imagePath = _receiptPath;
    if (imagePath == null) return;
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      final result = await _scanner.scan(imagePath);
      if (!mounted) return;
      setState(() {
        if (result.productName.isNotEmpty) {
          _nameController.text = result.productName;
        }
        if (result.storeName.isNotEmpty) {
          _storeController.text = result.storeName;
        }
        if (result.purchaseDate != null) {
          _purchaseDate = result.purchaseDate!;
        }
        _priceController.text = result.price?.toStringAsFixed(0) ?? '';
        _category = result.suggestedCategory;
        _warrantyMonths = result.suggestedWarrantyMonths;
        _customExpiryDate = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A blokk adatai kiolvasódtak. Ellenőrizd a mezőket.'),
        ),
      );
    } on ReceiptScanException catch (error) {
      if (mounted) setState(() => _scanError = error.message);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _scanError = 'A blokk elemzése nem sikerült: $error');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _selectPurchaseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate.isAfter(now) ? now : _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Vásárlás dátuma',
      cancelText: 'Mégse',
      confirmText: 'Kiválasztás',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _purchaseDate = selected;
      if (_customExpiryDate != null &&
          _customExpiryDate!.isBefore(_purchaseDate)) {
        _customExpiryDate = null;
        _warrantyMonths ??= 12;
      }
    });
  }

  Future<void> _selectExpiryDate() async {
    final earliest = DateTime(
      _purchaseDate.year,
      _purchaseDate.month,
      _purchaseDate.day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _customExpiryDate != null && !_customExpiryDate!.isBefore(earliest)
          ? _customExpiryDate!
          : Warranty.calculateExpiry(_purchaseDate, _warrantyMonths ?? 12),
      firstDate: earliest,
      lastDate: DateTime(2100),
      helpText: 'Garancia lejárata',
      cancelText: 'Mégse',
      confirmText: 'Kiválasztás',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customExpiryDate = selected;
      _warrantyMonths = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final now = DateTime.now();
    final existing = widget.existing;
    final draft = Warranty(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      storeName: _storeController.text.trim(),
      category: _category,
      purchaseDate: _purchaseDate,
      warrantyMonths: _warrantyMonths,
      expiryDate: _expiryDate,
      price: _parsePrice(_priceController.text),
      note: _noteController.text.trim(),
      receiptPath: _receiptPath,
      remindersEnabled: _remindersEnabled,
      notificationIds: existing?.notificationIds ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final saved = await widget.controller.saveWarranty(
        draft,
        previous: existing,
      );
      if (!mounted) return;
      final remindersUnavailable =
          saved.remindersEnabled &&
          saved.daysRemaining() > 3 &&
          saved.notificationIds.isEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remindersUnavailable
                ? 'A garancia mentve. Az emlékeztetőkhöz engedélyezd az értesítéseket.'
                : 'A garancia sikeresen elmentve.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A mentés nem sikerült: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double? _parsePrice(String value) {
    final normalized = value
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      children: [
        const Icon(Icons.calendar_month_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
