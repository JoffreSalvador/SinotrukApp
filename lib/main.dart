import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/environment.dart';
import 'core/theme/app_theme.dart';
import 'views/app_root.dart';

Future<void> bootstrap() async {
  await dotenv.load(fileName: '.env');
  Environment.load(dotenv.env);

  await Supabase.initialize(
    url: Environment.supabaseUrl,
    publishableKey: Environment.supabaseAnonKey,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const ProviderScope(child: SinotrukApp()));
}

class SinotrukApp extends StatelessWidget {
  const SinotrukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinotruk Transport',
      theme: AppTheme.light,
      home: const AppRoot(),
    );
  }
}