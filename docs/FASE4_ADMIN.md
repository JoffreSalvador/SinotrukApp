# Fase 4 — UI del Administrador

## Módulos entregados

| Archivo | Responsabilidad |
|---|---|
| `lib/core/utils/reports_calculator.dart` | Motor puro de los 5 reportes (colecciones Dart, testeable sin UI ni red) |
| `lib/services/admin_user_service.dart` | Llama a las Edge Functions `create-user`, `reset-password`, `delete-user` |
| `lib/repositories/admin_repository.dart` | Perfiles, vehículos, asignaciones y gastos de vehículo (local-first) |
| `lib/repositories/manager_account_repository.dart` | Cuenta con el gerente: por pagar/cobrar (auto+manual), pagos, ajuste |
| `lib/views/admin/admin_home.dart` | Shell con 5 secciones: Reportes, Usuarios, Flota, Gastos V., Gerente |

## Pantallas del administrador

### Usuarios
- Crear usuarios (conductor o admin) vía Edge Function con usuario/contraseña definidos.
- Cambiar contraseña, habilitar/deshabilitar (RLS directa), eliminar usuario.

### Flota
- Añadir vehículos (placa, marca, modelo) y ver conductores.
- Asignar vehículo ↔ conductor (cierra automáticamente la asignación previa de cualquiera de los dos).

### Gastos de vehículos
- Registrar gastos (fecha, concepto, valor).
- Reporte filtrable **por año** (vigente por defecto) o **desde-hasta**, con total del periodo.

### Cuenta con el gerente
- Los valores automáticos (10% por viaje y filas Empresa) llegan desde los triggers de Supabase (`source='auto'`) al hacer pull.
- El admin añade valores manuales por pagar/cobrar y pagos recibidos/realizados.
- Ajuste final: `porCobrar − porPagar + realizados − recibidos`.

### Reportes (filtro año-default / desde-hasta)
1. **Viajes**: fecha, conductor, rutas, ingreso, egreso; expansible para ver detalle.
2. **Conductor**: selector de conductor; filas fecha/ruta/valor/pagado + total pagado al conductor.
3. **Rutas**: promedios de gasolina, ingreso y egreso por ruta + neto ganancia/pérdida.
4. **Empresa**: fecha, ruta individual, conductor, valor + suma total Empresa.
5. **Ing/Egr**: ingresos por pasajeros y encomiendas; egresos de viaje y de vehículos.

## Tests nuevos

- `test/core/reports_calculator_test.dart`: los 5 reportes (agrupaciones, promedios,
  totales, manejo de viajes sin datos y conductores desconocidos).
- Ejecutar: `flutter test` (suite completa: **42 pruebas en verde**).

## Pendientes de despliegue para uso real

1. Ejecutar el SQL actualizado (incluye `app_needs_bootstrap()` y triggers del gerente).
2. Desplegar las Edge Functions (ver `docs/FASE1_DESPLIEGUE.md`).
3. Copiar `.env.example` → `.env` con credenciales reales.
4. Correr los E2E en emulador: `flutter test integration_test/driver_flow_test.dart`.
