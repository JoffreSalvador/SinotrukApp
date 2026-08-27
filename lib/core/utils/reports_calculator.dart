import 'payment_math.dart';
import '../../models/models.dart';

/// Motor de reportes del administrador.
/// Toda la logica opera sobre colecciones Dart (pura y testeable).
class ReportsCalculator {
  /// Reporte 1: Por Viajes.
  /// Fecha, conductor, ruta(s), ingreso (pasajeros sin importar el tipo)
  /// y egreso (gasolina + conductor + peajes + otros) por cada viaje.
  static List<TripReportRow> byTrip({
    required List<Trip> trips,
    required Map<String, String> driverNames,
    required List<TripPassenger> passengers,
    required List<TripExpense> expenses,
  }) =>
      trips.map((trip) {
        final tripPax =
            passengers.where((p) => p.tripId == trip.id).toList();
        final tripExp =
            expenses.where((e) => e.tripId == trip.id).toList();
        return TripReportRow(
          trip: trip,
          driverName: driverNames[trip.driverId] ?? trip.driverId,
          routes: tripPax.map((p) => p.route).toList(),
          ingreso: PaymentMath.sum(tripPax.map((p) => p.cost)),
          egreso: PaymentMath.sum(tripExp.map((e) => e.amount)),
        );
      }).toList();

  /// Reporte 2: Por conductor.
  /// Filas fecha/ruta/valor/valor-pagado-al-conductor + total pagado.
  static DriverReport byDriver({
    required String driverId,
    required Map<String, String> driverNames,
    required List<Trip> trips,
    required List<TripPassenger> passengers,
    required List<TripExpense> expenses,
  }) {
    final rows = <DriverReportRow>[];
    for (final trip in trips.where((t) => t.driverId == driverId)) {
      final paidToDriver = PaymentMath.sum(expenses
          .where((e) => e.tripId == trip.id && e.category == 'Conductor')
          .map((e) => e.amount));
      for (final p in passengers.where((p) => p.tripId == trip.id)) {
        rows.add(DriverReportRow(
          date: trip.tripDate,
          route: p.route,
          tripValue: p.cost,
          paidToDriver: paidToDriver,
        ));
      }
    }
    return DriverReport(
      driverName: driverNames[driverId] ?? driverId,
      rows: rows,
      totalPaid: PaymentMath.sum(rows.map((r) => r.paidToDriver)),
    );
  }

  /// Reporte 3: Por rutas.
  /// Promedios de gasolina / ingreso / egreso y neto por ruta.
  static List<RouteReportRow> byRoute({
    required List<TripPassenger> passengers,
    required List<TripExpense> expenses,
  }) {
    final routes = passengers
        .map((p) => p.route)
        .toSet();
    final result = <RouteReportRow>[];

    for (final route in routes) {
      final tripsOfRoute = passengers
          .where((p) => p.route == route)
          .map((p) => p.tripId)
          .toSet();

      final gasByTrip = <String, double>{};
      final expByTrip = <String, double>{};
      for (final tripId in tripsOfRoute) {
        gasByTrip[tripId] = PaymentMath.sum(expenses
            .where((e) => e.tripId == tripId && e.category == 'Gasolina')
            .map((e) => e.amount));
        expByTrip[tripId] = PaymentMath.sum(
            expenses.where((e) => e.tripId == tripId).map((e) => e.amount));
      }

      final avgGas = _avg(gasByTrip.values);
      final avgIncome = _avg([for (final t in tripsOfRoute)
        PaymentMath.sum(passengers
            .where((p) => p.route == route && p.tripId == t)
            .map((p) => p.cost))]);
      final avgExpense = _avg(expByTrip.values);

      result.add(RouteReportRow(
        route: route,
        avgGasolina: avgGas,
        avgIngreso: avgIncome,
        avgEgreso: avgExpense,
        neto: PaymentMath.round2(avgIncome - avgExpense),
      ));
    }
    return result;
  }

  /// Reporte 4: Empresa.
  /// Viajes con pago Empresa: fecha, ruta individual, conductor, valor.
  static CompanyReport byCompany({
    required List<Trip> trips,
    required Map<String, String> driverNames,
    required List<TripPassenger> passengers,
    required List<TripPackage> packages,
  }) {
    final rows = <CompanyReportRow>[];
    double total = 0;

    void addRows(Iterable<({String tripId, String departure, String arrival, double cost})> items) {
      for (final item in items) {
        final trip = trips.where((t) => t.id == item.tripId).firstOrNull;
        if (trip == null) continue;
        total += item.cost;
        rows.add(CompanyReportRow(
          date: trip.tripDate,
          route: '${item.departure} -> ${item.arrival}',
          driverName: driverNames[trip.driverId] ?? trip.driverId,
          value: item.cost,
        ));
      }
    }

    addRows(passengers
        .where((p) => p.paymentMethod == 'Empresa')
        .map((p) => (tripId: p.tripId, departure: p.departure,
            arrival: p.arrival, cost: p.cost)));
    addRows(packages
        .where((p) => p.paymentMethod == 'Empresa')
        .map((p) => (tripId: p.tripId, departure: p.departure,
            arrival: p.arrival, cost: p.cost)));

    return CompanyReport(rows: rows, total: PaymentMath.round2(total));
  }

  /// Reporte 5: Ingresos/Egresos.
  /// Ingresos: pasajeros y encomiendas. Egresos: gastos de viaje y vehiculo.
  static List<IncomeExpenseRow> incomeExpense({
    required List<TripPassenger> passengers,
    required List<TripPackage> packages,
    required List<TripExpense> expenses,
    required Map<String, String> tripDates,
    required List<VehicleExpense> vehicleExpenses,
  }) {
    final rows = <IncomeExpenseRow>[];
    for (final p in passengers) {
      rows.add(IncomeExpenseRow(
        date: tripDates[p.tripId] ?? '',
        detail: 'Ingreso pasajero ${p.route}',
        value: p.cost,
        isIncome: true,
      ));
    }
    for (final p in packages) {
      rows.add(IncomeExpenseRow(
        date: tripDates[p.tripId] ?? '',
        detail: 'Ingreso encomienda ${p.route}',
        value: p.cost,
        isIncome: true,
      ));
    }
    for (final e in expenses) {
      rows.add(IncomeExpenseRow(
        date: tripDates[e.tripId] ?? '',
        detail: 'Egreso ${e.category}${_withDetail(e.detail)}',
        value: e.amount,
        isIncome: false,
      ));
    }
    for (final v in vehicleExpenses) {
      rows.add(IncomeExpenseRow(
        date: v.expenseDate,
        detail: 'Egreso vehículo: ${v.detail}',
        value: v.amount,
        isIncome: false,
      ));
    }
    rows.sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  static double _avg(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return PaymentMath.round2(values.reduce((a, b) => a + b) / values.length);
  }

  static String _withDetail(String? detail) =>
      detail == null ? '' : ' ($detail)';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ---------------- filas de resultado ----------------

class TripReportRow {
  final Trip trip;
  final String driverName;
  final List<String> routes;
  final double ingreso;
  final double egreso;

  const TripReportRow({
    required this.trip,
    required this.driverName,
    required this.routes,
    required this.ingreso,
    required this.egreso,
  });

  String get routeText => routes.isEmpty ? '-' : routes.join(' | ');
}

class DriverReportRow {
  final String date;
  final String route;
  final double tripValue;
  final double paidToDriver;

  const DriverReportRow({
    required this.date,
    required this.route,
    required this.tripValue,
    required this.paidToDriver,
  });
}

class DriverReport {
  final String driverName;
  final List<DriverReportRow> rows;
  final double totalPaid;

  const DriverReport({
    required this.driverName,
    required this.rows,
    required this.totalPaid,
  });
}

class RouteReportRow {
  final String route;
  final double avgGasolina;
  final double avgIngreso;
  final double avgEgreso;
  final double neto;

  const RouteReportRow({
    required this.route,
    required this.avgGasolina,
    required this.avgIngreso,
    required this.avgEgreso,
    required this.neto,
  });
}

class CompanyReportRow {
  final String date;
  final String route;
  final String driverName;
  final double value;

  const CompanyReportRow({
    required this.date,
    required this.route,
    required this.driverName,
    required this.value,
  });
}

class CompanyReport {
  final List<CompanyReportRow> rows;
  final double total;

  const CompanyReport({required this.rows, required this.total});
}

class IncomeExpenseRow {
  final String date;
  final String detail;
  final double value;
  final bool isIncome;

  const IncomeExpenseRow({
    required this.date,
    required this.detail,
    required this.value,
    required this.isIncome,
  });
}
