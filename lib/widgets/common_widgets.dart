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

InputDecoration labelText(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());

/// Panel de filtro con despliegue animado (en vez de aparecer de golpe).
class AnimatedFilterPanel extends StatelessWidget {
  final bool expanded;
  final Widget child;

  const AnimatedFilterPanel(
      {super.key, required this.expanded, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: expanded
            ? child
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

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
