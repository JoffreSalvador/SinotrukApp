import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  Future<List<Profile>> profiles({String? role}) async {
    dynamic query = _client.from('profiles').select();
    if (role != null) {
      query = query.eq('role', role);
    }
    query = query.order('name');
    final rows = await query;
    return (rows as List).map((r) => Profile.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('profiles').update({'is_active': active}).eq('id', id);
  }

  Future<List<Vehicle>> vehicles() async {
    final rows = await _client.from('vehicles').select().order('plate');
    return (rows as List).map((r) => Vehicle.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    await _client.from('vehicles').upsert(vehicle.toMap());
  }

  Future<void> deleteVehicle(String id) async {
    await _client.from('vehicles').delete().eq('id', id);
  }

  Future<List<VehicleAssignment>> assignments() async {
    final rows = await _client
        .from('vehicle_assignments')
        .select()
        .order('assigned_date', ascending: false);
    return (rows as List).map((r) => VehicleAssignment.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> assign({
    required String vehicleId,
    required String driverId,
    required String date,
  }) async {
    final current = await assignments();
    for (final a in current.where((a) => a.isActive)) {
      if (a.vehicleId == vehicleId || a.driverId == driverId) {
        await _client.from('vehicle_assignments').update({
          'is_active': false,
          'unassigned_date': date,
        }).eq('id', a.id);
      }
    }
    await _client.from('vehicle_assignments').upsert({
      'id': const Uuid().v4(),
      'vehicle_id': vehicleId,
      'driver_id': driverId,
      'is_active': true,
      'assigned_date': date,
    });
  }

  Future<void> deleteAssignment(String id) async {
    await _client.from('vehicle_assignments').delete().eq('id', id);
  }

  Future<void> addVehicleExpense(VehicleExpense expense) async {
    await _client.from('vehicle_expenses').upsert(expense.toMap());
  }

  Future<void> deleteVehicleExpense(String id) async {
    await _client.from('vehicle_expenses').delete().eq('id', id);
  }

  Future<List<VehicleExpense>> vehicleExpenses(
      {required String from, required String to}) async {
    final rows = await _client
        .from('vehicle_expenses')
        .select()
        .gte('expense_date', from)
        .lte('expense_date', to)
        .order('expense_date', ascending: false);
    return (rows as List).map((r) => VehicleExpense.fromMap(Map<String, dynamic>.from(r))).toList();
  }
}