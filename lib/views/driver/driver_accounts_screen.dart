import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/enums.dart';
import '../../core/utils/payment_math.dart';
import '../../core/utils/account_adjustments.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
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
      balanceText: '\$${balance.abs().toStringAsFixed(2)}',
      expenses: '\$${adj.totalTripExpenses.toStringAsFixed(2)}',
      received: '\$${adj.pagosRecibidos.toStringAsFixed(2)}',
      cash: '\$${adj.viajesEfectivo.toStringAsFixed(2)}',
      made: '\$${adj.pagosRealizados.toStringAsFixed(2)}',
    );
  }
}

/// Cuentas del chofer con el empleador (realtime).
/// Por defecto muestra los últimos 30 días, con filtro discreto Desde-Hasta.
class DriverAccountsScreen extends ConsumerStatefulWidget {
  const DriverAccountsScreen({super.key});

  @override
  ConsumerState<DriverAccountsScreen> createState() =>
      _DriverAccountsScreenState();
}

class _DriverAccountsScreenState extends ConsumerState<DriverAccountsScreen> {
  int _limit = 10;
  DateTime? _from;
  DateTime? _to;
  DateTime? _draftFrom;
  DateTime? _draftTo;
  bool _showFilter = false;

  bool get _hasFilter => _from != null && _to != null;

  bool get _canApplyFilter =>
      _draftFrom != null &&
      _draftTo != null &&
      !_draftFrom!.isAfter(_draftTo!) &&
      (_draftFrom != _from || _draftTo != _to);

  bool get _canClearFilter =>
      _draftFrom != null ||
      _draftTo != null ||
      _from != null ||
      _to != null;

  Future<void> _pickDraftDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_draftFrom ?? DateTime.now())
          : (_draftTo ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _draftFrom = picked;
        } else {
          _draftTo = picked;
        }
      });
    }
  }

  void _refresh(String driverId) {
    ref.invalidate(driverEntriesStreamProvider(driverId));
    ref.invalidate(driverAdjustmentStreamProvider(
        (driverId: driverId, from: null, to: null)));
    ref.invalidate(passengersStreamProvider);
    ref.invalidate(packagesStreamProvider);
    ref.invalidate(expensesStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).valueOrNull;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    final entriesAsync = ref.watch(driverEntriesStreamProvider(profile.id));
    final adjAsync = ref.watch(driverAdjustmentStreamProvider((
      driverId: profile.id,
      from: _from == null ? null : DateUtilsX.format(_from!),
      to: _to == null ? null : DateUtilsX.format(_to!),
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas con el empleador'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list,
                color: (_showFilter || _hasFilter) ? AppTheme.button : null),
            tooltip: 'Filtrar por fechas',
            onPressed: () => setState(() => _showFilter = !_showFilter),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => _refresh(profile.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AnimatedFilterPanel(expanded: _showFilter, child: _filterCard()),
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
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _addEntry(context, ref, true), icon: const Icon(Icons.south_west, color: AppTheme.ok), label: const Text('Recibido'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _addEntry(context, ref, false), icon: const Icon(Icons.north_east, color: AppTheme.danger), label: const Text('Realizado'))),
          ]),
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
              final inScope = _hasFilter
                  ? entries
                      .where((e) =>
                          e.txDate.compareTo(DateUtilsX.format(_from!)) >= 0 &&
                          e.txDate.compareTo(DateUtilsX.format(_to!)) <= 0)
                      .toList()
                  : entries.toList();
              final sorted = inScope
                ..sort((a, b) => b.txDate.compareTo(a.txDate));
              final visible = sorted.take(_limit).toList();
              return Column(
                children: [
                  if (sorted.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Últimos ${visible.length} de ${sorted.length}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  for (final e in visible)
                    Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(color: AppTheme.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                      confirmDismiss: (_) async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar movimiento'),
                            content: const Text('¿Seguro que deseas eliminar este registro?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        return ok == true;
                      },
                      onDismissed: (_) async {
                        await ref.read(driverAccountRepositoryProvider).deleteEntry(e.id);
                      },
                      child: ListTile(
                        leading: Icon(e.isPagoRecibido ? Icons.arrow_downward : Icons.arrow_upward, color: e.isPagoRecibido ? AppTheme.ok : AppTheme.danger),
                        title: Text(e.detail),
                        subtitle: Text('${e.txDate} · ${e.isPagoRecibido ? 'Recibido' : 'Realizado'}'),
                        trailing: Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin movimientos'))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDraftDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Desde', prefixIcon: Icon(Icons.date_range)),
                      child: Text(_draftFrom != null
                          ? DateUtilsX.format(_draftFrom!)
                          : 'Seleccionar'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDraftDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Hasta', prefixIcon: Icon(Icons.date_range)),
                      child: Text(_draftTo != null
                          ? DateUtilsX.format(_draftTo!)
                          : 'Seleccionar'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canApplyFilter
                        ? () => setState(() {
                              _from = _draftFrom;
                              _to = _draftTo;
                            })
                        : null,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Filtrar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canClearFilter
                        ? () => setState(() {
                              _from = null;
                              _to = null;
                              _draftFrom = null;
                              _draftTo = null;
                            })
                        : null,
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref, bool isRecibido) async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final detailCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var date = DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isRecibido ? 'Nuevo pago recibido' : 'Nuevo pago realizado', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                UpperCaseTextField(controller: detailCtrl, label: 'Detalle'),
                const SizedBox(height: 8),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor')),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Fecha: ${DateUtilsX.format(date)}'),
                  const Spacer(),
                  TextButton(onPressed: () async { final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setSheetState(() => date = picked); }, child: const Text('Cambiar')),
                ]),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? -1;
    if (detailCtrl.text.trim().isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detalle y valor válido son obligatorios')));
      return;
    }

    await ref.read(driverAccountRepositoryProvider).addEntry(DriverAccountEntry(
          id: const Uuid().v4(),
          driverId: profile.id,
          txType: isRecibido ? DriverTxType.pagoRecibido.dbValue : DriverTxType.pagoRealizado.dbValue,
          txDate: DateUtilsX.format(date),
          detail: detailCtrl.text.trim(),
          amount: PaymentMath.round2(amount),
        ));
  }
}
