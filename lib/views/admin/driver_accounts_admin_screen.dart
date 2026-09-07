import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/account_adjustments.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Vista simplificada del ajuste para mostrar en UI.
class _AdjustmentView {
  final bool driverOwes;
  final String headline;
  final String balanceText;
  final String expenses;
  final String received;
  final String cash;
  final String made;

  const _AdjustmentView({
    required this.driverOwes,
    required this.headline,
    required this.balanceText,
    required this.expenses,
    required this.received,
    required this.cash,
    required this.made,
  });

  factory _AdjustmentView.from(DriverAccountAdjustment adj) {
    final balance = adj.balance;
    final driverOwes = balance < 0;
    return _AdjustmentView(
      driverOwes: driverOwes,
      headline: driverOwes ? 'El conductor debe al empleador' : 'El empleador debe al conductor',
      balanceText: money(balance.abs()),
      expenses: money(adj.totalTripExpenses),
      received: money(adj.pagosRecibidos),
      cash: money(adj.viajesEfectivo),
      made: money(adj.pagosRealizados),
    );
  }
}

/// Cuentas de conductores con el empleador (admin, solo lectura).
/// Por defecto muestra los últimos 30 días, con filtro discreto Desde-Hasta.
class DriverAccountsAdminScreen extends ConsumerStatefulWidget {
  const DriverAccountsAdminScreen({super.key});

  @override
  ConsumerState<DriverAccountsAdminScreen> createState() => _DriverAccountsAdminScreenState();
}

class _DriverAccountsAdminScreenState extends ConsumerState<DriverAccountsAdminScreen> {
  String? _selectedDriverId;
  int _limit = 10;

  void _refresh() {
    if (_selectedDriverId == null) return;
    ref.invalidate(driverEntriesStreamProvider(_selectedDriverId!));
    ref.invalidate(driverAdjustmentStreamProvider(
        (driverId: _selectedDriverId!, from: null, to: null)));
    ref.invalidate(passengersStreamProvider);
    ref.invalidate(packagesStreamProvider);
    ref.invalidate(expensesStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas conductores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _refresh,
          ),
        ],
      ),
      body: driversAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando datos...'),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (drivers) {
          if (drivers.isEmpty) {
            return const Center(child: Text('No hay conductores registrados'));
          }

          _selectedDriverId ??= drivers.first.id;
          if (drivers.every((d) => d.id != _selectedDriverId)) {
            _selectedDriverId = drivers.first.id;
          }

          final entriesAsync =
              ref.watch(driverEntriesStreamProvider(_selectedDriverId!));
          final adjAsync = ref.watch(driverAdjustmentStreamProvider(
              (driverId: _selectedDriverId!, from: null, to: null)));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDriverId,
                decoration: const InputDecoration(labelText: 'Conductor', prefixIcon: Icon(Icons.badge)),
                items: drivers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (v) => setState(() => _selectedDriverId = v),
              ),
              const SizedBox(height: 12),
              adjAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Cargando datos...'),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Text('Error ajuste: $e'),
                data: (adj) {
                  final view = _AdjustmentView.from(adj);
                  return Card(
                    color: view.driverOwes
                        ? AppTheme.danger.withValues(alpha: .08)
                        : AppTheme.ok.withValues(alpha: .08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text(view.headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(view.balanceText, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: view.driverOwes ? AppTheme.danger : AppTheme.ok)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                          Chip(label: Text('Gastos: ${view.expenses}')),
                          Chip(label: Text('Recibidos: ${view.received}')),
                          Chip(label: Text('Efectivo: ${view.cash}')),
                          Chip(label: Text('Realizados: ${view.made}')),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Mostrar:'),
                  const SizedBox(width: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 10, label: Text('10')),
                      ButtonSegment(value: 20, label: Text('20')),
                      ButtonSegment(value: 30, label: Text('30')),
                      ButtonSegment(value: 50, label: Text('50')),
                    ],
                    selected: {_limit},
                    onSelectionChanged: (s) => setState(() => _limit = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              entriesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Cargando datos...'),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (entries) {
                  final sorted = entries.toList()
                    ..sort((a, b) => b.txDate.compareTo(a.txDate));
                  final visible = sorted.take(_limit).toList();
                  return Column(
                    children: [
                      if (entries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Últimos ${visible.length} de ${entries.length}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      for (final e in visible)
                        ListTile(
                          leading: Icon(e.isPagoRecibido ? Icons.arrow_downward : Icons.arrow_upward, color: e.isPagoRecibido ? AppTheme.ok : AppTheme.danger),
                          title: Text(e.detail),
                          subtitle: Text('${e.txDate} · ${e.isPagoRecibido ? 'Recibido' : 'Realizado'}'),
                          trailing: Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin movimientos'))),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }


}
