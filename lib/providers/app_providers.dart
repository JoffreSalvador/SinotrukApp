import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/environment.dart';
import '../core/utils/account_adjustments.dart';
import '../models/profile.dart';
import '../repositories/repositories.dart';
import '../services/auth_service.dart';
import '../services/admin_user_service.dart';
import 'core_providers.dart';
import 'stream_providers.dart';

final authServiceProvider = Provider<SupabaseAuthService>(
    (ref) => SupabaseAuthService(ref.watch(supabaseClientProvider)));

final tripRepositoryProvider = Provider<TripRepository>(
    (ref) => TripRepository(ref.watch(supabaseClientProvider)));

final driverAccountRepositoryProvider = Provider<DriverAccountRepository>(
    (ref) => DriverAccountRepository(ref.watch(supabaseClientProvider)));

final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepository(ref.watch(supabaseClientProvider)));

final managerAccountRepositoryProvider = Provider<ManagerAccountRepository>(
    (ref) => ManagerAccountRepository(ref.watch(supabaseClientProvider)));

final functionsApiProvider = Provider<FunctionsApi>(
    (ref) => SupabaseFunctionsApi(ref.watch(supabaseClientProvider)));

final adminUserServiceProvider = Provider<AdminUserService>(
    (ref) => AdminUserService(ref.watch(functionsApiProvider)));

/// Estado de sesión: perfil del usuario logueado o null.
class AuthState extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    return ref.read(authServiceProvider).maybeCurrentProfile();
  }

  Future<bool> login(String username, String password) async {
    // Capturar estado actual ANTES de cambiar a loading
    final previousState = state;
    state = const AsyncLoading();
    try {
      final profile = await ref.read(authServiceProvider).login(
            username: username,
            password: password,
          );
      state = AsyncData(profile);
      return true;
    } catch (e) {
      // Restaurar estado anterior (que era AsyncData(null) al inicio)
      state = previousState;
      rethrow;
    }
  }

  Future<void> bootstrapAdmin(String username, String password) async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).bootstrapAdmin(
            username: username,
            password: password,
          );
      final profile = await ref.read(authServiceProvider).currentProfile();
      state = AsyncData(profile);
    } catch (e) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthState, Profile?>(AuthState.new);

/// Provider para el ajuste de cuentas del chofer (recalcula al cambiar entries)
final adjustmentProvider = FutureProvider.autoDispose.family<DriverAccountAdjustment, String>((ref, driverId) async {
  return ref.read(driverAccountRepositoryProvider).adjustment(driverId);
});

/// Provider para el ajuste de cuentas admin-gerente
final managerAdjustmentProvider = FutureProvider.autoDispose<ManagerAccountAdjustment>((ref) async {
  return ref.read(managerAccountRepositoryProvider).adjustment();
});