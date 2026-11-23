import 'package:material_ui/material_ui.dart';

import '../models/warranty.dart';
import '../services/app_controller.dart';
import '../widgets/warranty_card.dart';
import 'warranty_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, required this.onAdd, super.key});

  final AppController controller;
  final VoidCallback onAdd;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _filters = ['Összes', ...warrantyCategories];
  String _query = '';
  String _category = 'Összes';

  @override
  Widget build(BuildContext context) {
    final all = widget.controller.warranties;
    final activeCount = all.where((item) => item.daysRemaining() >= 0).length;
    final expiringCount = all
        .where(
          (item) => item.daysRemaining() >= 0 && item.daysRemaining() <= 30,
        )
        .length;
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = all.where((item) {
      final matchesCategory =
          _category == 'Összes' || item.category == _category;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.storeName.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList()..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final theme = Theme.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GaranciaŐr',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Szia! 👋',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Minden blokk biztonságban.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    value: '$activeCount',
                    label: 'Aktív garanciák',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    value: '$expiringCount',
                    label: '30 napon belül lejár',
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Keresés termékre vagy üzletre',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Kategória',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _category == filter,
                      onSelected: (_) => setState(() => _category = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mentett garanciák',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${filtered.length} termék',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.controller.loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.controller.loadError != null)
              _LoadError(
                message: widget.controller.loadError!,
                onRetry: widget.controller.refresh,
              )
            else if (filtered.isEmpty)
              _EmptyState(hasItems: all.isNotEmpty, onAdd: widget.onAdd)
            else
              ...filtered.map(
                (warranty) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WarrantyCard(
                    warranty: warranty,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WarrantyDetailScreen(
                          controller: widget.controller,
                          warranty: warranty,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasItems, required this.onAdd});

  final bool hasItems;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 38,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasItems ? 'Nincs találat' : 'Még nincs mentett garanciád',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasItems ? 'Próbálj más keresést vagy kategóriát.' : 'Add hozzá az első számládat, hogy ne vesszen el a garancia.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!hasItems) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Új garancia'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Újrapróbálás')),
        ],
      ),
    ),
  );
}
