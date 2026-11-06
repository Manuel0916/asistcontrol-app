import 'package:flutter/material.dart';

import '../../widgets/role_shell.dart';
import 'generar_qr_screen.dart';
import 'lista_screen.dart';
import 'registro_manual_screen.dart';
import 'reportes_screen.dart';

/// Panel del profesor (rol ADMIN en el backend):
/// Registro Manual · Lista · Generar QR · Reportes.
class ProfesorHome extends StatefulWidget {
  const ProfesorHome({super.key});

  @override
  State<ProfesorHome> createState() => _ProfesorHomeState();
}

class _ProfesorHomeState extends State<ProfesorHome> {
  int _version = 0; // sube cuando cambian los datos para que las demás pestañas recarguen
  void _cambio() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    return RoleShell(secciones: [
      SeccionRol('Registro', Icons.edit_note_outlined, Icons.edit_note,
          RegistroManualScreen(key: ValueKey('r$_version'), onGuardado: _cambio)),
      SeccionRol('Lista', Icons.list_alt_outlined, Icons.list_alt,
          ListaScreen(key: ValueKey('l$_version'), onCambio: _cambio)),
      const SeccionRol('Generar QR', Icons.qr_code_2_outlined, Icons.qr_code_2, GenerarQrScreen()),
      SeccionRol('Reportes', Icons.assessment_outlined, Icons.assessment,
          ReportesScreen(key: ValueKey('p$_version'))),
    ]);
  }
}
