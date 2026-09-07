import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common_widgets.dart';

/// Stream de perfiles en tiempo real.
final profilesStreamProvider = StreamProvider.autoDispose<List<Profile>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map((r) => Profile.fromMap(Map<String, dynamic>.from(r))).toList());
});

/// Gestión de usuarios: crear (Edge Function), resetear contraseña,
/// habilitar/deshabilitar y eliminar.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profiles) => ListView.builder(
          itemCount: profiles.length,
          itemBuilder: (_, i) {
            final p = profiles[i];
            return ListTile(
              leading: Icon(
                p.isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: p.isActive ? null : AppTheme.danger,
              ),
              title: Text(
                '${p.name} (${p.username})',
                style: TextStyle(
                  decoration: p.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                '${p.isAdmin ? "Administrador" : "Conductor"} · '
                '${p.isActive ? "Habilitado" : "Deshabilitado"}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'toggle':
                      _toggleActive(ref, p);
                    case 'reset':
                      _showResetDialog(context, ref, p);
                    case 'delete':
                      _showDeleteDialog(context, ref, p);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(p.isActive ? 'Deshabilitar' : 'Habilitar'),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Cambiar contraseña'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar usuario'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var role = 'driver';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UpperCaseTextField(controller: nameCtrl, label: 'Nombre'),
              const SizedBox(height: 8),
              TextField(controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario')),
              const SizedBox(height: 8),
              TextField(controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'driver', child: Text('Conductor')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (v) => setDlg(() => role = v ?? 'driver'),
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(adminUserServiceProvider).createUser(
            name: nameCtrl.text.trim(),
            username: userCtrl.text.trim(),
            password: passCtrl.text,
            role: role,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref, Profile profile) async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscurePass = true;
    var obscureConfirm = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Nueva contraseña para ${profile.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: obscurePass,
                decoration: InputDecoration(
                  labelText: 'Contraseña nueva',
                  suffixIcon: IconButton(
                    tooltip: obscurePass ? 'Mostrar' : 'Ocultar',
                    icon: Icon(obscurePass
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setDlg(() => obscurePass = !obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  suffixIcon: IconButton(
                    tooltip: obscureConfirm ? 'Mostrar' : 'Ocultar',
                    icon: Icon(obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setDlg(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (passCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa y confirma la contraseña')));
      }
      return;
    }
    if (passCtrl.text != confirmCtrl.text) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      }
      return;
    }
    if (passCtrl.text.length < 6) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')));
      }
      return;
    }
    try {
      await ref.read(adminUserServiceProvider).resetPassword(
            userId: profile.id,
            newPassword: passCtrl.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _toggleActive(WidgetRef ref, Profile profile) async {
    await ref.read(adminRepositoryProvider).setActive(profile.id, !profile.isActive);
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref, Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar a ${profile.username}?'),
        content: const Text('Se eliminará el usuario y todos sus datos. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminUserServiceProvider).deleteUser(profile.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }
}