import 'package:flutter/material.dart';

import '../../widgets/role_shell.dart';
import 'escanear_screen.dart';
import 'estadisticas_screen.dart';
import 'historial_screen.dart';

/// Panel del estudiante: Escanear QR · Historial · Estadísticas.
class EstudianteHome extends StatefulWidget {
  const EstudianteHome({super.key});

  @override
  State<EstudianteHome> createState() => _EstudianteHomeState();
}

class _EstudianteHomeState extends State<EstudianteHome> {
  // Cuando se registra una asistencia nueva, sube la versión y
  // el historial y las estadísticas se recargan solos.
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    return RoleShell(secciones: [
      SeccionRol('Escanear QR', Icons.qr_code_scanner_outlined, Icons.qr_code_scanner,
          EscanearScreen(onRegistrada: () => setState(() => _version++))),
      SeccionRol('Historial', Icons.history_outlined, Icons.history,
          HistorialScreen(key: ValueKey('h$_version'))),
      SeccionRol('Estadísticas', Icons.insights_outlined, Icons.insights,
          EstadisticasScreen(key: ValueKey('e$_version'))),
    ]);
  }
}
