import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ReportsScreen(),
      const UsersScreen(),
      const FleetScreen(),
      const VehicleExpensesScreen(),
      const ManagerAccountsScreen(),
    ];

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            title: Text('Admin · ${widget.profile.name}'),
            actions: [
              const SyncBadge(),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () =>
                    ref.read(authStateProvider.notifier).logout(),
              ),
            ],
            floating: true,
          ),
        ],
        body: screens[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Usuarios'),
          NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Flota'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Gastos V.'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Gerente'),
        ],
      ),
    );
  }
}
