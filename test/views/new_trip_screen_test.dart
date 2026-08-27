import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sinotruk_app/providers/app_providers.dart';
import 'package:sinotruk_app/services/auth_service.dart';
import 'package:sinotruk_app/views/driver/new_trip_screen.dart';

class MockAuthService extends Mock implements SupabaseAuthService {}

void main() {
  late MockAuthService authService;

  Future<void> pumpScreen(WidgetTester tester) async {
    // Superficie grande para que todo el formulario esté renderizado.
    tester.binding.window.physicalSizeTestValue = const Size(1200, 6000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
        ],
        child: const MaterialApp(home: NewTripScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    authService = MockAuthService();
    registerFallbackValue(StackTrace.current);
    when(() => authService.needsBootstrap()).thenAnswer((_) async => false);
  });

  group('Renderizado condicional de pasajeros (formulario dinámico)', () {
    testWidgets('por defecto no hay formularios de pasajeros',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('Pasajeros (0-4)'), findsOneWidget);
      expect(find.byKey(const ValueKey('passenger_0')), findsNothing);
      expect(find.byKey(const ValueKey('passenger_1')), findsNothing);
    });

    testWidgets('al elegir 2 pasajeros se despliegan 2 formularios',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('passenger_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('passenger_1')), findsOneWidget);
      expect(find.text('Punto de salida'), findsNWidgets(2));
      expect(find.text('Punto de llegada'), findsNWidgets(2));
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('reducir a 0 pasajeros elimina los formularios',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('Punto de salida'), findsNWidgets(3));

      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('passenger_0')), findsNothing);
      expect(find.text('Punto de salida'), findsNothing);
    });

    testWidgets('máximo 4 pasajeros', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('passenger_3')), findsOneWidget);
      expect(find.text('Punto de salida'), findsNWidgets(4));
    });

    testWidgets('las encomiendas crecen con el botón agregar y tienen borrar',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Agregar encomienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar encomienda'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('package_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('package_1')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('package_1')), findsNothing);
    });

    testWidgets('secciones de gastos y observaciones presentes',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Gasolina'), findsOneWidget);
      expect(find.text('Conductor'), findsOneWidget);
      expect(find.text('Peajes'), findsOneWidget);
      expect(find.text('Otros'), findsOneWidget);
      expect(find.text('Detalle *'), findsOneWidget);
      expect(find.text('Observaciones'), findsNWidgets(2));
    });
  });
}