import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/account_adjustments.dart';
import '../core/utils/payment_math.dart';
import '../models/models.dart';

/// Cuenta del administrador con el gerente usando Supabase directo.
class ManagerAccountRepository {
  final SupabaseClient _client;

  ManagerAccountRepository(this._client);

  Future<List<ManagerAccountEntry>> entries() async {
    final rows = await _client
        .from('manager_accounts')
        .select()
        .order('tx_date', ascending: false);
    return (rows as List).map((r) => ManagerAccountEntry.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> addManual({
    required bool porCobrar,
    required String date,
    required String detail,
    required double amount,
  }) async {
    await _client.from('manager_accounts').upsert({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'tx_type': porCobrar ? 'ManualPorCobrar' : 'ManualPorPagar',
      'tx_date': date,
      'detail': detail,
      'amount': amount,
      'source': 'manual',
    });
  }

  Future<void> addEntry(ManagerAccountEntry entry) async {
    await _client.from('manager_accounts').upsert(entry.toMap());
  }

  Future<ManagerAccountAdjustment> adjustment() async {
    final all = await entries();
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
}