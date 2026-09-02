import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'new_trip_screen.dart';

/// Reporte de viajes del chofer (solo los suyos).
/// Por defecto muestra los viajes de la fecha actual.
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
  DateTime _date = DateTime.now();
  bool _loading = true;
  List<_TripReport> _reports = [];

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
    final dateIso = DateUtilsX.format(_date);
    final trips = await repo.tripsOfDriver(profile.id, from: dateIso, to: dateIso);
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _date = picked;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis viajes · ${DateUtilsX.format(_date)}'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('Sin viajes en esta fecha'))
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
                              Text('Viaje ${report.trip.tripDate}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Chip(label: Text('${report.passengerCount} pax · ${report.packageCount} enc.')),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NewTripScreen()))
            .then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo viaje'),
      ),
    );
  }
}