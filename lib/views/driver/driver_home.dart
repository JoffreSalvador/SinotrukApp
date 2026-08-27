import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import 'my_trips_screen.dart';
import 'new_trip_screen.dart';
import 'trip_summary_screen.dart';
import 'driver_accounts_screen.dart';

/// Home del chofer con navegación por pestañas.
class DriverHome extends ConsumerStatefulWidget {
  final Profile profile;

  const DriverHome({super.key, required this.profile});

  @override
  ConsumerState<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends ConsumerState<DriverHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      MyTripsScreen(key: ValueKey('trips-$_index')),
      const TripSummaryScreen(),
      const DriverAccountsScreen(),
      const NewTripScreen(),
    ];

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            title: Text('Hola, ${widget.profile.name}'),
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
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Mis viajes'),
          NavigationDestination(icon: Icon(Icons.summarize), label: 'Resumen'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Cuentas'),
          NavigationDestination(icon: Icon(Icons.add_road), label: 'Nuevo'),
        ],
      ),
    );
  }
}
