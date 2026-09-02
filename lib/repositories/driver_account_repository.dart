import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/account_adjustments.dart';
import '../core/utils/payment_math.dart';
import '../models/models.dart';

class DriverAccountRepository {
  final SupabaseClient _client;

  DriverAccountRepository(this._client);

  Future<void> addEntry(DriverAccountEntry entry) async {
    await _client.from('driver_accounts').upsert(entry.toMap());
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('driver_accounts').delete().eq('id', id);
  }

  Future<List<DriverAccountEntry>> entriesOf(String driverId,
      {String? txType}) async {
    dynamic query = _client
        .from('driver_accounts')
        .select()
        .eq('driver_id', driverId);
    if (txType != null) {
      query = query.eq('tx_type', txType);
    }
    query = query.order('tx_date', ascending: false);
    final rows = await query;
    return (rows as List).map((r) => DriverAccountEntry.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<DriverAccountAdjustment> adjustment(String driverId) async {
    final trips = await _client
        .from('trips')
        .select('id')
        .eq('driver_id', driverId);
    final tripIds = (trips as List).map((r) => r['id'] as String).toSet();

    double totalTripExpenses = 0;
    double viajesEfectivo = 0;

    if (tripIds.isNotEmpty) {
      final expenses = await _client
          .from('trip_expenses')
          .select()
          .filter('trip_id', 'in', '(${tripIds.join(',')})');
      totalTripExpenses = PaymentMath.sum(
          (expenses as List).map((r) => (r['amount'] as num?)?.toDouble() ?? 0.0));

      final passengers = await _client
          .from('trip_passengers')
          .select()
          .filter('trip_id', 'in', '(${tripIds.join(',')})')
          .eq('payment_method', 'Efectivo');
      final passengersEfectivo = PaymentMath.sum(
          (passengers as List).map((r) => (r['cost'] as num?)?.toDouble() ?? 0.0));

      final packages = await _client
          .from('trip_packages')
          .select()
          .filter('trip_id', 'in', '(${tripIds.join(',')})')
          .eq('payment_method', 'Efectivo');
      final packagesEfectivo = PaymentMath.sum(
          (packages as List).map((r) => (r['cost'] as num?)?.toDouble() ?? 0.0));

      viajesEfectivo = passengersEfectivo + packagesEfectivo;
    }

    final entries = await entriesOf(driverId);
    final pagosRecibidos = PaymentMath.sum(entries
        .where((e) => e.isPagoRecibido)
        .map((e) => e.amount));
    final pagosRealizados = PaymentMath.sum(entries
        .where((e) => e.isPagoRealizado)
        .map((e) => e.amount));

    return DriverAccountAdjustment(
      totalTripExpenses: totalTripExpenses,
      pagosRecibidos: pagosRecibidos,
      viajesEfectivo: viajesEfectivo,
      pagosRealizados: pagosRealizados,
    );
  }
}