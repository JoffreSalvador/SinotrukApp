/// Utilidades de fecha en formato ISO corto (yyyy-MM-dd), el mismo que
/// usan las columnas date de Supabase y las columnas TEXT locales.
class DateUtilsX {
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String today() => format(DateTime.now());

  static DateTime parse(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Primer dia del año actual (para los filtros por defecto).
  static String startOfCurrentYear() => format(DateTime(DateTime.now().year));

  /// Ultimo dia del año actual.
  static String endOfCurrentYear() => format(DateTime(DateTime.now().year, 12, 31));

  /// true si [iso] esta dentro del rango inclusivo [from]..[to].
  static bool inRange(String iso, String from, String to) =>
      iso.compareTo(from) >= 0 && iso.compareTo(to) <= 0;
}
