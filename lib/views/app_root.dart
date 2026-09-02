import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    // Mostrar errores de login como SnackBar global
    ref.listen(authStateProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final error = next.error;
        if (error is AuthException || error.toString().contains('AuthException')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendlyError(error!))),
          );
        }
      }
    });

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Scaffold(
        body: Center(child: CircularProgressIndicator()), // No mostrar error aquí, se maneja en listener
      ),
      data: (profile) {
        if (profile == null) return const LoginScreen();
        if (profile.isAdmin) return AdminHome(profile: profile);
        return DriverHome(profile: profile);
      },
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user not found') || msg.contains('invalid login credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }
    if (msg.contains('wrong password') || msg.contains('invalid credentials')) {
      return 'Contraseña incorrecta.';
    }
    if (msg.contains('email not confirmed') || msg.contains('unconfirmed')) {
      return 'El email no está confirmado. Revisa tu bandeja de entrada.';
    }
    if (msg.contains('deshabilitado') || msg.contains('disabled') || msg.contains('banned')) {
      return 'Tu cuenta está deshabilitada. Contacta al administrador.';
    }
    if (msg.contains('at least') || msg.contains('too short') || msg.contains('demasiado corta')) {
      return 'La contraseña es demasiado corta (mínimo 6 caracteres).';
    }
    if (msg.contains('too many') || msg.contains('rate limit') || msg.contains('muchos intentos')) {
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('timeout') || msg.contains('red')) {
      return 'Error de conexión. Revisa tu internet e inténtalo de nuevo.';
    }
    if (msg.contains('already') || msg.contains('ya existe') || msg.contains('duplicate')) {
      return 'Este usuario ya existe.';
    }
    return 'Error de autenticación. Revisa tu conexión e inténtalo de nuevo.';
  }
}
