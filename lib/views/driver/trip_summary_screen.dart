import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/payment_math.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

/// Resumen general de un rango de fechas del chofer:
/// pasajeros, encomiendas, ingresos y egresos.
/// Por defecto muestra los últimos 30 días, con filtro discreto Desde-Hasta.
class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  DateTime? _from;
  DateTime? _to;
  DateTime? _draftFrom;
  DateTime? _draftTo;
  bool _showFilter = false;
  bool _loading = true;
  _SummaryData _data = const _SummaryData(0, 0, 0, 0);

  static const _empty = _SummaryData(0, 0, 0, 0);

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

  @override
  void initState() {
    super.initState();
    // Sin filtro personalizado: por defecto se muestra el mes presente.
    _load();
  }

  /// Etiqueta del periodo mostrado: "Septiembre de 2026" o rango si cruza meses.
  String get _periodLabel {
    final fallback = DateUtilsX.currentMonth();
    final from = _from ?? fallback.from;
    final to = _to ?? fallback.to;
    final fromLabel = DateUtilsX.monthYearLabel(from);
    if (from.year == to.year && from.month == to.month) return fromLabel;
    return '$fromLabel - ${DateUtilsX.monthYearLabel(to)}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final range = DateUtilsX.currentMonth();
    final from = DateUtilsX.format(_from ?? range.from);
    final to = DateUtilsX.format(_to ?? range.to);

    try {
      final summary = await ref.read(tripRepositoryProvider).rangeSummary(
            profile.id,
            from: from,
            to: to,
          );
      _data = _SummaryData(
        summary.passengerCount,
        summary.packageCount,
        summary.ingresos,
        summary.egresos,
      );
    } catch (_) {
      _data = _empty;
    }
    if (mounted) setState(() => _loading = false);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Resumen'),
            Text(
              _periodLabel,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
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
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AnimatedFilterPanel(expanded: _showFilter, child: _filterCard()),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Row(children: [
              Expanded(
                child: StatCard(
                    label: 'Pasajeros', value: '${_data.passengers}'),
              ),
              Expanded(
                child: StatCard(
                    label: 'Encomiendas', value: '${_data.packages}'),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: StatCard(
                    label: 'Ingresos',
                    value: money(PaymentMath.round2(_data.ingresos)),
                    color: Theme.of(context).colorScheme.primary),
              ),
              Expanded(
                child: StatCard(
                    label: 'Egresos',
                    value: money(PaymentMath.round2(_data.egresos)),
                    color: Theme.of(context).colorScheme.error),
              ),
            ]),
            const SizedBox(height: 8),
            StatCard(
              label: 'Neto (ingresos - egresos)',
              value: money(PaymentMath.round2(_data.ingresos - _data.egresos)),
            ),
          ],
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
                        ? () {
                            setState(() {
                              _from = _draftFrom;
                              _to = _draftTo;
                            });
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Filtrar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canClearFilter
                        ? () {
                            final range = DateUtilsX.currentMonth();
                            setState(() {
                              _from = range.from;
                              _to = range.to;
                              _draftFrom = null;
                              _draftTo = null;
                            });
                            _load();
                          }
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
}

class _SummaryData {
  final int passengers;
  final int packages;
  final double ingresos;
  final double egresos;

  const _SummaryData(this.passengers, this.packages, this.ingresos, this.egresos);
}
