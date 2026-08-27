/// Utilidades numericas para manejar dinero sin errores de punto flotante.
class PaymentMath {
  /// Suma una lista de montos tolerando nulos (se cuentan como 0).
  static double sum(Iterable<double?> amounts) {
    var total = 0.0;
    for (final amount in amounts) {
      if (amount != null) total += amount;
    }
    return round2(total);
  }

  /// Redondea a 2 decimales para evitar residuos tipo 0.30000000000000004.
  static double round2(double value) =>
      (value * 100).roundToDouble() / 100;

  /// Porcentaje seguro: [percent] en escala 0-100 (ej. 10 para el gerente).
  static double percentOf(double base, double percent) =>
      round2(base * percent / 100);

  static String formatMoney(double value) =>
      '\$${value.toStringAsFixed(2)}';
}
