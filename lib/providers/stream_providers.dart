import 'dart:core';
import 'dart:async';

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
  return client.from('profiles').stream(primaryKey: ['id']).map((rows) {
    final drivers = rows
        .map((r) => Profile.fromMap(Map<String, dynamic>.from(r)))
        .where((p) => p.isDriver)
        .toList();
    drivers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return drivers;
  });
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

/// Solo movimientos MANUALES de la tabla: las filas `auto` las genera el
/// trigger de la BD y la app las calcula en cliente; incluirlas aquí
/// las contaría dos veces.
final managerEntriesStreamProvider = StreamProvider.autoDispose<List<ManagerAccountEntry>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.from('manager_accounts').stream(primaryKey: ['id']).map((rows) => rows
      .map((r) => ManagerAccountEntry.fromMap(Map<String, dynamic>.from(r)))
      .where((e) => !e.isAutomatic)
      .toList());
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
  final tripsAsync = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));
  final passengersAsync = ref.watch(passengersStreamProvider);
  final packagesAsync = ref.watch(packagesStreamProvider);
  final driversAsync = ref.watch(driversStreamProvider);

  for (final a in [tripsAsync, passengersAsync, packagesAsync, driversAsync]) {
    if (a.hasError) return Stream.error(a.error!, a.stackTrace);
  }
  if (tripsAsync.isLoading || passengersAsync.isLoading || packagesAsync.isLoading || driversAsync.isLoading) {
    return const Stream<List<ManagerAccountEntry>>.empty();
  }

  return Stream.value(_computeCommissionEntries(
    trips: tripsAsync.value ?? [],
    passengers: passengersAsync.value ?? [],
    packages: packagesAsync.value ?? [],
    driverNames: {for (final d in driversAsync.value ?? <Profile>[]) d.id: d.name},
    from: range.from,
    to: range.to,
  ));
});

// Empresa entries provider
final managerEmpresaEntriesProvider = StreamProvider.autoDispose.family<List<ManagerAccountEntry>, ({String from, String to})>((ref, range) {
  final tripsAsync = ref.watch(tripsStreamProvider((from: range.from, to: range.to, driverId: null)));
  final passengersAsync = ref.watch(passengersStreamProvider);
  final packagesAsync = ref.watch(packagesStreamProvider);
  final vehiclesAsync = ref.watch(vehiclesStreamProvider);
  final assignmentsAsync = ref.watch(assignmentsStreamProvider);

  for (final a in [tripsAsync, passengersAsync, packagesAsync, vehiclesAsync, assignmentsAsync]) {
    if (a.hasError) return Stream.error(a.error!, a.stackTrace);
  }
  if (tripsAsync.isLoading || passengersAsync.isLoading || packagesAsync.isLoading || vehiclesAsync.isLoading || assignmentsAsync.isLoading) {
    return const Stream<List<ManagerAccountEntry>>.empty();
  }

  final trips = tripsAsync.value ?? [];
  final passengers = passengersAsync.value ?? [];
  final packages = packagesAsync.value ?? [];
  final vehicles = vehiclesAsync.value ?? [];
  final assignments = assignmentsAsync.value ?? [];

  // Build vehicle plate map for active assignments
  final activeAssignments = assignments.where((a) => a.isActive).toList();
  final vehicleMap = {for (final v in vehicles) v.id: v.plate};
  final driverToPlate = <String, String>{};
  for (final a in activeAssignments) {
    final plate = vehicleMap[a.vehicleId];
    if (plate != null) driverToPlate[a.driverId] = plate;
  }

  return Stream.value(_computeEmpresaEntries(
    trips: trips,
    passengers: passengers,
    packages: packages,
    vehiclePlates: driverToPlate,
    from: range.from,
    to: range.to,
  ));
});

// Combined entries (manual + auto commission + auto empresa).
// Todo respeta el rango: los manuales se acotan por tx_date y los
// automáticos ya vienen calculados dentro del rango.
final managerCombinedEntriesProvider = StreamProvider.autoDispose.family<List<ManagerAccountEntry>, ({String from, String to})>((ref, range) {
  final manualAsync = ref.watch(managerEntriesStreamProvider);
  final commissionAsync = ref.watch(managerCommissionEntriesProvider(range));
  final empresaAsync = ref.watch(managerEmpresaEntriesProvider(range));

  for (final a in [manualAsync, commissionAsync, empresaAsync]) {
    if (a.hasError) return Stream.error(a.error!, a.stackTrace);
  }
  if (manualAsync.isLoading || commissionAsync.isLoading || empresaAsync.isLoading) {
    return const Stream<List<ManagerAccountEntry>>.empty();
  }

  final manualInRange = (manualAsync.value ?? [])
      .where((e) =>
          e.txDate.compareTo(range.from) >= 0 &&
          e.txDate.compareTo(range.to) <= 0)
      .toList();

  return Stream.value([
    ...manualInRange,
    ...(commissionAsync.value ?? []),
    ...(empresaAsync.value ?? []),
  ]);
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
  final entriesAsync = ref.watch(managerCombinedEntriesProvider(range));

  if (entriesAsync.hasError) return Stream.error(entriesAsync.error!, entriesAsync.stackTrace);
  if (entriesAsync.isLoading) return const Stream<ManagerAccountAdjustment>.empty();

  return Stream.value(_computeAdjustment(entriesAsync.value ?? []));
});

// Ajuste de cuentas del conductor en tiempo real, opcionalmente acotado.
// Sin from/to abarca todo el historial. Todo deriva de streams: cualquier
// cambio (nuevo pago, viaje, gasto) recalcula y re-emite automáticamente.
final driverAdjustmentStreamProvider = StreamProvider.autoDispose.family<DriverAccountAdjustment, ({String driverId, String? from, String? to})>((ref, args) {
  final tripsAsync = ref.watch(tripsStreamProvider((
    from: args.from ?? '2000-01-01',
    to: args.to ?? '2100-12-31',
    driverId: args.driverId,
  )));
  final passengersAsync = ref.watch(passengersStreamProvider);
  final packagesAsync = ref.watch(packagesStreamProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);
  final entriesAsync = ref.watch(driverEntriesStreamProvider(args.driverId));

  for (final a in [tripsAsync, passengersAsync, packagesAsync, expensesAsync, entriesAsync]) {
    if (a.hasError) return Stream.error(a.error!, a.stackTrace);
  }
  if (tripsAsync.isLoading ||
      passengersAsync.isLoading ||
      packagesAsync.isLoading ||
      expensesAsync.isLoading ||
      entriesAsync.isLoading) {
    return const Stream<DriverAccountAdjustment>.empty();
  }

  final tripIds = (tripsAsync.value ?? []).map((t) => t.id).toSet();
  final totalTripExpenses = PaymentMath.sum((expensesAsync.value ?? [])
      .where((e) => tripIds.contains(e.tripId))
      .map((e) => e.amount));
  final cashPassengers = PaymentMath.sum((passengersAsync.value ?? [])
      .where((p) => tripIds.contains(p.tripId) && p.paymentMethod == 'Efectivo')
      .map((p) => p.cost));
  final cashPackages = PaymentMath.sum((packagesAsync.value ?? [])
      .where((p) => tripIds.contains(p.tripId) && p.paymentMethod == 'Efectivo')
      .map((p) => p.cost));
  final inRangeEntries = (entriesAsync.value ?? [])
      .where((e) =>
          (args.from == null || e.txDate.compareTo(args.from!) >= 0) &&
          (args.to == null || e.txDate.compareTo(args.to!) <= 0))
      .toList();

  return Stream.value(DriverAccountAdjustment(
    totalTripExpenses: totalTripExpenses,
    pagosRecibidos: PaymentMath.sum(
        inRangeEntries.where((e) => e.isPagoRecibido).map((e) => e.amount)),
    viajesEfectivo: PaymentMath.round2(cashPassengers + cashPackages),
    pagosRealizados: PaymentMath.sum(
        inRangeEntries.where((e) => e.isPagoRealizado).map((e) => e.amount)),
  ));
});