import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'admin/admin_home.dart';
import 'auth/login_screen.dart';
import 'driver/driver_home.dart';

/// Raíz de la app: enruta según el estado de sesión.
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Scaffold(
        body: Center(child: Text('Error de sesión. Reinicia la app.')),
      ),
      data: (profile) {
        if (profile == null) return const LoginScreen();
        if (profile.isAdmin) return AdminHome(profile: profile);
        return DriverHome(profile: profile);
      },
    );
  }
}
