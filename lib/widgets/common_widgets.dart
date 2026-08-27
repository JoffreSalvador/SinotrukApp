import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/payment_math.dart';
import '../providers/app_providers.dart';
import '../providers/stream_providers.dart';

/// Badge de sincronizaciÃ³n (versiÃ³n simplificada: solo botÃ³n de refresh manual).
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sincronizar ahora',
      icon: const Icon(Icons.sync),
      onPressed: () {
        ref.invalidate(tripsStreamProvider((from: '', to: '', driverId: null)));
        ref.invalidate(passengersStreamProvider);
        ref.invalidate(expensesStreamProvider);
        ref.invalidate(packagesStreamProvider);
        ref.invalidate(vehicleExpensesStreamProvider((from: '', to: '')));
        ref.invalidate(driversStreamProvider);
        ref.invalidate(vehiclesStreamProvider);
        ref.invalidate(profilesStreamProvider);
        ref.invalidate(assignmentsStreamProvider);
        ref.invalidate(managerEntriesStreamProvider);
        ref.invalidate(driverEntriesStreamProvider(''));
      },
    );
  }
}

/// Filtro de fechas reutilizable (Por aÃ±o / Desde-Hasta).
class DateFilterBar extends ConsumerWidget {
  final bool byYear;
  final int? selectedYear;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onYearChanged;
  final void Function(({DateTime from, DateTime to})) onRangeChanged;

  const DateFilterBar({
    super.key,
    required this.byYear,
    this.selectedYear,
    this.from,
    this.to,
    required this.onModeChanged,
    required this.onYearChanged,
    required this.onRangeChanged,
  });

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final initial = isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final newFrom = isFrom ? picked : (from ?? picked);
    final newTo = isFrom ? (to ?? picked) : picked;
    if (!newFrom.isAfter(newTo)) onRangeChanged((from: newFrom, to: newTo));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentYear = DateTime.now().year;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Por aÃ±o')),
                ButtonSegment(value: false, label: Text('Desde - Hasta')),
              ],
              selected: {byYear},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
            if (byYear) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: selectedYear ?? currentYear,
                decoration: labelText('AÃ±o'),
                items: [
                  for (var y = currentYear; y >= currentYear - 10; y--)
                    DropdownMenuItem(value: y, child: Text('$y'))
                ],
                onChanged: (y) {
                  if (y != null) onYearChanged(y);
                },
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context, true),
                      child: InputDecorator(
                        decoration: labelText('Desde'),
                        child: Text(from == null
                            ? 'Seleccionar'
                            : DateUtilsX.format(from!)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('â†’'),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context, false),
                      child: InputDecorator(
                        decoration: labelText('Hasta'),
                        child: Text(
                            to == null ? 'Seleccionar' : DateUtilsX.format(to!)),
                      ),
                    ),
                  ),
                ],
              ),
],
        ),
      ),
    );
}
  }

InputDecoration labelText(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatCard({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String money(double value) => '\$${value.toStringAsFixed(2)}';

/// Formatter que convierte el texto a mayúsculas al escribir.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// TextField que fuerza mayúsculas en la entrada.
/// Úsalo para campos de texto libre (nombres, observaciones, detalles).
/// No usar en passwords ni campos puramente numéricos.
class UpperCaseTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final String? hintText;

  const UpperCaseTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      );
}
