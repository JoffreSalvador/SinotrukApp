import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/stream_providers.dart';
import '../../widgets/common_widgets.dart';

/// Flota: vehículos, conductores y asignaciones (realtime).
class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);
    final driversAsync = ref.watch(driversStreamProvider);
    final assignmentsAsync = ref.watch(assignmentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flota'),
        actions: [
          IconButton(icon: const Icon(Icons.directions_car), onPressed: () => _showAddVehicle(context, ref)),
          IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () => _showAssign(context, ref)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const ListTile(
              title: Text('Vehículos', style: TextStyle(fontWeight: FontWeight.bold))),
          vehiclesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (vehicles) => Column(
              children: [
                for (final v in vehicles)
                  ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text(v.plate),
                    subtitle: Text([v.brand, v.model].whereType<String>().join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      onPressed: () => _deleteVehicle(context, ref, v.id),
                    ),
                  ),
                if (vehicles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin vehículos registrados'),
                  ),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
              title: Text('Conductores', style: TextStyle(fontWeight: FontWeight.bold))),
          driversAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (drivers) => Column(
              children: [
                for (final d in drivers)
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: Text(d.name),
                    subtitle: Text(d.username),
                  ),
                if (drivers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin conductores registrados'),
                  ),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
              title: Text('Asignaciones', style: TextStyle(fontWeight: FontWeight.bold))),
          // Asignaciones
          assignmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (assignments) {
              final vehicles = vehiclesAsync.value ?? [];
              final drivers = driversAsync.value ?? [];
              return Column(
                children: [
                  for (final a in assignments) ...[
                    ListTile(
                      leading: Icon(a.isActive ? Icons.link : Icons.link_off,
                          color: a.isActive ? null : Colors.grey),
                      title: _vehicleName(a.vehicleId, vehicles),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _driverName(a.driverId, drivers),
                          Text(a.isActive
                              ? 'Asignado: ${a.assignedDate}'
                              : '${a.assignedDate} → ${a.unassignedDate ?? '-'}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                        onPressed: () => _deleteAssignment(context, ref, a.id),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  if (assignments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sin asignaciones registradas'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddVehicle(BuildContext context, WidgetRef ref) async {
    final plateCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UpperCaseTextField(controller: plateCtrl, label: 'Placa *'),
            UpperCaseTextField(controller: brandCtrl, label: 'Marca'),
            UpperCaseTextField(controller: modelCtrl, label: 'Modelo'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || plateCtrl.text.trim().isEmpty) return;

    try {
      await ref.read(adminRepositoryProvider).addVehicle(Vehicle(
            id: const Uuid().v4(),
            plate: plateCtrl.text.trim().toUpperCase(),
            brand: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
            model: modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
          ));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo guardado')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _deleteVehicle(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehículo?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteVehicle(id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo eliminado')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _deleteAssignment(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar asignación?'),
        content: const Text('¿Estás seguro de eliminar esta asignación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteAssignment(id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asignación eliminada')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Widget _vehicleName(String vehicleId, List<Vehicle> vehicles) {
    final v = vehicles.firstWhere((v) => v.id == vehicleId, orElse: () => Vehicle(id: vehicleId, plate: vehicleId, brand: null, model: null));
    return Text([v.brand, v.model, v.plate].whereType<String>().join(' · '));
  }

  Widget _driverName(String driverId, List<Profile> drivers) {
    final d = drivers.firstWhere((d) => d.id == driverId, orElse: () => Profile(id: driverId, name: driverId, username: '', role: 'driver'));
    return Text(d.name);
  }

  Future<void> _showAssign(BuildContext context, WidgetRef ref) async {
    final vehiclesAsync = ref.read(vehiclesStreamProvider.future);
    final driversAsync = ref.read(driversStreamProvider.future);
    final vehicles = await vehiclesAsync;
    final drivers = await driversAsync;

    if (vehicles.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registra al menos un vehículo y un conductor primero.')));
      return;
    }
    String? vehicleId = vehicles.first.id;
    String? driverId = drivers.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Asignar vehículo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: vehicleId,
                items: vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.plate))).toList(),
                onChanged: (v) => setDlg(() => vehicleId = v),
                decoration: const InputDecoration(labelText: 'Vehículo'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: driverId,
                items: drivers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (v) => setDlg(() => driverId = v),
                decoration: const InputDecoration(labelText: 'Conductor'),
              ),
              const SizedBox(height: 8),
              Text('Fecha: ${DateUtilsX.today()}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Asignar')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(adminRepositoryProvider).assign(vehicleId: vehicleId!, driverId: driverId!, date: DateUtilsX.today());
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asignación creada')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    }
  }
}