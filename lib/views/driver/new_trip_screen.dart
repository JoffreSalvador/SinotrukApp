import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

/// Formulario dinámico de viaje:
///  - Pasajeros 0-4 (se despliegan formularios al elegir cantidad)
///  - Encomiendas 0-n (botón agregar/quitar)
///  - Gastos del viaje para reembolso (Gasolina, Conductor, Peajes, Otros)
///  - Observaciones
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key});

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

abstract class _DetailForm {
  final departure = TextEditingController();
  final arrival = TextEditingController();
  final cost = TextEditingController();
  PaymentType payment = PaymentType.efectivo;

  void dispose() {
    departure.dispose();
    arrival.dispose();
    cost.dispose();
  }
}

class _PassengerForm extends _DetailForm {}

class _PackageForm extends _DetailForm {}

class _ExpenseForm {
  final detail = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    detail.dispose();
    amount.dispose();
  }
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  DateTime _tripDate = DateTime.now();
  int _passengerCount = 0;
  final List<_PackageForm> _packages = [];
  final Map<ExpenseCategory, _ExpenseForm> _expenses = {};
  final _observationsCtrl = TextEditingController();
  bool _saving = false;

  void _resetForm() {
    setState(() {
      _passengerCount = 0;
      _packages.clear();
      _expenses.clear();
      _passengerForms.clear();
      _observationsCtrl.clear();
      _tripDate = DateTime.now();
    });
  }

  @override
  void dispose() {
    for (final p in _packages) {
      p.dispose();
    }
    for (final e in _expenses.values) {
      e.dispose();
    }
    _observationsCtrl.dispose();
    super.dispose();
  }

  void _setPassengerCount(int count) {
    setState(() => _passengerCount = count.clamp(0, 4));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _tripDate = picked);
  }

  double get _totalIngreso {
    var total = 0.0;
    for (final entry in _passengerForms.entries) {
      if (entry.key < _passengerCount) {
        total +=
            double.tryParse(entry.value.cost.text.replaceAll(',', '')) ?? 0;
      }
    }
    total += _sumControllers(_packages.map((p) => p.cost));
    return total;
  }

  double _sumControllers(Iterable<TextEditingController> ctrls) {
    var total = 0.0;
    for (final c in ctrls) {
      total += double.tryParse(c.text.replaceAll(',', '')) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final tripId = const Uuid().v4();

    final passengersData = <TripPassenger>[];
    for (final entry in _passengerForms.entries) {
      final f = entry.value;
      if (!_validateDetail(f.departure, f.arrival, f.cost)) {
        return;
      }
      passengersData.add(TripPassenger(
        id: const Uuid().v4(),
        tripId: tripId,
        departure: f.departure.text.trim(),
        arrival: f.arrival.text.trim(),
        cost: double.parse(f.cost.text.replaceAll(',', '')),
        paymentMethod: f.payment.dbValue,
      ));
    }

    final packagesData = <TripPackage>[];
    for (final p in _packages) {
      if (!_validateDetail(p.departure, p.arrival, p.cost)) {
        return;
      }
      packagesData.add(TripPackage(
        id: const Uuid().v4(),
        tripId: tripId,
        departure: p.departure.text.trim(),
        arrival: p.arrival.text.trim(),
        cost: double.parse(p.cost.text.replaceAll(',', '')),
        paymentMethod: p.payment.dbValue,
      ));
    }

    final expensesData = <TripExpense>[];
    _expenses.forEach((category, form) {
      final amount =
          double.tryParse(form.amount.text.replaceAll(',', '')) ?? 0;
      if (amount > 0) {
        expensesData.add(TripExpense(
          id: const Uuid().v4(),
          tripId: tripId,
          category: category.dbValue,
          detail: category == ExpenseCategory.otros
              ? (form.detail.text.trim().isEmpty
                  ? null
                  : form.detail.text.trim())
              : null,
          amount: amount,
        ));
      }
    });

    final trip = Trip(
      id: tripId,
      driverId: profile.id,
      tripDate: DateUtilsX.format(_tripDate),
      observations:
          _observationsCtrl.text.trim().isEmpty
              ? null
              : _observationsCtrl.text.trim(),
    );

    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).saveTripFull(
            trip: trip,
            passengers: passengersData,
            packages: packagesData,
            expenses: expensesData,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje guardado')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validateDetail(TextEditingController dep, TextEditingController arr,
      TextEditingController cost) {
    if (dep.text.trim().isEmpty ||
        arr.text.trim().isEmpty ||
        (double.tryParse(cost.text.replaceAll(',', '')) ?? -1) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Completa salida, llegada y costo válido en cada pasajero/encomienda.'),
      ));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo viaje')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text('Fecha: ${DateUtilsX.format(_tripDate)}'),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Cambiar'),
              ),
            ),
          ),
          _sectionTitle('Pasajeros (0-4)'),
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i <= 4; i++)
                ButtonSegment(value: i, label: Text('$i'))
            ],
            selected: {_passengerCount},
            onSelectionChanged: (s) => _setPassengerCount(s.first),
          ),
          ..._buildPassengerForms(),
          _sectionTitle('Encomiendas'),
          ..._buildPackageForms(),
          OutlinedButton.icon(
            onPressed: () => setState(() => _packages.add(_PackageForm())),
            icon: const Icon(Icons.add),
            label: const Text('Agregar encomienda'),
          ),
          _sectionTitle('Gastos del viaje (reembolsables)'),
          ..._buildExpenseFields(),
          _sectionTitle('Observaciones'),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: UpperCaseTextField(
              controller: _observationsCtrl,
              maxLines: 3,
              label: 'Observaciones',
              hintText: 'Notas adicionales del viaje (opcional)',
            ),
          ),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              title: const Text('Total ingreso del viaje'),
              trailing: Text(money(_totalIngreso),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar viaje'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  // ---- pasajeros ----

  final Map<int, _PassengerForm> _passengerForms = {};

  List<Widget> _buildPassengerForms() {
    final widgets = <Widget>[];
    for (var i = 0; i < _passengerCount; i++) {
      final form = _passengerForms.putIfAbsent(i, _PassengerForm.new);
      widgets.add(_personFormCard(
        key: ValueKey('passenger_$i'),
        index: i + 1,
        icon: Icons.person,
        form: form,
      ));
    }
    // Libera formularios sobrantes al reducir la cantidad.
    final extraKeys =
        _passengerForms.keys.where((k) => k >= _passengerCount).toList();
    for (final k in extraKeys) {
      _passengerForms.remove(k)?.dispose();
    }
    return widgets;
  }

  List<Widget> _buildPackageForms() {
    final widgets = <Widget>[];
    for (var i = 0; i < _packages.length; i++) {
      widgets.add(_personFormCard(
        key: ValueKey('package_$i'),
        index: i + 1,
        icon: Icons.inventory_2,
        form: _packages[i],
        onDelete: _packages.isNotEmpty
            ? () => setState(() {
                  _packages.removeAt(i).dispose();
                })
            : null,
      ));
    }
    return widgets;
  }

  List<Widget> _buildExpenseFields() {
    const categories = ExpenseCategory.values;
    return [
      for (final c in categories)
        _expenseTile(c),
    ];
  }

  Widget _expenseTile(ExpenseCategory category) {
    final form = _expenses.putIfAbsent(category, _ExpenseForm.new);
    final isOther = category == ExpenseCategory.otros;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(category.dbValue,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: form.amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                ),
              ],
            ),
            if (isOther)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: UpperCaseTextField(
                  controller: form.detail,
                  label: 'Detalle *',
                  hintText: 'Requerido si ingresa valor en "Otros"',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _personFormCard({
    required Key key,
    required int index,
    required IconData icon,
    required _DetailForm form,
    VoidCallback? onDelete,
  }) =>
      Card(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('#$index',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.danger),
                    onPressed: onDelete,
                  ),
              ]),
              UpperCaseTextField(
                controller: form.departure,
                label: 'Punto de salida',
              ),
              const SizedBox(height: 8),
              UpperCaseTextField(
                controller: form.arrival,
                label: 'Punto de llegada',
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: form.cost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Costo del viaje'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: form.payment.dbValue,
                    items: const [
                      DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'Empresa', child: Text('Empresa')),
                    ],
                    onChanged: (v) {
                      if (v == 'Efectivo') {
                        form.payment = PaymentType.efectivo;
                      } else if (v == 'Empresa') {
                        form.payment = PaymentType.empresa;
                      }
                      setState(() {});
                    },
                    decoration: const InputDecoration(labelText: 'Tipo de pago'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}
