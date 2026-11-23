import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../models/warranty.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import 'add_edit_warranty_screen.dart';

class WarrantyDetailScreen extends StatefulWidget {
  const WarrantyDetailScreen({
    required this.controller,
    required this.warranty,
    super.key,
  });

  final AppController controller;
  final Warranty warranty;

  @override
  State<WarrantyDetailScreen> createState() => _WarrantyDetailScreenState();
}

class _WarrantyDetailScreenState extends State<WarrantyDetailScreen> {
  late Warranty _warranty;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _warranty = widget.warranty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _warranty.daysRemaining();
    final (statusColor, statusLabel) = switch (_warranty.status) {
      WarrantyStatus.active => (Colors.green.shade600, 'Érvényes'),
      WarrantyStatus.expiring => (Colors.orange.shade700, 'Hamarosan lejár'),
      WarrantyStatus.expired => (Colors.red.shade600, 'Lejárt'),
    };
    final remainingText = days < 0
        ? 'A garancia ${days.abs()} napja lejárt'
        : days == 0
        ? 'A garancia ma jár le'
        : '$days nap van hátra a garanciából';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garancia részletei'),
        actions: [
          IconButton(
            tooltip: 'Szerkesztés',
            onPressed: _isDeleting ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Törlés',
            onPressed: _isDeleting ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _warranty.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_warranty.storeName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _warranty.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          days < 0
                              ? 'Lejárt'
                              : days == 0
                              ? 'Ma lejár'
                              : '$days',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          days < 0 || days == 0
                              ? remainingText
                              : 'nap van hátra',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Vásárlási adatok',
            children: [
              _DetailRow(label: 'Kategória', value: _warranty.category),
              _DetailRow(
                label: 'Vásárlás dátuma',
                value: formatHungarianDate(_warranty.purchaseDate),
              ),
              _DetailRow(
                label: 'Garancia lejárata',
                value: formatHungarianDate(_warranty.expiryDate),
              ),
              _DetailRow(
                label: 'Időtartam',
                value: _warranty.warrantyMonths == null
                    ? 'Egyedi lejárati dátum'
                    : '${_warranty.warrantyMonths} hónap',
              ),
              if (_warranty.price != null)
                _DetailRow(
                  label: 'Vételár',
                  value: formatForint(_warranty.price!),
                ),
              _DetailRow(
                label: 'Emlékeztetők',
                value: _warranty.remindersEnabled
                    ? 'Bekapcsolva'
                    : 'Kikapcsolva',
              ),
            ],
          ),
          if (_warranty.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Megjegyzés',
              children: [
                Text(_warranty.note, style: theme.textTheme.bodyLarge),
              ],
            ),
          ],
          if (_warranty.receiptPath != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Számlakép',
              trailing: IconButton(
                tooltip: 'Megosztás',
                onPressed: _shareReceipt,
                icon: const Icon(Icons.share_outlined),
              ),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Image.file(
                      File(_warranty.receiptPath!),
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        alignment: Alignment.center,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Text('A számlakép nem érhető el.'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _shareReceipt,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Számla megosztása'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _isDeleting ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Garancia szerkesztése'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddEditWarrantyScreen(
          controller: widget.controller,
          existing: _warranty,
        ),
      ),
    );
    if (!mounted) return;
    for (final item in widget.controller.warranties) {
      if (item.id == _warranty.id) {
        setState(() => _warranty = item);
        break;
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Garancia törlése?'),
        content: const Text(
          'A termék adatai és a hozzá tartozó számlakép törlődni fognak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await widget.controller.deleteWarranty(_warranty);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A törlés nem sikerült: $error')),
        );
      }
    }
  }

  Future<void> _shareReceipt() async {
    final path = _warranty.receiptPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException(
          'A számlakép nem található a készüléken.',
        );
      }
      await SharePlus.instance.share(
        ShareParams(
          title: 'Számla – ${_warranty.name}',
          text: 'Számla a következő termékhez: ${_warranty.name}',
          files: [XFile(path, mimeType: 'image/jpeg')],
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A számlát nem sikerült megosztani: $error')),
        );
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
