import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Autenticación por username con emails sintéticos u-<username>@sinotruk.app
/// y detección del bootstrap del admin (primer acceso).
class AuthService {
  final SupabaseClient client;

  AuthService(this.client);

  static SupabaseAuthService fromDefault() =>
      SupabaseAuthService(Supabase.instance.client);

  String syntheticEmail(String username) =>
      'u-${username.trim().toLowerCase()}@sinotruk.app';
}

class SupabaseAuthService extends AuthService {
  SupabaseAuthService(super.client);

  /// true mientras la tabla profiles esté vacía -> mostrar "Primer acceso".
  Future<bool> needsBootstrap() async {
    try {
      final result = await client.rpc('app_needs_bootstrap');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Crea el admin inicial (solo válido cuando profiles está vacía).
  Future<void> bootstrapAdmin({
    required String username,
    required String password,
    String name = 'Administrador',
  }) async {
    try {
      await client.auth.signUp(
        email: syntheticEmail(username),
        password: password,
        data: {'name': name, 'username': username, 'role': 'admin'},
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<Profile> login({
    required String username,
    required String password,
  }) async {
    try {
      await client.auth.signInWithPassword(
        email: syntheticEmail(username),
        password: password,
      );
      return currentProfile();
    } on AuthException catch (e) {
      // Re-lanzar con mensaje original de Supabase para mejor diagnóstico
      throw AuthException(e.message);
    }
  }

  /// Perfil del usuario logueado. Lanza si está deshabilitado.
  Future<Profile> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sesión no iniciada');
    }
    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final profile = Profile.fromMap(Map<String, dynamic>.from(row));
    if (!profile.isActive) {
      await logout();
      throw const AuthException(
        'Tu usuario está deshabilitado. Contacta al administrador.',
      );
    }
    return profile;
  }

  Future<Profile?> maybeCurrentProfile() async {
    if (client.auth.currentUser == null) return null;
    try {
      return await currentProfile();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => client.auth.signOut();
}