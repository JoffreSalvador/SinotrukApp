# Fase 2 — Motor de Sincronización Offline (sqflite)

## Estrategia offline-first

```
ESCRITURA (siempre funciona, con o sin red)
  UI -> LocalDatabase.upsertLocal() -> sqflite + pending_ops (cola FIFO)

SINCRONIZACION (cuando hay red)
  PUSH: SyncEngine.pushPendingOps()
        drena pending_ops en orden hacia Supabase (upsert/delete),
        marca filas is_synced=1 y borra la op de la cola.
        Ante error se detiene y reintenta luego (orden causal preservado).
  PULL: SyncEngine.pullTable(table)
        refresca cada tabla desde la nube SIN sobreescribir filas
        locales con is_synced=0 (nunca se pierde trabajo del chofer).

DISPARADORES
  - Reconexión de red (connectivity_plus) -> syncAll()
  - Al iniciar sesión / abrir pantallas clave (Fase 3)
```

## Archivos entregados

| Archivo | Responsabilidad |
|---|---|
| `lib/core/config/environment.dart` | Lee SUPABASE_URL / SUPABASE_ANON_KEY de `.env` |
| `lib/core/constants/db_schema.dart` | Nombres de tablas, columnas, tipos de op |
| `lib/core/utils/enums.dart` | Enums ↔ valores de BD (`Efectivo/Empresa`, categorías…) |
| `lib/core/utils/payment_math.dart` | Suma/redondeo/porcentaje sin errores float |
| `lib/core/utils/account_adjustments.dart` | Ajuste conductor-empleador y admin-gerente |
| `lib/models/*` | Modelos con serialización tolerante a nulos (sqflite + PostgREST) |
| `lib/services/local_database.dart` | sqflite, esquema local, cola `pending_ops`, upserts |
| `lib/services/remote_data_source.dart` | Interfaz remota (mockeable) |
| `lib/services/supabase_remote_data_source.dart` | Implementación real sobre `supabase_flutter` |
| `lib/services/sync_engine.dart` | PUSH/PULL/syncAll |
| `lib/services/connectivity_service.dart` | Detección online/offline |

## Tests

```powershell
flutter pub get
flutter test
```

| Suite | Qué valida |
|---|---|
| `test/core/financial_logic_test.dart` | Fórmulas exactas de "Ajuste de Cuentas" (conductor y gerente), redondeos, nulos |
| `test/models/models_serialization_test.dart` | Serialización dual y tolerancia a nulos |
| `test/services/sync_engine_test.dart` | **Integración**: cola sqflite → nube con mock del backend (mocktail + sqflite in-memory): FIFO, reintento tras fallo, pull no pisa cambios locales, syncAll completo |

## Notas

- Los IDs son UUID generados en el cliente: no hay colisiones al sincronizar.
- La app nunca bloquea al usuario por falta de red; todo escribe primero en local.
- Para correr los tests en Windows se usa `sqflite_common_ffi` (ya incluido en dev_dependencies).

## Pendiente para instalar Flutter en esta máquina

1. Instalar Flutter SDK y agregarlo al PATH.
2. `flutter create . --org com.sinotruk` (genera carpetas android/ios sin tocar lib/).
3. Copiar `.env.example` → `.env` y completar credenciales.
