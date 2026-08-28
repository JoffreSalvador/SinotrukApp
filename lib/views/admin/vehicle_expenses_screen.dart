import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/payment_math.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Gastos de vehículos con reporte filtrable (realtime).
class VehicleExpensesScreen extends ConsumerStatefulWidget {
  const VehicleExpensesScreen({super.key});

  @override
  ConsumerState<VehicleExpensesScreen> createState() => _VehicleExpensesScreenState();
}

class _VehicleExpensesScreenState extends ConsumerState<VehicleExpensesScreen> {
  bool _byYear = true;
  int _year = DateTime.now().year;
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final from = _byYear ? DateTime(_year) : (_from ?? DateTime(_year));
    final to = _byYear ? DateTime(_year, 12, 31) : (_to ?? DateTime(_year, 12, 31));

    final expensesAsync = ref.watch(vehicleExpensesStreamProvider((from: DateUtilsX.format(from), to: DateUtilsX.format(to))));
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos de vehículos'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDialog(context, ref)),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(vehiclesStreamProvider)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DateFilterBar(
            byYear: _byYear,
            selectedYear: _year,
            from: _from,
            to: _to,
            onModeChanged: (byYear) => setState(() => _byYear = byYear),
            onYearChanged: (y) => setState(() => _year = y),
            onRangeChanged: (r) => setState(() { _from = r.from; _to = r.to; }),
          ),
          const SizedBox(height: 12),
          vehiclesAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (vehicles) {
              if (vehicles.isEmpty) return const SizedBox();
              return _ExpensesList(
                expensesAsync: expensesAsync,
                vehicles: vehicles,
                onDelete: (id) => ref.read(adminRepositoryProvider).deleteVehicleExpense(id),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final vehiclesAsync = ref.read(vehiclesStreamProvider.future);
    final vehicles = await vehiclesAsync;

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registra un vehículo primero (pestaña Flota).')));
      return;
    }
    String? vehicleId = vehicles.first.id;
    final detailCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var date = DateTime.now();

final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo gasto de vehículo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    isDense: true,
                    initialValue: vehicleId,
                    items: vehicles.map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        '${v.brand ?? ''} ${v.model ?? ''} · ${v.plate}'.trim(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (v) => setDlg(() => vehicleId = v),
                    decoration: const InputDecoration(labelText: 'Vehículo'),
                  ),
                ),
              const SizedBox(height: 8),
              UpperCaseTextField(controller: detailCtrl, label: 'Concepto *'),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor *')),
              const SizedBox(height: 8),
              Row(children: [Text('Fecha: ${DateUtilsX.format(date)}'), const Spacer(), TextButton(onPressed: () async { final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setDlg(() => date = picked); }, child: const Text('Cambiar')),]),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))],
        ),
      ),
    );
    if (ok != true) return;

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? -1;
    if (detailCtrl.text.trim().isEmpty || vehicleId == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa vehículo, concepto y valor válido.')));
      return;
    }

    await ref.read(adminRepositoryProvider).addVehicleExpense(VehicleExpense(id: const Uuid().v4(), vehicleId: vehicleId!, expenseDate: DateUtilsX.format(date), detail: detailCtrl.text.trim(), amount: PaymentMath.round2(amount)));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto guardado')));
  }
}

class _ExpensesList extends StatelessWidget {
  const _ExpensesList({
    required this.expensesAsync,
    required this.vehicles,
    required this.onDelete,
  });

  final AsyncValue<List<VehicleExpense>> expensesAsync;
  final List<Vehicle> vehicles;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final vehicleMap = {for (final v in vehicles) v.id: v};

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final expensesByVehicle = <String, List<VehicleExpense>>{};
        for (final e in expenses) {
          expensesByVehicle.putIfAbsent(e.vehicleId, () => []).add(e);
        }

        final total = PaymentMath.sum(expenses.map((e) => e.amount));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatCard(label: 'Total del periodo', value: money(total), color: AppTheme.danger),
            const SizedBox(height: 8),
            ...expensesByVehicle.entries.map((entry) {
              final vehicle = vehicleMap[entry.key];
              final vehicleTotal = PaymentMath.sum(entry.value.map((e) => e.amount));
              final vehicleLabel = vehicle != null
                  ? '${vehicle.brand ?? ''} ${vehicle.model ?? ''} · ${vehicle.plate}'.trim()
                  : entry.key;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Row(children: [
                      Expanded(child: Text(vehicleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Text(money(vehicleTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger)),
                    ]),
                  ),
                  const Divider(height: 1, indent: 16),
                  ...entry.value.map((e) => Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(color: AppTheme.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) => onDelete(e.id),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(e.detail),
                      subtitle: Text(e.expenseDate),
                      trailing: Text(money(e.amount)),
                    ),
                  )),
                ],
              );
            }),
            if (expenses.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin gastos en el periodo'))),
          ],
        );
      },
    );
  }
}