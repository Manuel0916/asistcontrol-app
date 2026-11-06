import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/coordinador/coordinador_home.dart';
import 'features/estudiante/estudiante_home.dart';
import 'features/profesor/profesor_home.dart';
import 'state/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');
  await AppConfig.cargar(); // dirección del servidor guardada

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..restaurar(),
      child: const AsistControlApp(),
    ),
  );
}

class AsistControlApp extends StatelessWidget {
  const AsistControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AsistControl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system, // sigue el modo claro/oscuro del teléfono
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _RaizSegunSesion(),
    );
  }
}

/// Decide qué mostrar: cargando, login o el panel del rol del usuario.
class _RaizSegunSesion extends StatelessWidget {
  const _RaizSegunSesion();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final Widget pantalla = switch (auth.estado) {
      EstadoSesion.cargando => const Scaffold(body: Center(child: CircularProgressIndicator())),
      EstadoSesion.sinSesion => const LoginScreen(),
      EstadoSesion.conSesion => switch (auth.usuario!.rol) {
          'COORDINADOR' => const CoordinadorHome(),
          'ADMIN' => const ProfesorHome(),
          _ => const EstudianteHome(),
        },
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: KeyedSubtree(key: ValueKey('${auth.estado}-${auth.usuario?.rol}'), child: pantalla),
    );
  }
}
