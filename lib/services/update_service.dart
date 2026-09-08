import 'package:ota_update/ota_update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Release publicado para actualización in-app (tabla `app_releases`).
class AppRelease {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String? sha256;
  final String changelog;

  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.sha256,
    this.changelog = '',
  });

  factory AppRelease.fromMap(Map<String, dynamic> map) => AppRelease(
        version: (map['version'] ?? '') as String,
        buildNumber: (map['build_number'] as num?)?.toInt() ?? 0,
        apkUrl: (map['apk_url'] ?? '') as String,
        sha256: map['sha256'] as String?,
        changelog: (map['changelog'] ?? '') as String,
      );
}

/// Consulta de actualizaciones y descarga/instalación del APK.
/// Todo fallo aquí es silencioso para el llamador: nunca debe bloquear la app.
class UpdateService {
  final SupabaseClient _client;

  UpdateService(this._client);

  /// Hay actualización solo si el build remoto es MAYOR al instalado.
  static bool isNewer({required int currentBuild, required int remoteBuild}) =>
      remoteBuild > currentBuild;

  Future<AppRelease?> latestRelease() async {
    final rows = await _client
        .from('app_releases')
        .select()
        .order('build_number', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return AppRelease.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  /// Devuelve el release a instalar, o null si ya está al día.
  Future<AppRelease?> checkForUpdate({required int currentBuild}) async {
    final release = await latestRelease();
    if (release == null) return null;
    if (release.apkUrl.isEmpty) return null;
    if (!isNewer(currentBuild: currentBuild, remoteBuild: release.buildNumber)) {
      return null;
    }
    return release;
  }

  /// Descarga el APK y lanza el instalador del sistema.
  /// Si [AppRelease.sha256] viene informado, el plugin verifica la
  /// integridad del archivo antes de instalar.
  Stream<OtaEvent> downloadAndInstall(AppRelease release) {
    return OtaUpdate().execute(
      release.apkUrl,
      destinationFilename: 'sinotruk-update.apk',
      sha256checksum: release.sha256,
    );
  }
}
