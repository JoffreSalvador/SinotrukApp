import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'core_providers.dart';

// ================== STREAMS (Realtime) ==================
// NOTA: .stream(primaryKey: ['id']) devuelve TODAS las filas.
// Filtramos en Dart con .map() porque la API de streams no encadena .eq().

final profilesStreamProvider = StreamProvider.autoDispose<List<Profile>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => Profile.fromMap(Map<String, dynamic>.from(r))).toList());
});

final vehiclesStreamProvider = StreamProvider.autoDispose<List<Vehicle>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => Vehicle.fromMap(Map<String, dynamic>.from(r))).toList());
});

final driversStreamProvider = StreamProvider.autoDispose<List<Profile>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .map((r) => Profile.fromMap(Map<String, dynamic>.from(r)))
          .where((p) => p.isDriver)
          .toList());
});

final assignmentsStreamProvider = StreamProvider.autoDispose<List<VehicleAssignment>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('vehicle_assignments')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => VehicleAssignment.fromMap(Map<String, dynamic>.from(r))).toList());
});

final tripsStreamProvider = StreamProvider.autoDispose.family<List<Trip>, ({String from, String to, String? driverId})>((ref, range) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('trips')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .map((r) => Trip.fromMap(Map<String, dynamic>.from(r)))
          .where((t) => t.tripDate.compareTo(range.from) >= 0 && t.tripDate.compareTo(range.to) <= 0 && (range.driverId == null || t.driverId == range.driverId))
          .toList());
});

final passengersStreamProvider = StreamProvider.autoDispose<List<TripPassenger>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('trip_passengers')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => TripPassenger.fromMap(Map<String, dynamic>.from(r))).toList());
});

final packagesStreamProvider = StreamProvider.autoDispose<List<TripPackage>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('trip_packages')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => TripPackage.fromMap(Map<String, dynamic>.from(r))).toList());
});

final expensesStreamProvider = StreamProvider.autoDispose<List<TripExpense>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('trip_expenses')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => TripExpense.fromMap(Map<String, dynamic>.from(r))).toList());
});

final vehicleExpensesStreamProvider = StreamProvider.autoDispose.family<List<VehicleExpense>, ({String from, String to})>((ref, range) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('vehicle_expenses')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .map((r) => VehicleExpense.fromMap(Map<String, dynamic>.from(r)))
          .where((e) => e.expenseDate.compareTo(range.from) >= 0 && e.expenseDate.compareTo(range.to) <= 0)
          .toList());
});

final driverEntriesStreamProvider = StreamProvider.autoDispose.family<List<DriverAccountEntry>, String>((ref, driverId) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('driver_accounts')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .map((r) => DriverAccountEntry.fromMap(Map<String, dynamic>.from(r)))
          .where((e) => e.driverId == driverId)
          .toList());
});

final managerEntriesStreamProvider = StreamProvider.autoDispose<List<ManagerAccountEntry>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('manager_accounts')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => ManagerAccountEntry.fromMap(Map<String, dynamic>.from(r))).toList());
});