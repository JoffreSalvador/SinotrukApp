import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_providers.dart';
import '../services/update_service.dart';
import 'admin/admin_home.dart';
import 'auth/login_screen.dart';
import 'driver/driver_home.dart';

/// Raíz de la app: enruta según el estado de sesión y revisa
/// actualizaciones una vez por arranque (aviso opcional, nunca bloquea).
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    if (_updateChecked) return;
    _updateChecked = true;

    int currentBuild = 0;
    try {
      final info = await PackageInfo.fromPlatform();
      currentBuild = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return;
    }

    AppRelease? release;
    try {
      release =
          await ref.read(updateServiceProvider).checkForUpdate(currentBuild: currentBuild);
    } catch (_) {
      return; // Sin red o sin tabla: la app sigue normal.
    }
    if (!mounted || release == null) return;

    final pending = release;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nueva versión disponible (${pending.version})'),
        content: Text(pending.changelog.isEmpty
            ? 'Hay una actualización lista para instalar.'
            : pending.changelog),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Actualizar ahora')),
        ],
      ),
    );
    if (go == true && mounted) _downloadAndInstall(pending);
  }

  Future<void> _downloadAndInstall(AppRelease release) async {
    final stream = ref.read(updateServiceProvider).downloadAndInstall(release);
    final installed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDownloadDialog(stream: stream),
    );
    if (installed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Confirma la instalación en la ventana del sistema')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

/// Diálogo de descarga con progreso. Al terminar, el plugin abre el
/// instalador del sistema (la confirmación final la hace Android).
class _UpdateDownloadDialog extends StatefulWidget {
  final Stream<OtaEvent> stream;

  const _UpdateDownloadDialog({required this.stream});

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  double _progress = 0;
  String? _error;
  StreamSubscription<OtaEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((event) {
      if (!mounted) return;
      switch (event.status) {
        case OtaStatus.DOWNLOADING:
          setState(() => _progress =
              ((double.tryParse(event.value ?? '') ?? 0) / 100).clamp(0.0, 1.0));
        case OtaStatus.INSTALLING:
          setState(() => _progress = 1);
        case OtaStatus.INSTALLATION_DONE:
          Navigator.of(context).pop(true);
        case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          setState(() => _error =
              'Permite "instalar apps desconocidas" para Sinotruk en Ajustes e inténtalo de nuevo.');
        case OtaStatus.DOWNLOAD_ERROR:
          setState(() => _error =
              'No se pudo descargar${event.value == null ? '.' : ': ${event.value}'} Revisa tu conexión.');
        case OtaStatus.INSTALLATION_ERROR:
          setState(() => _error =
              'El instalador falló${event.value == null ? '.' : ': ${event.value}'}');
        case OtaStatus.CHECKSUM_ERROR:
          setState(() => _error =
              'El archivo descargado no coincide con el publicado. No se instaló nada.');
        case OtaStatus.ALREADY_RUNNING_ERROR:
          setState(() => _error = 'Ya hay una descarga en curso.');
        case OtaStatus.CANCELED:
          Navigator.of(context).pop(false);
        case OtaStatus.INTERNAL_ERROR:
          setState(() => _error =
              'Error interno${event.value == null ? '.' : ': ${event.value}'}');
      }
    }, onError: (Object e) {
      if (mounted) setState(() => _error = 'Error de descarga: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Descargando actualización'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error == null) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).round()}%'),
          ] else
            Text(_error!),
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cerrar'))
        else
          TextButton(
              onPressed: () async {
                await OtaUpdate().cancel();
                if (context.mounted) Navigator.pop(context, false);
              },
              child: const Text('Cancelar')),
      ],
    );
  }
}
