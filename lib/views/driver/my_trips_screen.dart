import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'new_trip_screen.dart';

/// Reporte de viajes del chofer (solo los suyos).
/// Por defecto muestra los últimos 10 viajes, con filtro discreto Desde-Hasta.
class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _TripReport {
  final Trip trip;
  final List<TripPassenger> passengers;
  final List<TripPackage> packages;
  final List<TripExpense> expenses;

  _TripReport(this.trip, this.passengers, this.packages, this.expenses);

  int get passengerCount => passengers.length;
  int get packageCount => packages.length;
  double get totalIncome => passengers.fold(0.0, (sum, p) => sum + p.cost) + packages.fold(0.0, (sum, p) => sum + p.cost);
  double get totalExpenses => expenses.fold(0.0, (sum, e) => sum + e.amount);
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  DateTime? _from;
  DateTime? _to;
  DateTime? _draftFrom;
  DateTime? _draftTo;
  bool _showFilter = false;
  bool _loading = true;
  List<_TripReport> _reports = [];

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
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;
    final repo = ref.read(tripRepositoryProvider);
    List<Trip> trips;
    if (_hasFilter) {
      trips = await repo.tripsOfDriver(
        profile.id,
        from: DateUtilsX.format(_from!),
        to: DateUtilsX.format(_to!),
      );
    } else {
      // Por defecto: últimos 10 viajes (ya vienen ordenados por fecha desc).
      trips = (await repo.tripsOfDriver(profile.id)).take(10).toList();
    }
    final reports = <_TripReport>[];
    for (final trip in trips) {
      final passengers = await repo.passengersOf(trip.id);
      final packages = await repo.packagesOf(trip.id);
      final expenses = await repo.expensesOf(trip.id);
      reports.add(_TripReport(trip, passengers, packages, expenses));
    }
    if (mounted) {
      setState(() { _reports = reports; _loading = false; });
    }
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

  void _editTrip(_TripReport report) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => NewTripScreen(
            editingTrip: report.trip,
            editingPassengers: report.passengers,
            editingPackages: report.packages,
            editingExpenses: report.expenses,
          ),
        ))
        .then((_) => _load());
  }

  Future<void> _deleteTrip(_TripReport report) async {
    if (!report.trip.isEditable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo se puede eliminar dentro de las 24 horas de creado')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar viaje'),
        content: Text(
            '¿Eliminar el viaje del ${report.trip.tripDate} con sus pasajeros, encomiendas y gastos?'),
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
    if (ok != true) return;
    try {
      await ref.read(tripRepositoryProvider).deleteTrip(report.trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje eliminado')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasFilter
            ? 'Mis viajes · ${DateUtilsX.format(_from!)} al ${DateUtilsX.format(_to!)}'
            : 'Mis viajes · Últimos 10'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list,
                color: _hasFilter ? AppTheme.button : null),
            tooltip: 'Filtrar por fechas',
            onPressed: () => setState(() => _showFilter = !_showFilter),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilter) _filterCard(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(
                        child: Text(_hasFilter
                            ? 'Sin viajes en el rango'
                            : 'Sin viajes registrados'))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _reports.length,
                  itemBuilder: (_, i) {
                    final report = _reports[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text('Viaje ${report.trip.tripDate}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Chip(label: Text('${report.passengerCount} pax · ${report.packageCount} enc.')),
                              if (report.trip.isEditable)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: 'Opciones',
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _editTrip(report);
                                    } else if (v == 'delete') {
                                      _deleteTrip(report);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit_outlined),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ]),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline, color: AppTheme.danger),
                                        SizedBox(width: 8),
                                        Text('Eliminar'),
                                      ]),
                                    ),
                                  ],
                                ),
                            ]),
                            const Divider(),
                            if (report.passengers.isNotEmpty) ...[
                              const Text('Pasajeros:', style: TextStyle(fontWeight: FontWeight.w600)),
                              ...report.passengers.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(children: [
                                      Expanded(child: Text(p.route)),
                                      SizedBox(
                                        width: 90,
                                        child: Text(money(p.cost),
                                            textAlign: TextAlign.right),
                                      ),
                                      SizedBox(
                                        width: 84,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Chip(
                                            label: Text(p.paymentMethod,
                                                style:
                                                    const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ),
                                    ]),
                                  )),
                            ],
                            if (report.packages.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Encomiendas:', style: TextStyle(fontWeight: FontWeight.w600)),
                              ...report.packages.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(children: [
                                      Expanded(child: Text(p.route)),
                                      SizedBox(
                                        width: 90,
                                        child: Text(money(p.cost),
                                            textAlign: TextAlign.right),
                                      ),
                                      SizedBox(
                                        width: 84,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Chip(
                                            label: Text(p.paymentMethod,
                                                style:
                                                    const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ),
                                    ]),
                                  )),
                            ],
                            if (report.expenses.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Gastos:', style: TextStyle(fontWeight: FontWeight.w600)),
                              ...report.expenses.map((e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(children: [
                                      Expanded(child: Text(e.category)),
                                      SizedBox(
                                        width: 90,
                                        child: Text('-${money(e.amount)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(color: Colors.red)),
                                      ),
                                    ]),
                                  )),
                            ],
                            if (report.trip.observations != null && report.trip.observations!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(report.trip.observations!),
                            ],
                            if (report.passengers.isEmpty && report.packages.isEmpty && report.expenses.isEmpty)
                              const Text('Sin datos registrados'),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ingresos: ${money(report.totalIncome)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Gastos: ${money(report.totalExpenses)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                Text('Neto: ${money(report.totalIncome - report.totalExpenses)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NewTripScreen()))
            .then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo viaje'),
      ),
    );
  }

  Widget _filterCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                            setState(() {
                              _from = null;
                              _to = null;
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