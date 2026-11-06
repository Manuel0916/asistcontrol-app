import 'package:flutter/material.dart';

import '../../widgets/role_shell.dart';
import 'panel_screen.dart';
import 'prediccion_screen.dart';
import 'registrar_usuario_screen.dart';
import 'riesgo_screen.dart';

/// Panel del coordinador: Panel de Control · Registrar Usuario · Predicción · Riesgo.
class CoordinadorHome extends StatelessWidget {
  const CoordinadorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(secciones: [
      SeccionRol('Panel', Icons.shield_outlined, Icons.shield, PanelScreen()),
      SeccionRol('Usuarios', Icons.person_add_alt_outlined, Icons.person_add_alt_1, RegistrarUsuarioScreen()),
      SeccionRol('Predicción', Icons.auto_graph_outlined, Icons.auto_graph, PrediccionScreen()),
      SeccionRol('Riesgo', Icons.warning_amber_outlined, Icons.warning_amber, RiesgoScreen()),
    ]);
  }
}
