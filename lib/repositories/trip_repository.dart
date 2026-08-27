import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/account_adjustments.dart';
import '../core/utils/payment_math.dart';
import '../models/models.dart';

class TripRepository {
  final SupabaseClient _client;

  TripRepository(this._client);

  Future<void> saveTripFull({
    required Trip trip,
    required List<TripPassenger> passengers,
    required List<TripPackage> packages,
    required List<TripExpense> expenses,
  }) async {
    await _client.from('trips').upsert(trip.toMap());
    if (passengers.isNotEmpty) {
      await _client.from('trip_passengers').upsert(
        passengers.map((p) => p.toMap()).toList(),
      );
    }
    if (packages.isNotEmpty) {
      await _client.from('trip_packages').upsert(
        packages.map((p) => p.toMap()).toList(),
      );
    }
    if (expenses.isNotEmpty) {
      await _client.from('trip_expenses').upsert(
        expenses.map((e) => e.toMap()).toList(),
      );
    }
  }

  Future<List<Trip>> tripsOfDriver(String driverId,
      {String? from, String? to}) async {
    dynamic query = _client
        .from('trips')
        .select()
        .eq('driver_id', driverId);
    if (from != null && to != null) {
      query = query.gte('trip_date', from).lte('trip_date', to);
    } else if (from != null) {
      query = query.gte('trip_date', from);
    } else if (to != null) {
      query = query.lte('trip_date', to);
    }
    query = query.order('trip_date', ascending: false);
    final rows = await query;
    return (rows as List).map((r) => Trip.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<TripPassenger>> passengersOf(String tripId) async {
    final rows = await _client
        .from('trip_passengers')
        .select()
        .eq('trip_id', tripId);
    return (rows as List).map((r) => TripPassenger.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<TripPackage>> packagesOf(String tripId) async {
    final rows = await _client
        .from('trip_packages')
        .select()
        .eq('trip_id', tripId);
    return (rows as List).map((r) => TripPackage.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<List<TripExpense>> expensesOf(String tripId) async {
    final rows = await _client
        .from('trip_expenses')
        .select()
        .eq('trip_id', tripId);
    return (rows as List).map((r) => TripExpense.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<TripRangeSummary> rangeSummary(String driverId,
      {required String from, required String to}) async {
    final trips = await tripsOfDriver(driverId);
    final tripIds = trips.map((t) => t.id).toSet();

    if (tripIds.isEmpty) {
      return const TripRangeSummary(
        passengerCount: 0,
        packageCount: 0,
        ingresos: 0,
        egresos: 0,
      );
    }

    final passengers = await _client
        .from('trip_passengers')
        .select()
        .filter('trip_id', 'in', '(${tripIds.join(',')})');
    final packages = await _client
        .from('trip_packages')
        .select()
        .filter('trip_id', 'in', '(${tripIds.join(',')})');
    final expenses = await _client
        .from('trip_expenses')
        .select()
        .filter('trip_id', 'in', '(${tripIds.join(',')})');

    final pax = (passengers as List).map((r) => TripPassenger.fromMap(Map<String, dynamic>.from(r)));
    final pkgs = (packages as List).map((r) => TripPackage.fromMap(Map<String, dynamic>.from(r)));
    final exps = (expenses as List).map((r) => TripExpense.fromMap(Map<String, dynamic>.from(r)));

    return TripRangeSummary(
      passengerCount: pax.length,
      packageCount: pkgs.length,
      ingresos: PaymentMath.sum([
        ...pax.map((p) => p.cost),
        ...pkgs.map((p) => p.cost),
      ]),
      egresos: PaymentMath.sum(exps.map((e) => e.amount)),
    );
  }
}