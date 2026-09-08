import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'driver_accounts_admin_screen.dart';
import 'fleet_screen.dart';
import 'manager_accounts_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';
import 'vehicle_expenses_screen.dart';

/// Home del administrador con acceso a gestión y reportes.
class AdminHome extends ConsumerStatefulWidget {
  final Profile profile;

  const AdminHome({super.key, required this.profile});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _index = 0;

  /// Última pantalla de Operación visitada: la barra inferior solo tiene
  /// esos 4 destinos y conserva su resaltado al entrar a Administración.
  int _lastMain = 0;

  static const _mains = [0, 3, 4, 5];

  /// Índice resaltado en la barra (0 Reportes, 1 Gastos V., 2 Gerente, 3 Cuentas).
  int get _barIndex => _mains.indexOf(_lastMain);

  void _go(int i) {
    setState(() {
      _index = i;
      if (_mains.contains(i)) _lastMain = i;
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(authStateProvider.notifier).logout();
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String label,
    required int index,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: _index == index,
      onTap: () {
        Navigator.pop(context);
        _go(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ReportsScreen(),
      const UsersScreen(),
      const FleetScreen(),
      const VehicleExpensesScreen(),
      const ManagerAccountsScreen(),
      const DriverAccountsAdminScreen(),
    ];

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            title: Text('Admin · ${widget.profile.name}'),
            actions: const [
              SyncBadge(),
            ],
            floating: true,
          ),
        ],
        body: screens[_index],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                color: AppTheme.header,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_shipping,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Admin · ${widget.profile.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sectionLabel('Operación'),
                    _drawerTile(
                        icon: Icons.bar_chart,
                        label: 'Reportes',
                        index: 0),
                    _drawerTile(
                        icon: Icons.receipt_long,
                        label: 'Gastos V.',
                        index: 3),
                    _drawerTile(
                        icon: Icons.account_balance,
                        label: 'Gerente',
                        index: 4),
                    _drawerTile(
                        icon: Icons.account_balance_wallet,
                        label: 'Cuentas',
                        index: 5),
                    const Divider(),
                    _sectionLabel('Administración'),
                    _drawerTile(
                        icon: Icons.people, label: 'Usuarios', index: 1),
                    _drawerTile(
                        icon: Icons.local_shipping,
                        label: 'Flota',
                        index: 2),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout();
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _barIndex,
        onDestinationSelected: (i) => _go(_mains[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reportes'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Gastos V.'),
          NavigationDestination(
              icon: Icon(Icons.account_balance), label: 'Gerente'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Cuentas'),
        ],
      ),
    );
  }
}
