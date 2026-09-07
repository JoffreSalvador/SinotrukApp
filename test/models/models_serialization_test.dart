import 'package:flutter_test/flutter_test.dart';
import 'package:sinotruk_app/models/models.dart';

void main() {
  group('Serializacion de modelos (sqflite / Supabase)', () {
    test('TripPassenger maneja cost nulo como 0 y valores por defecto', () {
      final passenger = TripPassenger.fromMap({
        'id': 'p1',
        'trip_id': 't1',
      });
      expect(passenger.cost, 0.0);
      expect(passenger.paymentMethod, 'Efectivo');
      expect(passenger.route, ' -> ');
    });

    test('TripExpense tolera detail nulo (categorias no-Otros)', () {
      final expense = TripExpense.fromMap({
        'id': 'e1',
        'trip_id': 't1',
        'category': 'Gasolina',
        'detail': null,
        'amount': 25.5,
      });
      expect(expense.detail, isNull);
      expect(expense.amount, 25.5);
      expect(expense.isRefundableCategory, isTrue);
    });

    test('ManagerAccountEntry lee created_at opcional', () {
      final withDate = ManagerAccountEntry.fromMap({
        'id': 'm1',
        'tx_type': 'PagoRecibido',
        'tx_date': '2026-09-07',
        'detail': 'Abono',
        'amount': 10,
        'created_at': '2026-09-07T10:00:00Z',
      });
      expect(withDate.createdAt, isNotNull);

      const withoutDate = ManagerAccountEntry(
        id: 'm2',
        txType: 'PagoRecibido',
        txDate: '2026-09-07',
        detail: 'Abono',
        amount: 10,
      );
      expect(withoutDate.createdAt, isNull);
      expect(withoutDate.toMap().containsKey('created_at'), isFalse);
    });

    test('ManagerAccountEntry distingue auto de manual', () {
      final auto = ManagerAccountEntry.fromMap({
        'id': 'm1',
        'tx_type': 'ManualPorPagar',
        'tx_date': '2026-08-25',
        'detail': '10% gerente',
        'amount': 12.5,
        'source': 'auto',
        'related_trip_id': null,
      });
      expect(auto.isAutomatic, isTrue);
      expect(auto.relatedTripId, isNull);

      final manual = ManagerAccountEntry(
        id: 'm2',
        txType: 'PagoRecibido',
        txDate: '2026-08-25',
        detail: 'Abono',
        amount: 100,
      );
      expect(manual.toMap().containsKey('related_trip_id'), isFalse);
    });

    test('Profile acepta is_active como bool, int o nulo', () {
      expect(Profile.fromMap({'id': 'u1', 'name': 'A', 'username': 'a', 'role': 'admin', 'is_active': true}).isActive, isTrue);
      expect(Profile.fromMap({'id': 'u2', 'name': 'B', 'username': 'b', 'role': 'driver', 'is_active': 0}).isActive, isFalse);
      expect(Profile.fromMap({'id': 'u3', 'name': 'C', 'username': 'c', 'role': 'driver'}).isActive, isTrue);
    });

    test('toMap elimina claves nulas para PostgREST', () {
      final trip = Trip(id: 't1', driverId: 'd1', tripDate: '2026-08-25')
          .toMap();
      expect(trip.containsKey('observations'), isFalse);
    });

    test('Trip lee created_at y ventana editable de 24h', () {
      final recent = Trip.fromMap({
        'id': 't1',
        'driver_id': 'd1',
        'trip_date': '2026-08-25',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      });
      expect(recent.createdAt, isNotNull);
      expect(recent.isEditable, isTrue);

      final old = Trip.fromMap({
        'id': 't2',
        'driver_id': 'd1',
        'trip_date': '2026-08-20',
        'created_at': DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      });
      expect(old.isEditable, isFalse);

      const unknown = Trip(id: 't3', driverId: 'd1', tripDate: '2026-08-25');
      expect(unknown.createdAt, isNull);
      expect(unknown.isEditable, isFalse);

      // created_at lo gestiona la BD: no se envía en toMap.
      expect(recent.toMap().containsKey('created_at'), isFalse);
    });
  });
}
