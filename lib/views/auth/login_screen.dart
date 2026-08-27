import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Login por usuario/contraseña. Si la app aun no tiene ningun usuario,
/// muestra "Primer acceso" para crear al administrador (bootstrap).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool? _needsBootstrap;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _detectBootstrap();
  }

  Future<void> _detectBootstrap() async {
    try {
      final needs = await ref.read(authServiceProvider).needsBootstrap();
      if (mounted) setState(() { _needsBootstrap = needs; _checking = false; });
    } catch (_) {
      if (mounted) setState(() { _needsBootstrap = false; _checking = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authStateProvider.notifier);
    try {
      if (_needsBootstrap == true) {
        await auth.bootstrapAdmin(
          _usernameCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }
    if (msg.contains('deshabilitado')) {
      return msg.replaceFirst('AuthException: ', '');
    }
    if (msg.toLowerCase().contains('at least')) {
      return 'La contraseña es demasiado corta.';
    }
    return 'Error de autenticación. Revisa tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isLoading = authAsync.isLoading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.local_shipping,
                      size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Sinotruk Transport',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (_checking)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    if (_needsBootstrap == true) ...[
                      Card(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Primer acceso: esta cuenta se convertirá en '
                            'la cuenta ADMINISTRADOR del sistema.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Usuario'),
                      autocorrect: false,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_needsBootstrap == true
                              ? 'Crear administrador'
                              : 'Ingresar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
