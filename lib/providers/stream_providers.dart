import 'dart:core';
import 'dart:async';
import 'package:async/async.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/account_adjustments.dart';
import '../core/utils/payment_math.dart';
import '../models/accounts.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';
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

// 10% commission entries derived from trips + passengers + packages
List<ManagerAccountEntry> _computeCommissionEntries({
  required List<Trip> trips,
  required List<TripPassenger> passengers,
  required List<TripPackage> packages,
  required Map<String, String> driverNames,
  required String from,
  required String to,
}) {
  final tripMap = {for (final t in trips) t.id: t};
  final entries = <ManagerAccountEntry>[];
  
  // Group passengers by trip and date
  final passengerIncomeByTrip = <String, double>{};
  for (final p in passengers) {
    final trip = tripMap[p.tripId];
    if (trip == null) continue;
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    passengerIncomeByTrip[p.tripId] = (passengerIncomeByTrip[p.tripId] ?? 0) + p.cost;
  }
  
  // Group packages by trip and date
  final packageIncomeByTrip = <String, double>{};
  for (final p in packages) {
    final trip = tripMap[p.tripId];
    if (trip == null) continue;
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    packageIncomeByTrip[p.tripId] = (packageIncomeByTrip[p.tripId] ?? 0) + p.cost;
  }
  
  // Create 10% entries per trip
  for (final trip in trips) {
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    final passengerIncome = passengerIncomeByTrip[trip.id] ?? 0;
    final packageIncome = packageIncomeByTrip[trip.id] ?? 0;
    final totalIncome = passengerIncome + packageIncome;
    if (totalIncome > 0) {
      final commission = PaymentMath.round2(totalIncome * 0.1);
      if (commission > 0) {
        final driverName = driverNames[trip.driverId] ?? 'Conductor';
        entries.add(ManagerAccountEntry(
          id: 'auto-commission-${trip.id}',
          txType: 'ManualPorPagar',
          txDate: trip.tripDate,
          detail: '10% comisión $driverName',
          amount: commission,
          source: 'auto',
          relatedTripId: trip.id,
        ));
      }
    }
  }
  
  return entries;
}

// Empresa entries derived from trips + passengers + packages + vehicles
List<ManagerAccountEntry> _computeEmpresaEntries({
  required List<Trip> trips,
  required List<TripPassenger> passengers,
  required List<TripPackage> packages,
  required Map<String, String> vehiclePlates,
  required String from,
  required String to,
}) {
  final tripMap = {for (final t in trips) t.id: t};
  final entries = <ManagerAccountEntry>[];
  
  // Group Empresa passengers by trip
  final empresaPassengerByTrip = <String, double>{};
  for (final p in passengers) {
    if (p.paymentMethod.toLowerCase() != 'empresa') continue;
    final trip = tripMap[p.tripId];
    if (trip == null) continue;
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    empresaPassengerByTrip[p.tripId] = (empresaPassengerByTrip[p.tripId] ?? 0) + p.cost;
  }
  
  // Group Empresa packages by trip
  final empresaPackageByTrip = <String, double>{};
  for (final p in packages) {
    if (p.paymentMethod.toLowerCase() != 'empresa') continue;
    final trip = tripMap[p.tripId];
    if (trip == null) continue;
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    empresaPackageByTrip[p.tripId] = (empresaPackageByTrip[p.tripId] ?? 0) + p.cost;
  }
  
  // Create Empresa entries per trip
  for (final trip in trips) {
    if (trip.tripDate.compareTo(from) < 0 || trip.tripDate.compareTo(to) > 0) continue;
    final passengerEmpresa = empresaPassengerByTrip[trip.id] ?? 0;
    final packageEmpresa = empresaPackageByTrip[trip.id] ?? 0;
    final totalEmpresa = passengerEmpresa + packageEmpresa;
    if (totalEmpresa > 0) {
      // Get vehicle plate from assignment
      String plate = 'Sin placa';
      for (final entry in vehiclePlates.entries) {
        if (entry.key == trip.driverId) {
          plate = entry.value;
          break;
        }
      }
      entries.add(ManagerAccountEntry(
        id: 'auto-empresa-${trip.id}',
        txType: 'ManualPorCobrar',
        txDate: trip.tripDate,
        detail: 'Empresa $plate',
        amount: totalEmpresa,
        source: 'auto',
        relatedTripId: trip.id,
      ));
    }
  }
  
  return entries;
}

final managerCommissionEntriesProvider = StreamProvider.autoDispose.family<List<ManagerAccountEntry>, ({String from, String to})>((ref, range) {
  final tripsStream = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)).stream);
  final passengersStream = ref.watch(passengersStreamProvider.stream);
  final packagesStream = ref.watch(packagesStreamProvider.stream);
  final driversStream = ref.watch(driversStreamProvider.stream);
  
  return StreamZip([
    tripsStream,
    passengersStream,
    packagesStream,
    driversStream,
  ]).map(
    (values) => _computeCommissionEntries(
      trips: values[0] as List<Trip>,
      passengers: values[1] as List<TripPassenger>,
      packages: values[2] as List<TripPackage>,
      driverNames: {for (final d in values[3] as List<Profile>) d.id: d.name},
      from: range.from,
      to: range.to,
    ),
  );
});

// Empresa entries provider
final managerEmpresaEntriesProvider = StreamProvider.autoDispose.family<List<ManagerAccountEntry>, ({String from, String to})>((ref, range) {
  final tripsStream = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)).stream);
  final passengersStream = ref.watch(passengersStreamProvider.stream);
  final packagesStream = ref.watch(packagesStreamProvider.stream);
  final vehiclesStream = ref.watch(vehiclesStreamProvider.stream);
  final assignmentsStream = ref.watch(assignmentsStreamProvider.stream);
  
  return StreamZip([
    tripsStream,
    passengersStream,
    packagesStream,
    vehiclesStream,
    assignmentsStream,
  ]).map(
    (values) {
      final trips = values[0] as List<Trip>;
      final passengers = values[1] as List<TripPassenger>;
      final packages = values[2] as List<TripPackage>;
      final vehicles = values[3] as List<Vehicle>;
      final assignments = values[4] as List<VehicleAssignment>;
      
      // Build vehicle plate map for active assignments
      final activeAssignments = assignments.where((a) => a.isActive).toList();
      final vehicleMap = {for (final v in vehicles) v.id: v.plate};
      final driverToPlate = <String, String>{};
      for (final a in activeAssignments) {
        final plate = vehicleMap[a.vehicleId];
        if (plate != null) driverToPlate[a.driverId] = plate;
      }
      
      return _computeEmpresaEntries(
        trips: trips,
        passengers: passengers,
        packages: packages,
        vehiclePlates: driverToPlate,
        from: range.from,
        to: range.to,
      );
    },
  );
});

// Combined entries (manual + auto commission + auto empresa)
final managerCombinedEntriesProvider = StreamProvider.autoDispose.family<List<ManagerAccountEntry>, ({String from, String to})>((ref, range) {
  final manualEntriesStream = ref.watch(managerEntriesStreamProvider.stream);
  final commissionEntriesStream = ref.watch(managerCommissionEntriesProvider(range).stream);
  final empresaEntriesStream = ref.watch(managerEmpresaEntriesProvider(range).stream);
  
  return StreamZip([
    manualEntriesStream,
    commissionEntriesStream,
    empresaEntriesStream,
  ]).map(
    (values) => [...values[0] as List<ManagerAccountEntry>, ...values[1] as List<ManagerAccountEntry>, ...values[2] as List<ManagerAccountEntry>],
  );
});

// Real-time adjustment derived from combined entries stream (auto empresa entries already included)
ManagerAccountAdjustment _computeAdjustment(List<ManagerAccountEntry> all) {
  double cobrar = 0, pagar = 0, recibidos = 0, realizados = 0;
  for (final e in all) {
    if (e.isPorCobrar) {
      cobrar += e.amount;
    } else if (e.txType == 'ManualPorPagar') {
      pagar += e.amount;
    } else if (e.isPagoRecibido) {
      recibidos += e.amount;
    } else if (e.isPagoRealizado) {
      realizados += e.amount;
    }
  }
  return ManagerAccountAdjustment(
    valoresPorCobrar: PaymentMath.round2(cobrar),
    valoresPorPagar: PaymentMath.round2(pagar),
    pagosRealizados: PaymentMath.round2(realizados),
    pagosRecibidos: PaymentMath.round2(recibidos),
  );
}

final managerAdjustmentStreamProvider = StreamProvider.autoDispose.family<ManagerAccountAdjustment, ({String from, String to})>((ref, range) {
  final entriesStream = ref.watch(managerCombinedEntriesProvider(range).stream);
  
  return entriesStream.map(_computeAdjustment);
});