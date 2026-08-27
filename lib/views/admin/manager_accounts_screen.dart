import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/account_adjustments.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/enums.dart';
import '../../core/utils/payment_math.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Cuenta interna admin ↔ gerente (realtime).
class ManagerAccountsScreen extends ConsumerWidget {
  const ManagerAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(managerEntriesStreamProvider);
    final adjAsync = ref.watch(managerAdjustmentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta con el gerente'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(managerAdjustmentProvider)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          adjAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error ajuste: $e'),
            data: (adj) {
              final view = _AdjustmentView.from(adj);
              return Card(
                color: view.managerOwes
                    ? AppTheme.ok.withValues(alpha: .08)
                    : AppTheme.danger.withValues(alpha: .08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text(view.headline, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(view.balanceText, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                      Chip(label: Text('Por cobrar: ${view.cobrar}')),
                      Chip(label: Text('Por pagar: ${view.pagar}')),
                      Chip(label: Text('Realizados: ${view.made}')),
                      Chip(label: Text('Recibidos: ${view.received}')),
                    ]),
                  ]),
                ),
              );
            },
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _showPaymentDialog(context, ref, true), icon: const Icon(Icons.south_west, color: AppTheme.ok), label: const Text('Pago recibido')),
            OutlinedButton.icon(onPressed: () => _showPaymentDialog(context, ref, false), icon: const Icon(Icons.north_east, color: AppTheme.danger), label: const Text('Pago realizado')),
            OutlinedButton.icon(onPressed: () => _showManualDialog(context, ref, true), icon: const Icon(Icons.add_circle_outline, color: AppTheme.ok), label: const Text('+ Por cobrar')),
            OutlinedButton.icon(onPressed: () => _showManualDialog(context, ref, false), icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger), label: const Text('+ Por pagar')),
          ]),
          const Divider(height: 24),
          entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entries) => Column(
              children: [
                for (final e in entries)
                  ListTile(
                    leading: Icon(_iconFor(e), color: _colorFor(e)),
                    title: Text(e.detail),
                    subtitle: Text('${e.txDate} · ${_labelFor(e)}${e.isAutomatic ? " · auto" : ""}'),
                    trailing: Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                if (entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin movimientos'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualDialog(BuildContext context, WidgetRef ref, bool porCobrar) async {
    final detailCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(porCobrar ? 'Nuevo valor por cobrar al gerente' : 'Nuevo valor por pagar al gerente'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        UpperCaseTextField(controller: detailCtrl, label: 'Detalle *'),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor *')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))],
    ));
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? -1;
    if (detailCtrl.text.trim().isEmpty || amount <= 0) return;
    await ref.read(managerAccountRepositoryProvider).addManual(porCobrar: porCobrar, date: DateUtilsX.today(), detail: detailCtrl.text.trim(), amount: amount);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref, bool isRecibido) async {
    final detailCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var date = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      title: Text(isRecibido ? 'Pago recibido del gerente' : 'Pago realizado al gerente'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        UpperCaseTextField(controller: detailCtrl, label: 'Detalle *'),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor *')),
        const SizedBox(height: 8),
        Row(children: [Text('Fecha: ${DateUtilsX.format(date)}'), const Spacer(), TextButton(onPressed: () async { final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setDlg(() => date = picked); }, child: const Text('Cambiar'))]),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))],
    )));
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? -1;
    if (detailCtrl.text.trim().isEmpty || amount <= 0) return;
    await ref.read(managerAccountRepositoryProvider).addEntry(ManagerAccountEntry(id: const Uuid().v4(), txType: isRecibido ? ManagerTxType.pagoRecibido.dbValue : ManagerTxType.pagoRealizado.dbValue, txDate: DateUtilsX.format(date), detail: detailCtrl.text.trim(), amount: amount));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  IconData _iconFor(ManagerAccountEntry e) {
    switch (e.txType) {
      case 'PagoRecibido': return Icons.south_west;
      case 'PagoRealizado': return Icons.north_east;
      case 'ManualPorCobrar': return Icons.add_circle_outline;
      default: return Icons.remove_circle_outline;
    }
  }

  Color _colorFor(ManagerAccountEntry e) => (e.isPorCobrar || e.isPagoRealizado) ? AppTheme.ok : AppTheme.danger;

  String _labelFor(ManagerAccountEntry e) {
    switch (e.txType) {
      case 'PagoRecibido': return 'Pago recibido';
      case 'PagoRealizado': return 'Pago realizado';
      case 'ManualPorCobrar': return 'Por cobrar';
      default: return 'Por pagar';
    }
  }
}

// Provider para el ajuste de cuentas admin-gerente
final managerAdjustmentProvider = FutureProvider.autoDispose<ManagerAccountAdjustment>((ref) async {
  return ref.read(managerAccountRepositoryProvider).adjustment();
});

class _AdjustmentView {
  final String headline;
  final String balanceText;
  final bool managerOwes;
  final String cobrar;
  final String pagar;
  final String made;
  final String received;

  const _AdjustmentView({required this.headline, required this.balanceText, required this.managerOwes, required this.cobrar, required this.pagar, required this.made, required this.received});

  factory _AdjustmentView.from(ManagerAccountAdjustment adj) {
    final fmt = (double v) => money(v);
    return _AdjustmentView(headline: adj.balance > 0 ? 'El gerente le debe al empleador' : adj.balance < 0 ? 'El empleador le debe al gerente' : 'Cuentas parejas', balanceText: fmt(adj.balance.abs()), managerOwes: adj.balance > 0, cobrar: fmt(adj.valoresPorCobrar), pagar: fmt(adj.valoresPorPagar), made: fmt(adj.pagosRealizados), received: fmt(adj.pagosRecibidos));
  }
}