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

  /// Rango por defecto de los últimos 30 días (hoy incluido).
  static ({DateTime from, DateTime to}) last30Days() => lastDays(30);

  /// Rango de los últimos [days] días (hoy incluido).
  static ({DateTime from, DateTime to}) lastDays(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (from: today.subtract(Duration(days: days - 1)), to: today);
  }

  /// Rango del mes presente: del día 1 hasta hoy.
  static ({DateTime from, DateTime to}) currentMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (from: DateTime(now.year, now.month, 1), to: today);
  }

  /// Nombre del mes en español con el año: "Septiembre de 2026".
  static String monthYearLabel(DateTime date) =>
      '${_monthName(date.month)} de ${date.year}';

  static String _monthName(int month) => const [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ][month - 1];
}
