import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/payment_math.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

/// Resumen general de un rango de fechas del chofer:
/// pasajeros, encomiendas, ingresos y egresos.
class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  bool _byYear = true;
  int _year = DateTime.now().year;
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  _SummaryData _data = const _SummaryData(0, 0, 0, 0);

  static const _empty = _SummaryData(0, 0, 0, 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final from = _byYear ? DateTime(_year) : (_from ?? DateTime(_year));
    final to = _byYear ? DateTime(_year, 12, 31) : (_to ?? DateTime(_year, 12, 31));

    try {
      final summary = await ref.read(tripRepositoryProvider).rangeSummary(
            profile.id,
            from: DateUtilsX.format(from),
            to: DateUtilsX.format(to),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen por rango')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DateFilterBar(
            byYear: _byYear,
            selectedYear: _year,
            from: _from,
            to: _to,
            onModeChanged: (byYear) {
              setState(() => _byYear = byYear);
              if (!byYear) return;
              _load();
            },
            onYearChanged: (year) {
              setState(() => _year = year);
              _load();
            },
            onRangeChanged: (r) { setState(() { _from = r.from; _to = r.to; }); _load(); },
          ),
          const SizedBox(height: 12),
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
}

class _SummaryData {
  final int passengers;
  final int packages;
  final double ingresos;
  final double egresos;

  const _SummaryData(this.passengers, this.packages, this.ingresos, this.egresos);
}
