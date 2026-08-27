import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstraccion para poder mockear en tests.
abstract class FunctionsApi {
  Future<Map<String, dynamic>> invoke(String name, Map<String, dynamic> body);
}

class SupabaseFunctionsApi implements FunctionsApi {
  final SupabaseClient client;

  SupabaseFunctionsApi(this.client);

  @override
  Future<Map<String, dynamic>> invoke(
      String name, Map<String, dynamic> body) async {
    final response = await client.functions.invoke(name,
        body: body,
        headers: {'Content-Type': 'application/json'});
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return {};
  }
}

/// Operaciones administrativas que requieren service_role
/// (se ejecutan como Edge Functions desplegadas en Supabase).
class AdminUserService {
  final FunctionsApi functions;

  AdminUserService(this.functions);

  Future<void> createUser({
    required String name,
    required String username,
    required String password,
    String role = 'driver',
  }) async {
    _throwIfError(await functions.invoke('create-user', {
      'name': name,
      'username': username,
      'password': password,
      'role': role,
    }));
  }

  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    _throwIfError(await functions.invoke('reset-password', {
      'user_id': userId,
      'new_password': newPassword,
    }));
  }

  Future<void> deleteUser(String userId) async {
    _throwIfError(
        await functions.invoke('delete-user', {'user_id': userId}));
  }

  void _throwIfError(Map<String, dynamic> response) {
    final error = response['error'];
    if (error != null) throw Exception(error.toString());
  }
}
