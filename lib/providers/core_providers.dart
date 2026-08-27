import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Proveedores base que no dependen de nada más (evita ciclos).
final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final supabaseUrlProvider = Provider<String>((ref) {
  // Se usa en bootstrap; se inicializa en main.dart
  throw UnimplementedError('Inicializar en bootstrap()');
});