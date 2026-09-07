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
        final profile = ref.read(authStateProvider).valueOrNull;
        ref.invalidate(passengersStreamProvider);
        ref.invalidate(expensesStreamProvider);
        ref.invalidate(packagesStreamProvider);
        ref.invalidate(driversStreamProvider);
        ref.invalidate(vehiclesStreamProvider);
        ref.invalidate(profilesStreamProvider);
        ref.invalidate(assignmentsStreamProvider);
        ref.invalidate(managerEntriesStreamProvider);
        if (profile != null) {
          ref.invalidate(driverEntriesStreamProvider(profile.id));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronizando...')),
        );
      },
    );
  }
}

/// Filtro de fechas reutilizable (Por año / Desde-Hasta).
/// En modo Desde-Hasta las fechas se editan como borrador y solo se aplican
/// al pulsar "Filtrar". "Limpiar" descarta el borrador y vuelve al defecto.
class DateFilterBar extends StatefulWidget {
  final bool byYear;
  final int? selectedYear;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onYearChanged;
  final void Function(({DateTime from, DateTime to})) onRangeChanged;
  final VoidCallback onRangeCleared;

  const DateFilterBar({
    super.key,
    required this.byYear,
    this.selectedYear,
    this.from,
    this.to,
    required this.onModeChanged,
    required this.onYearChanged,
    required this.onRangeChanged,
    required this.onRangeCleared,
  });

  @override
  State<DateFilterBar> createState() => _DateFilterBarState();
}

class _DateFilterBarState extends State<DateFilterBar> {
  DateTime? _draftFrom;
  DateTime? _draftTo;

  @override
  void initState() {
    super.initState();
    _draftFrom = widget.from;
    _draftTo = widget.to;
  }

  @override
  void didUpdateWidget(DateFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.from != oldWidget.from || widget.to != oldWidget.to) {
      _draftFrom = widget.from;
      _draftTo = widget.to;
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial =
        isFrom ? (_draftFrom ?? DateTime.now()) : (_draftTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _draftFrom = picked;
      } else {
        _draftTo = picked;
      }
    });
  }

  bool get _canApply =>
      _draftFrom != null &&
      _draftTo != null &&
      !_draftFrom!.isAfter(_draftTo!) &&
      (_draftFrom != widget.from || _draftTo != widget.to);

  bool get _canClear =>
      _draftFrom != null ||
      _draftTo != null ||
      widget.from != null ||
      widget.to != null;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Por año')),
                ButtonSegment(value: false, label: Text('Desde - Hasta')),
              ],
              selected: {widget.byYear},
              onSelectionChanged: (s) => widget.onModeChanged(s.first),
            ),
            if (widget.byYear) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: widget.selectedYear ?? currentYear,
                decoration: labelText('Año'),
                items: [
                  for (var y = currentYear; y >= currentYear - 10; y--)
                    DropdownMenuItem(value: y, child: Text('$y'))
                ],
                onChanged: (y) {
                  if (y != null) widget.onYearChanged(y);
                },
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: InputDecorator(
                        decoration: labelText('Desde'),
                        child: Text(_draftFrom == null
                            ? 'Seleccionar'
                            : DateUtilsX.format(_draftFrom!)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-'),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: InputDecorator(
                        decoration: labelText('Hasta'),
                        child: Text(_draftTo == null
                            ? 'Seleccionar'
                            : DateUtilsX.format(_draftTo!)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canApply
                          ? () => widget.onRangeChanged(
                              (from: _draftFrom!, to: _draftTo!))
                          : null,
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Filtrar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canClear
                          ? () {
                              setState(() {
                                _draftFrom = null;
                                _draftTo = null;
                              });
                              widget.onRangeCleared();
                            }
                          : null,
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                    ),
                  ),
                ],
              ),
            ],
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
