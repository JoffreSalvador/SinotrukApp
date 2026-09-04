import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/payment_math.dart';
import '../../core/utils/reports_calculator.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Pestaña Viajes
class _TripsTab extends ConsumerWidget {
  final ({String from, String to, String? driverId}) range;
  const _TripsTab({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsStreamProvider(range));
    final passengersAsync = ref.watch(passengersStreamProvider);
    final packagesAsync = ref.watch(packagesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final driversAsync = ref.watch(driversStreamProvider);

    return _Async5<Trip, TripPassenger, TripPackage, TripExpense, Profile>(
      a: tripsAsync,
      b: passengersAsync,
      c: packagesAsync,
      d: expensesAsync,
      e: driversAsync,
      builder: (context, trips, passengers, packages, expenses, drivers) {
        final driverNames = {for (final d in drivers) d.id: d.name};
        final rows = ReportsCalculator.byTrip(trips: trips, driverNames: driverNames, passengers: passengers, packages: packages, expenses: expenses);
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final row = rows[i];
            return ExpansionTile(
              leading: const Icon(Icons.local_taxi),
              title: Text('${row.trip.tripDate} · ${row.driverName}'),
              subtitle: Text(row.routeText, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: SizedBox(width: 130, child: Row(children: [
                Expanded(child: Text(money(row.ingreso), style: const TextStyle(color: Colors.green))),
                Expanded(child: Text(money(row.egreso), style: const TextStyle(color: AppTheme.danger))),
              ])),
              children: _buildTripDetail(row),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildTripDetail(TripReportRow row) {
    final widgets = <Widget>[];
    
    // Pasajeros
    if (row.passengers.isNotEmpty) {
      widgets.add(_sectionTitle('Pasajeros (${row.passengers.length})'));
      for (final p in row.passengers) {
        widgets.add(ListTile(
          dense: true,
          leading: const Icon(Icons.person, size: 20),
          title: Text(p.route),
          subtitle: Text('Pago: ${p.paymentMethod}'),
          trailing: Text(money(p.cost), style: const TextStyle(fontWeight: FontWeight.w500)),
        ));
      }
    }
    
    // Encomiendas
    if (row.packages.isNotEmpty) {
      widgets.add(_sectionTitle('Encomiendas (${row.packages.length})'));
      for (final p in row.packages) {
        widgets.add(ListTile(
          dense: true,
          leading: const Icon(Icons.inventory_2, size: 20),
          title: Text(p.route),
          subtitle: Text('Pago: ${p.paymentMethod}'),
          trailing: Text(money(p.cost), style: const TextStyle(fontWeight: FontWeight.w500)),
        ));
      }
    }
    
    // Gastos del viaje
    if (row.expenses.isNotEmpty) {
      widgets.add(_sectionTitle('Gastos del viaje'));
      final expensesByCategory = <String, List<TripExpense>>{};
      for (final e in row.expenses) {
        expensesByCategory.putIfAbsent(e.category, () => []).add(e);
      }
      for (final entry in expensesByCategory.entries) {
        final totalCat = PaymentMath.sum(entry.value.map((e) => e.amount));
        widgets.add(ListTile(
          dense: true,
          leading: const Icon(Icons.receipt, size: 20),
          title: Text(entry.key),
          subtitle: entry.value.length > 1 
              ? Text(entry.value.map((e) => '${e.detail ?? ""}: ${money(e.amount)}').join(', '))
              : null,
          trailing: Text(money(totalCat), style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.danger)),
        ));
      }
      widgets.add(ListTile(
        dense: true,
        title: const Text('Total gastos', style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(money(row.egreso), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger)),
      ));
    }
    
    // Observaciones al final
    if (row.trip.observations != null && row.trip.observations!.isNotEmpty) {
      widgets.add(_sectionTitle('Observaciones'));
      widgets.add(ListTile(
        dense: true,
        leading: const Icon(Icons.note, size: 20),
        title: Text(row.trip.observations!),
      ));
    }
    
    if (widgets.isEmpty) {
      widgets.add(const ListTile(
        dense: true,
        title: Text('Sin detalles adicionales'),
      ));
    }
    
    return widgets;
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Map<String, String> _buildDriverNames(WidgetRef ref) {
    final drivers = ref.read(driversStreamProvider).value ?? [];
    return {for (final d in drivers) d.id: d.name};
  }
}

/// Pestaña Por Conductor
class _DriverTab extends ConsumerWidget {
  final ({String from, String to}) range;
  final String? selectedDriverId;
  final ValueChanged<String?> onDriverChanged;
  const _DriverTab({required this.range, required this.selectedDriverId, required this.onDriverChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromIso = DateUtilsX.format(DateTime.parse(range.from));
    final toIso = DateUtilsX.format(DateTime.parse(range.to));

    final driversAsync = ref.watch(driversStreamProvider);
    final tripsAsync = ref.watch(tripsStreamProvider((from: fromIso, to: toIso, driverId: null)));
    final passengersAsync = ref.watch(passengersStreamProvider);
    final packagesAsync = ref.watch(packagesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return _Async5<Profile, Trip, TripPassenger, TripPackage, TripExpense>(
      a: driversAsync,
      b: tripsAsync,
      c: passengersAsync,
      d: packagesAsync,
      e: expensesAsync,
      builder: (context, drivers, trips, passengers, packages, expenses) {
        if (drivers.isEmpty) return const Center(child: Text('Sin conductores registrados'));
        final driverId = selectedDriverId ?? drivers.first.id;
        return _DriverTabInner(
          driverId: driverId,
          drivers: drivers,
          trips: trips,
          passengers: passengers,
          packages: packages,
          expenses: expenses,
          onDriverChanged: onDriverChanged,
        );
      },
    );
  }
}

class _DriverTabInner extends ConsumerWidget {
  final String driverId;
  final List<Profile> drivers;
  final List<Trip> trips;
  final List<TripPassenger> passengers;
  final List<TripPackage> packages;
  final List<TripExpense> expenses;
  final ValueChanged<String?> onDriverChanged;
  const _DriverTabInner({required this.driverId, required this.drivers, required this.trips, required this.passengers, required this.packages, required this.expenses, required this.onDriverChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverNames = {for (final d in drivers) d.id: d.name};
    final report = ReportsCalculator.byDriver(driverId: driverId, driverNames: driverNames, trips: trips, passengers: passengers, packages: packages, expenses: expenses);
    final totalValue = PaymentMath.sum(report.rows.map((r) => r.tripValue));
    return ListView(padding: const EdgeInsets.all(8), children: [
      DropdownButtonFormField<String>(initialValue: driverId, items: driverNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: onDriverChanged, decoration: const InputDecoration(labelText: 'Conductor')),
      const SizedBox(height: 8),
      ...report.rows.map((r) => ListTile(title: Text(r.route), subtitle: Text('${r.date} · ${r.type}'), trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Viaje: ${money(r.tripValue)}'), Text('Pagado: ${money(r.paidToDriver)}', style: const TextStyle(fontSize: 12))]))),
      Card(color: Theme.of(context).colorScheme.secondaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text('Valor de viajes: ${money(totalValue)}'), const SizedBox(height: 4), Text('TOTAL PAGADO AL CONDUCTOR: ${money(report.totalPaid)}', style: const TextStyle(fontWeight: FontWeight.bold))]))),
    ]);
  }
}

/// Helper widgets for combining multiple AsyncValues
class _Async3<A, B, C> extends ConsumerWidget {
  final AsyncValue<List<A>> a;
  final AsyncValue<List<B>> b;
  final AsyncValue<List<C>> c;
  final Widget Function(BuildContext, List<A>, List<B>, List<C>) builder;
  const _Async3({required this.a, required this.b, required this.c, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (aVal) => b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bVal) => c.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cVal) => builder(context, aVal, bVal, cVal),
        ),
      ),
    );
  }
}

class _Async4<A, B, C, D> extends ConsumerWidget {
  final AsyncValue<List<A>> a;
  final AsyncValue<List<B>> b;
  final AsyncValue<List<C>> c;
  final AsyncValue<List<D>> d;
  final Widget Function(BuildContext, List<A>, List<B>, List<C>, List<D>) builder;
  const _Async4({required this.a, required this.b, required this.c, required this.d, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (aVal) => b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bVal) => c.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cVal) => d.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (dVal) => builder(context, aVal, bVal, cVal, dVal),
          ),
        ),
      ),
    );
  }
}

/// Pestaña Por Rutas
class _RoutesTab extends ConsumerWidget {
  const _RoutesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(passengersStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return _Async2<TripPassenger, TripExpense>(
      a: passengersAsync,
      b: expensesAsync,
      builder: (context, passengers, expenses) {
        final rows = ReportsCalculator.byRoute(passengers: passengers, expenses: expenses);
        return ListView(padding: const EdgeInsets.all(8), children: [
          const ListTile(title: Text('Ruta'), subtitle: Text('Prom. gasolina / ingreso / egreso / neto')),
          ...rows.map((r) => ListTile(dense: true, title: Text(r.route), subtitle: Wrap(spacing: 6, children: [
            Chip(label: Text('Gas: ${money(r.avgGasolina)}')),
            Chip(label: Text('Ing: ${money(r.avgIngreso)}')),
            Chip(label: Text('Egr: ${money(r.avgEgreso)}')),
            Chip(label: Text('Neto: ${money(r.neto)}'), backgroundColor: r.neto >= 0 ? Colors.green.withValues(alpha: .15) : Colors.red.withValues(alpha: .15)),
          ]))),
          if (rows.isEmpty) const Center(child: Text('Sin datos en el periodo')),
        ]);
      },
    );
  }
}

/// Pestaña Detalle Cuentas
class _AccountDetailTab extends ConsumerWidget {
  final ({String from, String to}) range;
  const _AccountDetailTab({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(passengersStreamProvider);
    final packagesAsync = ref.watch(packagesStreamProvider);
    final tripsAsync = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));

    return _Async3<TripPassenger, TripPackage, Trip>(
      a: passengersAsync,
      b: packagesAsync,
      c: tripsAsync,
      builder: (context, passengers, packages, trips) {
        final report = ReportsCalculator.accountDetail(
          passengers: passengers,
          packages: packages,
          trips: trips,
          from: range.from,
          to: range.to,
        );
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            // Sección Empresa
            _buildSection(
              context,
              'Empresa',
              report.empresaPassengers,
              report.empresaPackages,
              report.empresaPassengerTotal,
              report.empresaPackageTotal,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            // Sección Efectivo
            _buildSection(
              context,
              'Efectivo',
              report.efectivoPassengers,
              report.efectivoPackages,
              report.efectivoPassengerTotal,
              report.efectivoPackageTotal,
              Colors.green,
            ),
            const SizedBox(height: 16),
            // Resumen 10%
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Comisión 10% (Pasajeros + Encomiendas)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(money(report.commission10),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<AccountDetailRow> passengers,
    List<AccountDetailRow> packages,
    double passengerTotal,
    double packageTotal,
    Color color,
  ) {
    final total = passengerTotal + packageTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const Spacer(),
            Chip(
              label: Text('Total: ${money(passengerTotal + packageTotal)}'),
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (passengers.isNotEmpty) ...[
          Text('Pasajeros (${passengers.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 4),
          ...passengers.map((p) => ListTile(
            dense: true,
            leading: const Icon(Icons.person, size: 20, color: Colors.blue),
            title: Text(p.detail),
            subtitle: Text(p.date),
            trailing: Text(money(p.value), style: const TextStyle(fontWeight: FontWeight.w500)),
          )),
          const SizedBox(height: 8),
        ],
        if (packages.isNotEmpty) ...[
          Text('Encomiendas (${packages.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 4),
          ...packages.map((p) => ListTile(
            dense: true,
            leading: const Icon(Icons.inventory_2, size: 20, color: Colors.orange),
            title: Text(p.detail),
            subtitle: Text(p.date),
            trailing: Text(money(p.value), style: const TextStyle(fontWeight: FontWeight.w500)),
          )),
          const SizedBox(height: 8),
        ],
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            title: Text('Total $title', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(money(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Pestaña Empresa
class _CompanyTab extends ConsumerWidget {
  final ({String from, String to}) range;
  const _CompanyTab({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));
    final passengersAsync = ref.watch(passengersStreamProvider);
    final packagesAsync = ref.watch(packagesStreamProvider);
    final driversAsync = ref.watch(driversStreamProvider);

    return _Async4<Trip, TripPassenger, TripPackage, Profile>(
      a: tripsAsync,
      b: passengersAsync,
      c: packagesAsync,
      d: driversAsync,
      builder: (context, trips, passengers, packages, drivers) {
        final driverNames = {for (final d in drivers) d.id: d.name};
        final report = ReportsCalculator.byCompany(trips: trips, driverNames: driverNames, passengers: passengers, packages: packages);
        return ListView(padding: const EdgeInsets.all(8), children: [
          ...report.rows.map((r) => ListTile(title: Text(r.route), subtitle: Text('${r.date} · ${r.driverName}'), trailing: Text(money(r.value)))),
          if (report.rows.isEmpty) const Center(child: Text('Sin viajes de empresa en el periodo')),
          Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Text('TOTAL EMPRESA: ${money(report.total)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)))),
        ]);
      },
    );
  }
}

/// Pestaña Ingresos/Egresos
class _IncomeExpenseTab extends ConsumerWidget {
  final ({String from, String to}) range;
  const _IncomeExpenseTab({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(passengersStreamProvider);
    final packagesAsync = ref.watch(packagesStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final vehicleExpensesAsync = ref.watch(vehicleExpensesStreamProvider((from: range.from, to: range.to)));
    final tripsAsync = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));

    return _Async5<TripPassenger, TripPackage, TripExpense, VehicleExpense, Trip>(
      a: passengersAsync,
      b: packagesAsync,
      c: expensesAsync,
      d: vehicleExpensesAsync,
      e: tripsAsync,
      builder: (context, passengers, packages, expenses, vehicleExpenses, trips) {
        final tripDates = {for (final t in trips) t.id: t.tripDate};
        final rows = ReportsCalculator.incomeExpense(passengers: passengers, packages: packages, expenses: expenses, tripDates: tripDates, vehicleExpenses: vehicleExpenses);
        final ingresos = PaymentMath.sum(rows.where((r) => r.isIncome).map((r) => r.value));
        final egresos = PaymentMath.sum(rows.where((r) => !r.isIncome).map((r) => r.value));
        return ListView(padding: const EdgeInsets.all(8), children: [
          Row(children: [
            Expanded(child: StatCard(label: 'Ingresos', value: money(PaymentMath.round2(PaymentMath.sum(rows.where((r) => r.isIncome).map((r) => r.value)))), color: Colors.green)),
            Expanded(child: StatCard(label: 'Egresos', value: money(PaymentMath.round2(PaymentMath.sum(rows.where((r) => !r.isIncome).map((r) => r.value)))), color: AppTheme.danger)),
            Expanded(child: StatCard(label: 'Neto', value: money(PaymentMath.round2(PaymentMath.sum(rows.where((r) => r.isIncome).map((r) => r.value)) - PaymentMath.sum(rows.where((r) => !r.isIncome).map((r) => r.value)))))),
          ]),
          ...rows.map((r) => ListTile(leading: Icon(r.isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: r.isIncome ? Colors.green : AppTheme.danger), title: Text(r.detail), subtitle: Text(r.date), trailing: Text(money(r.value)))),
          if (rows.isEmpty) const Center(child: Text('Sin movimientos en el periodo')),
        ]);
      },
    );
  }
}

class _Async2<A, B> extends ConsumerWidget {
  final AsyncValue<List<A>> a;
  final AsyncValue<List<B>> b;
  final Widget Function(BuildContext, List<A>, List<B>) builder;
  const _Async2({required this.a, required this.b, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (aVal) => b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bVal) => builder(context, aVal, bVal),
      ),
    );
  }
}

class _Async5<A, B, C, D, E> extends ConsumerWidget {
  final AsyncValue<List<A>> a;
  final AsyncValue<List<B>> b;
  final AsyncValue<List<C>> c;
  final AsyncValue<List<D>> d;
  final AsyncValue<List<E>> e;
  final Widget Function(BuildContext, List<A>, List<B>, List<C>, List<D>, List<E>) builder;
  const _Async5({required this.a, required this.b, required this.c, required this.d, required this.e, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (aVal) => b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bVal) => c.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cVal) => d.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (dVal) => e.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (eVal) => builder(context, aVal, bVal, cVal, dVal, eVal),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla principal de reportes
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _byYear = true;
  int _year = DateTime.now().year;
  DateTime? _from;
  DateTime? _to;
  String? _selectedDriverId;

  ({String from, String to}) get _range {
    final from = _byYear ? DateTime(_year) : (_from ?? DateTime(_year));
    final to = _byYear ? DateTime(_year, 12, 31) : (_to ?? DateTime(_year, 12, 31));
    return (from: DateUtilsX.format(from), to: DateUtilsX.format(to));
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {}))],
          bottom: TabBar(isScrollable: true, tabs: const [
            Tab(text: 'Viajes'),
            Tab(text: 'Conductor'),
            Tab(text: 'Detalle cuentas'),
            Tab(text: 'Empresa'),
            Tab(text: 'Ing/Egr'),
          ]),
        ),
        body: Column(children: [
          DateFilterBar(
            byYear: _byYear,
            selectedYear: _year,
            from: _from,
            to: _to,
            onModeChanged: (byYear) { setState(() => _byYear = byYear); },
            onYearChanged: (y) { setState(() => _year = y); },
            onRangeChanged: (r) { setState(() { _from = r.from; _to = r.to; }); },
          ),
          Expanded(
            child: TabBarView(children: [
              _TripsTab(range: (from: _range.from, to: _range.to, driverId: _selectedDriverId)),
              _DriverTab(range: _range, selectedDriverId: _selectedDriverId, onDriverChanged: (v) => setState(() => _selectedDriverId = v)),
              _AccountDetailTab(range: _range),
              _CompanyTab(range: _range),
              _IncomeExpenseTab(range: _range),
            ]),
          ),
        ]),
      ),
    );
  }
}