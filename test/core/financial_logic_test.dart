import 'package:flutter_test/flutter_test.dart';
import 'package:sinotruk_app/core/utils/account_adjustments.dart';
import 'package:sinotruk_app/core/utils/payment_math.dart';

void main() {
  group('PaymentMath', () {
    test('sum ignora nulos y redondea a 2 decimales', () {
      final total = PaymentMath.sum([10.5, null, 20.25, 0.005]);
      expect(total, 30.76);
    });

    test('round2 elimina residuos de punto flotante', () {
      expect(PaymentMath.round2(0.1 + 0.2), 0.3);
      expect(PaymentMath.round2(33.333333), 33.33);
    });

    test('percentOf calcula el 10% del gerente', () {
      expect(PaymentMath.percentOf(125.50, 10), 12.55);
      expect(PaymentMath.percentOf(0, 10), 0);
    });

    test('sum con lista vacia o toda nula devuelve 0', () {
      expect(PaymentMath.sum([]), 0);
      expect(PaymentMath.sum([null, null]), 0);
    });
  });

  group('DriverAccountAdjustment', () {
    // Formula: (gastosViaje - pagosRecibidos) - (viajesEfectivo - pagosRealizados)
    test('conductor debe al empleador cuando retiene mas efectivo del reembolso pendiente',
        () {
      final adj = DriverAccountAdjustment(
        totalTripExpenses: 50, // gasolina+conductor+peajes+otros
        pagosRecibidos: 20,
        viajesEfectivo: 100, // cobro directo al pasajero
        pagosRealizados: 0,
      );
      // (50-20) - (100-0) = -70 -> el conductor debe al empleador
      expect(adj.balance, -70);
      expect(adj.driverOwesEmployer, isTrue);
      expect(adj.employerOwesDriver, isFalse);
    });

    test('empleador debe al conductor cuando el reembolso supera el efectivo retenido',
        () {
      final adj = DriverAccountAdjustment(
        totalTripExpenses: 120,
        pagosRecibidos: 10,
        viajesEfectivo: 40,
        pagosRealizados: 30,
      );
      // (120-10) - (40-30) = 110 - 10 = 100 -> el empleador debe al conductor
      expect(adj.balance, 100);
      expect(adj.employerOwesDriver, isTrue);
    });

    test('cuentas parejas dan balance cero', () {
      final adj = DriverAccountAdjustment(
        totalTripExpenses: 60,
        pagosRecibidos: 60,
        viajesEfectivo: 80,
        pagosRealizados: 80,
      );
      expect(adj.balance, 0);
      expect(adj.isSettled, isTrue);
    });
  });

  group('ManagerAccountAdjustment', () {
    // Formula: porCobrar + valoresEmpresa - porPagar + realizados - recibidos
    test('gerente le debe al empleador con valores positivos', () {
      final adj = ManagerAccountAdjustment(
        valoresPorCobrar: 100,
        valoresEmpresa: 400, // viajes Empresa
        valoresPorPagar: 200, // 10% gerente + manuales
        pagosRealizados: 300,
        pagosRecibidos: 100,
      );
      expect(adj.balance, 500);
      expect(adj.managerOwesEmployer, isTrue);
    });

    test('empleador le debe al gerente cuando pago de mas', () {
      final adj = ManagerAccountAdjustment(
        valoresPorCobrar: 100,
        valoresEmpresa: 0,
        valoresPorPagar: 400,
        pagosRealizados: 0,
        pagosRecibidos: 50,
      );
      expect(adj.balance, -350);
      expect(adj.employerOwesManager, isTrue);
    });

    test('balance cero cuando todo cuadra', () {
      final adj = ManagerAccountAdjustment(
        valoresPorCobrar: 300,
        valoresEmpresa: 0,
        valoresPorPagar: 100,
        pagosRealizados: 0,
        pagosRecibidos: 200,
      );
      expect(adj.balance, 0);
      expect(adj.isSettled, isTrue);
    });
  });

  group('TripRangeSummary', () {
    test('neto = ingresos - egresos', () {
      const summary = TripRangeSummary(
        passengerCount: 4,
        packageCount: 2,
        ingresos: 150,
        egresos: 90,
      );
      expect(summary.neto, 60);
    });

    test('neto negativo representa perdida', () {
      const summary = TripRangeSummary(
        passengerCount: 0,
        packageCount: 0,
        ingresos: 0,
        egresos: 25.5,
      );
      expect(summary.neto, -25.5);
    });
  });
}
