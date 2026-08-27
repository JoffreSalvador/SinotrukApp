import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/enums.dart';
import '../../core/utils/payment_math.dart';
import '../../core/utils/account_adjustments.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/core_providers.dart';
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
class DriverAccountsScreen extends ConsumerWidget {
  const DriverAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).value;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    final entriesAsync = ref.watch(driverEntriesStreamProvider(profile.id));
    final adjAsync = ref.watch(adjustmentProvider(profile.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas con el empleador')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          adjAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
          entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entries) => Column(
              children: [
                for (final e in entries)
                  Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(color: AppTheme.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                    confirmDismiss: (_) async => true,
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref, bool isRecibido) async {
    final profile = ref.read(authStateProvider).value;
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