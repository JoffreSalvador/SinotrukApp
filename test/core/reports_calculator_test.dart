import 'package:flutter_test/flutter_test.dart';
import 'package:sinotruk_app/core/utils/reports_calculator.dart';
import 'package:sinotruk_app/models/models.dart';

void main() {
  final trips = [
    const Trip(id: 't1', driverId: 'd1', tripDate: '2026-03-10'),
    const Trip(id: 't2', driverId: 'd2', tripDate: '2026-04-20'),
    const Trip(id: 't3', driverId: 'd1', tripDate: '2025-12-01'),
  ];
  final driverNames = {'d1': 'Luis', 'd2': 'Ana'};
  final passengers = [
    // t1: Loja->Quito (2 pax), Loja->Cuenca (Empresa)
    const TripPassenger(id: 'p1', tripId: 't1', departure: 'Loja',
        arrival: 'Quito', cost: 15, paymentMethod: 'Efectivo'),
    const TripPassenger(id: 'p2', tripId: 't1', departure: 'Loja',
        arrival: 'Quito', cost: 25, paymentMethod: 'Empresa'),
    const TripPassenger(id: 'p3', tripId: 't1', departure: 'Loja',
        arrival: 'Cuenca', cost: 10, paymentMethod: 'Empresa'),
    // t2
    const TripPassenger(id: 'p4', tripId: 't2', departure: 'Loja',
        arrival: 'Quito', cost: 30, paymentMethod: 'Efectivo'),
    // t3 (fuera de rango en algunos tests)
    const TripPassenger(id: 'p5', tripId: 't3', departure: 'A',
        arrival: 'B', cost: 8, paymentMethod: 'Efectivo'),
  ];
  final packages = [
    const TripPackage(id: 'k1', tripId: 't2', departure: 'Machala',
        arrival: 'Guayaquil', cost: 6, paymentMethod: 'Empresa'),
  ];
  final expenses = [
    const TripExpense(id: 'e1', tripId: 't1', category: 'Gasolina',
        amount: 20, detail: null),
    const TripExpense(id: 'e2', tripId: 't1', category: 'Conductor',
        amount: 10, detail: null),
    const TripExpense(id: 'e3', tripId: 't2', category: 'Gasolina',
        amount: 14, detail: null),
    const TripExpense(id: 'e4', tripId: 't3', category: 'Otros',
        amount: 3, detail: 'lavado'),
  ];

  group('Reporte Por Viajes', () {
    test('ingreso = suma de pasajeros; egreso = suma de gastos', () {
      final rows = ReportsCalculator.byTrip(
        trips: [trips[0]],
        driverNames: driverNames,
        passengers: passengers,
        packages: const [],
        expenses: expenses,
      );
      expect(rows.single.driverName, 'Luis');
      expect(rows.single.ingreso, 50); // 15+25+10
      expect(rows.single.egreso, 30); // 20+10
      expect(rows.single.passengers.length, 3);
    });

    test('maneja viaje sin pasajeros ni gastos (nulos/vacios)', () {
      final rows = ReportsCalculator.byTrip(
        trips: [const Trip(id: 'tx', driverId: 'desconocido',
            tripDate: '2026-05-01')],
        driverNames: driverNames,
        passengers: const [],
        packages: const [],
        expenses: const [],
      );
      expect(rows.single.ingreso, 0);
      expect(rows.single.egreso, 0);
      expect(rows.single.routeText, '-');
      expect(rows.single.driverName, 'desconocido');
    });
  });

  group('Reporte Por Conductor', () {
    test('filas por pasajero con pago al conductor por viaje + total', () {
      final report = ReportsCalculator.byDriver(
        driverId: 'd1',
        driverNames: driverNames,
        trips: trips,
        passengers: passengers,
        packages: [],
        expenses: expenses,
      );
      // d1 tiene t1 (3 pax) y t3 (1 pax) -> 4 filas
      expect(report.rows.length, 4);
      // t1 pagó 10 a conductor (1 pago por viaje), t3 no pagó conductor (1 fila)
      expect(report.totalPaid, 10);
      final t1rows =
          report.rows.where((r) => r.date == '2026-03-10').toList();
      for (final r in t1rows) {
        expect(r.paidToDriver, 10);
      }
    });

    test('conductor sin viajes produce total cero', () {
      final report = ReportsCalculator.byDriver(
        driverId: 'sin-viajes',
        driverNames: driverNames,
        trips: trips,
        passengers: passengers,
        packages: [],
        expenses: expenses,
      );
      expect(report.rows, isEmpty);
      expect(report.totalPaid, 0);
    });
  });

  group('Reporte Por Rutas', () {
    test('promedios por ruta y neto ganancia/perdida', () {
      final rows = ReportsCalculator.byRoute(
        passengers: passengers.where((p) => p.tripId != 't3').toList(),
        expenses: expenses,
      );

      final lojaQuito =
          rows.firstWhere((r) => r.route == 'Loja -> Quito');
      // Dos viajes con esa ruta: t1 (ingreso 40) y t2 (ingreso 30)
      expect(lojaQuito.avgIngreso, 35);
      // Gasolina: t1=20, t2=14 -> promedio 17
      expect(lojaQuito.avgGasolina, 17);
      // Egreso: t1=30, t2=14 -> promedio 22
      expect(lojaQuito.avgEgreso, 22);
      expect(lojaQuito.neto, 13);

      final lojaCuenca =
          rows.firstWhere((r) => r.route == 'Loja -> Cuenca');
      // Un solo viaje: ingreso 10, egreso 30 -> perdida -20
      expect(lojaCuenca.neto, -20);
    });
  });

  group('Reporte Empresa', () {
    test('incluye pasajeros y encomiendas Empresa con ruta individual', () {
      final report = ReportsCalculator.byCompany(
        trips: trips,
        driverNames: driverNames,
        passengers: passengers,
        packages: packages,
      );
      // p2(25,t1), p3(10,t1), k1(6,t2)
      expect(report.rows.length, 3);
      expect(report.total, 41);
      expect(
        report.rows.map((r) => r.route),
        containsAll(['Loja -> Quito', 'Loja -> Cuenca',
            'Machala -> Guayaquil']),
      );
      final kRow = report.rows.firstWhere(
          (r) => r.route == 'Machala -> Guayaquil');
      expect(kRow.driverName, 'Ana');
    });
  });

  group('Reporte Ingresos/Egresos', () {
    test('incluye pasajeros, encomiendas, gastos de viaje y vehículo',
        () {
      final rows = ReportsCalculator.incomeExpense(
        passengers: passengers.where((p) => p.tripId == 't1').toList(),
        packages: packages,
        expenses:
            expenses.where((e) => e.tripId == 't1').toList(),
        tripDates: {'t1': '2026-03-10', 't2': '2026-04-20'},
        vehicleExpenses: const [
          VehicleExpense(id: 'v1', vehicleId: 'vh1',
              expenseDate: '2026-03-11',
              detail: 'Aceite', amount: 45),
        ],
      );
      final ingresos =
          rows.where((r) => r.isIncome).fold(0.0, (s, r) => s + r.value);
      final egresos =
          rows.where((r) => !r.isIncome).fold(0.0, (s, r) => s + r.value);

      expect(ingresos, 56); // 50 pax + 6 encomienda
      expect(egresos, 75); // 30 viaje + 45 vehículo
      expect(
        rows.any((r) =>
            !r.isIncome && r.detail.contains('Aceite') && r.date == '2026-03-11'),
        isTrue,
      );
      expect(
        rows.any((r) => r.isIncome &&
            r.detail.contains('encomienda') &&
            r.date == '2026-04-20'),
        isTrue,
      );
    });
  });
}
