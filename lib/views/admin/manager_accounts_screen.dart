import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/account_adjustments.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Cuenta interna admin ↔ gerente (realtime).
class ManagerAccountsScreen extends ConsumerStatefulWidget {
  const ManagerAccountsScreen({super.key});

  @override
  ConsumerState<ManagerAccountsScreen> createState() => _ManagerAccountsScreenState();
}

class _ManagerAccountsScreenState extends ConsumerState<ManagerAccountsScreen> {
  String _filter = 'Todos';
  DateTime? _from;
  DateTime? _to;
  DateTime? _draftFrom;
  DateTime? _draftTo;
  bool _showFilter = false;

  bool get _hasFilter => _from != null && _to != null;

  @override
  Widget build(BuildContext context) {
    final from = _from ?? DateTime(DateTime.now().year);
    final to = _to ?? DateTime(DateTime.now().year, 12, 31);
    final range = (from: DateUtilsX.format(from), to: DateUtilsX.format(to));

    final entriesAsync = ref.watch(managerCombinedEntriesProvider(range));
    final adjAsync = ref.watch(managerAdjustmentStreamProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta C. Gato'), actions: [
        IconButton(
          icon: Icon(Icons.filter_list,
              color: (_showFilter || _hasFilter) ? AppTheme.button : null),
          tooltip: 'Filtrar por fechas',
          onPressed: () => setState(() => _showFilter = !_showFilter),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recargar',
          onPressed: () {
            ref.invalidate(managerEntriesStreamProvider);
            ref.invalidate(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));
            ref.invalidate(passengersStreamProvider);
            ref.invalidate(packagesStreamProvider);
            ref.invalidate(driversStreamProvider);
            ref.invalidate(vehiclesStreamProvider);
            ref.invalidate(assignmentsStreamProvider);
          },
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AnimatedFilterPanel(
            expanded: _showFilter,
            child: Column(
              children: [
                Card(
                  margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isDense: true,
                      value: _filter,
                      decoration: const InputDecoration(labelText: 'Filtrar pagos'),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'Recibidos', child: Text('Recibidos')),
                        DropdownMenuItem(value: 'Realizados', child: Text('Realizados')),
                        DropdownMenuItem(value: 'Por cobrar', child: Text('Por cobrar')),
                        DropdownMenuItem(value: 'Por pagar', child: Text('Por pagar')),
                      ],
                      onChanged: (v) => setState(() => _filter = v ?? 'Todos'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: context, initialDate: _draftFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (picked != null) setState(() => _draftFrom = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Desde', prefixIcon: Icon(Icons.date_range)),
                              child: Text(_draftFrom != null ? DateUtilsX.format(_draftFrom!) : 'Seleccionar'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: context, initialDate: _draftTo ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (picked != null) setState(() => _draftTo = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Hasta', prefixIcon: Icon(Icons.date_range)),
                              child: Text(_draftTo != null ? DateUtilsX.format(_draftTo!) : 'Seleccionar'),
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
                            onPressed: _canApplyDateFilter
                                ? () => setState(() { _from = _draftFrom; _to = _draftTo; })
                                : null,
                            icon: const Icon(Icons.filter_alt),
                            label: const Text('Filtrar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _canClearDateFilter
                                ? () => setState(() { _from = null; _to = null; _draftFrom = null; _draftTo = null; })
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
            ),
            const SizedBox(height: 12),
              ],
            ),
          ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Chip(label: Text('Por cobrar: ${view.cobrar}')),
                              const SizedBox(height: 6),
                              Chip(label: Text('Realizados: ${view.made}')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Chip(label: Text('Por pagar: ${view.pagar}')),
                              const SizedBox(height: 6),
                              Chip(label: Text('Recibidos: ${view.received}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              );
            },
          ),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton.icon(onPressed: () => _showPaymentDialog(context, ref, true), icon: const Icon(Icons.south_west, color: AppTheme.ok), label: const Text('Pago recibido')),
            OutlinedButton.icon(onPressed: () => _showPaymentDialog(context, ref, false), icon: const Icon(Icons.north_east, color: AppTheme.danger), label: const Text('Pago realizado')),
            OutlinedButton.icon(onPressed: () => _showManualDialog(context, ref, true), icon: const Icon(Icons.add_circle_outline, color: AppTheme.ok), label: const Text('+ Por cobrar')),
            OutlinedButton.icon(onPressed: () => _showManualDialog(context, ref, false), icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger), label: const Text('+ Por pagar')),
          ]),
          const Divider(height: 24),
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
              final filtered = _filterEntries(entries);
              // Más reciente arriba; a igualdad de fecha, el creado primero
              // va abajo (sin fecha de creación conocida va al final).
              final sorted = filtered.toList()
                ..sort((a, b) {
                  final byDate = b.txDate.compareTo(a.txDate);
                  if (byDate != 0) return byDate;
                  final ac = a.createdAt;
                  final bc = b.createdAt;
                  if (ac == null && bc == null) {
                    return a.id.compareTo(b.id);
                  }
                  if (ac == null) return 1;
                  if (bc == null) return -1;
                  final byCreated = bc.compareTo(ac);
                  return byCreated != 0
                      ? byCreated
                      : a.id.compareTo(b.id);
                });
              // Solo se limita lo mostrado (últimos 50); el cálculo del
              // cuadro superior siempre abarca todo el alcance vigente.
              const displayLimit = 50;
              final visible = sorted.take(displayLimit).toList();
              return Column(
                children: [
                  if (sorted.length > visible.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Últimos ${visible.length} de ${sorted.length}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
for (final e in visible)
                      e.isAutomatic
                          ? ListTile(
                              leading: Icon(_iconFor(e), color: _colorFor(e)),
                              title: Text(e.detail),
                              subtitle: Text('${e.txDate} · ${_labelFor(e)} · auto'),
                              trailing: Text(money(e.amount), style: TextStyle(fontWeight: FontWeight.w600, color: _amountColor(e))),
                            )
                          : Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDelete(context, ref, e.id),
                              background: Container(color: AppTheme.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                              child: ListTile(
                                leading: Icon(_iconFor(e), color: _colorFor(e)),
                                title: Text(e.detail),
                                subtitle: Text('${e.txDate} · ${_labelFor(e)}'),
                                trailing: Text(money(e.amount), style: TextStyle(fontWeight: FontWeight.w600, color: _amountColor(e))),
                              ),
                            ),
                  if (visible.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin movimientos'))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool get _canApplyDateFilter =>
      _draftFrom != null &&
      _draftTo != null &&
      !_draftFrom!.isAfter(_draftTo!) &&
      (_draftFrom != _from || _draftTo != _to);

  bool get _canClearDateFilter =>
      _draftFrom != null ||
      _draftTo != null ||
      _from != null ||
      _to != null;

  List<ManagerAccountEntry> _filterEntries(List<ManagerAccountEntry> entries) {
    switch (_filter) {
      case 'Recibidos':
        return entries.where((e) => e.isPagoRecibido).toList();
      case 'Realizados':
        return entries.where((e) => e.isPagoRealizado).toList();
      case 'Por cobrar':
        return entries.where((e) => e.isPorCobrar).toList();
      case 'Por pagar':
        return entries.where((e) => e.txType == 'ManualPorPagar').toList();
      default:
        return entries;
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar movimiento'),
      content: const Text('¿Seguro que deseas eliminar este registro?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx, true);
          await ref.read(managerAccountRepositoryProvider).deleteEntry(id);
        }, child: const Text('Eliminar')),
      ],
    ));
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

  Color _amountColor(ManagerAccountEntry e) {
    // A favor (verde): Por cobrar, Pago recibido
    // En contra (rojo): Por pagar, Pago realizado
    return (e.isPorCobrar || e.isPagoRecibido) ? AppTheme.ok : AppTheme.danger;
  }

  String _labelFor(ManagerAccountEntry e) {
    switch (e.txType) {
      case 'PagoRecibido': return 'Pago recibido';
      case 'PagoRealizado': return 'Pago realizado';
      case 'ManualPorCobrar': return 'Por cobrar';
      default: return 'Por pagar';
    }
  }
}

// Provider para el ajuste de cuentas admin-gerente (legacy, mantenido por compatibilidad)
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