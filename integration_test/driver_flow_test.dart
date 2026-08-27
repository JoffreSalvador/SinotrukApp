// Pruebas E2E (integration_test) para los flujos criticos del chofer:
// login, renderizado condicional de pasajeros y filtro por fecha.
//
// Ejecutar con un dispositivo/emulador corriendo:
//   flutter test integration_test/driver_flow_test.dart
//
// No requieren red: los servicios remotos se reemplazan con mocks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sinotruk_app/main.dart' as app;
import 'package:sinotruk_app/models/profile.dart';
import 'package:sinotruk_app/providers/app_providers.dart';
import 'package:sinotruk_app/services/auth_service.dart';

class MockAuthService extends Mock implements SupabaseAuthService {}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late MockAuthService authService;

  const driver = Profile(
    id: 'driver-1',
    name: 'Chofer Test',
    username: 'ctest',
    role: 'driver',
  );

  Future<void> launch(WidgetTester tester) async {
    authService = MockAuthService();
    when(() => authService.needsBootstrap()).thenAnswer((_) async => false);
    when(() => authService.maybeCurrentProfile())
        .thenAnswer((_) async => driver);

    await app.bootstrap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(authService)],
        child: const app.SinotrukApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Flujo E2E del chofer', () {
    testWidgets('login con usuario y contraseña navega al home del chofer',
        (tester) async {
      // Estado inicial: sin sesion -> pantalla de login
      when(() => authService.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => driver);
      when(() => authService.currentProfile()).thenAnswer((_) async => driver);

      await launch(tester);

      expect(find.text('Sinotruk Transport'), findsOneWidget);
      expect(find.text('Usuario'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuario'), 'ctest');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'), 'secret123');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hola,'), findsOneWidget);
      verify(() => authService.login(username: 'ctest', password: 'secret123'))
          .called(1);
    });

    testWidgets('formulario de viaje despliega pasajeros dinamicamente',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await launch(tester); // ya logueado

      // Ir a la pestana "Nuevo"
      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();

      expect(find.text('Pasajeros (0-4)'), findsOneWidget);
      expect(find.text('Punto de salida'), findsNothing);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.text('Punto de salida'), findsNWidgets(2));
      expect(find.text('Tipo de pago'), findsNWidgets(2));

      // Agregar una encomienda
      await tester.tap(find.text('Agregar encomienda'));
      await tester.pumpAndSettle();
      expect(find.text('Punto de salida'), findsNWidgets(3));
    });

    testWidgets('mis viajes muestra la fecha actual por defecto',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await launch(tester);

      expect(find.textContaining('Mis viajes ·'), findsOneWidget);
      final today = DateTime.now();
      final iso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(find.textContaining(iso), findsOneWidget);
    });
  });
}
