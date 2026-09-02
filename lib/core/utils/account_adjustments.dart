import 'payment_math.dart';

double _round2(double value) => PaymentMath.round2(value);

/// Resultado del ajuste de cuentas entre conductor y empleador.
///
/// Logica de negocio (formula del requerimiento):
///   balance = (gastosDeViaje - pagosRecibidos)
///           - (viajesEnEfectivo - pagosRealizados)
///
/// Terminos: (gastosDeViaje - pagosRecibidos) es lo que el empleador aun
/// debe reembolsar al conductor; (viajesEnEfectivo - pagosRealizados) es el
/// efectivo que el conductor retuvo y aun no entrega.
///
/// balance > 0  -> el EMPLEADOR DEBE al conductor (reembolso pendiente).
/// balance < 0  -> el CONDUCTOR DEBE al empleador (efectivo retenido).
/// balance == 0 -> cuentas parejas.
class DriverAccountAdjustment {
  final double totalTripExpenses;
  final double pagosRecibidos;
  final double viajesEfectivo;
  final double pagosRealizados;

  const DriverAccountAdjustment({
    required this.totalTripExpenses,
    required this.pagosRecibidos,
    required this.viajesEfectivo,
    required this.pagosRealizados,
  });

  double get balance =>
      _round2((totalTripExpenses - pagosRecibidos) -
          (viajesEfectivo - pagosRealizados));

  bool get employerOwesDriver => balance > 0;
  bool get driverOwesEmployer => balance < 0;
  bool get isSettled => balance == 0;
}

/// Resultado del ajuste de cuentas entre admin (empleador) y gerente.
///
/// Logica de negocio (formula del requerimiento):
///   balance = valoresPorCobrar + valoresEmpresa - valoresPorPagar
///           + pagosRealizados - pagosRecibidos
///
/// balance > 0  -> el gerente LE DEBE al empleador.
/// balance < 0  -> el empleador DEBE al gerente.
class ManagerAccountAdjustment {
  final double valoresPorCobrar;
  final double valoresEmpresa;
  final double valoresPorPagar;
  final double pagosRealizados;
  final double pagosRecibidos;

  const ManagerAccountAdjustment({
    required this.valoresPorCobrar,
    required this.valoresEmpresa,
    required this.valoresPorPagar,
    required this.pagosRealizados,
    required this.pagosRecibidos,
  });

  double get balance => _round2(valoresPorCobrar +
      valoresEmpresa -
      valoresPorPagar +
      pagosRealizados -
      pagosRecibidos);

  bool get managerOwesEmployer => balance > 0;
  bool get employerOwesManager => balance < 0;
  bool get isSettled => balance == 0;
}

/// Resumen general de un rango de fechas para el chofer.
class TripRangeSummary {
  final int passengerCount;
  final int packageCount;
  final double ingresos;
  final double egresos;

  const TripRangeSummary({
    required this.passengerCount,
    required this.packageCount,
    required this.ingresos,
    required this.egresos,
  });

  double get neto => _round2(ingresos - egresos);
}

