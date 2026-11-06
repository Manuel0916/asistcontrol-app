import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Panel de Control: habilitar/deshabilitar el acceso por rol
/// y un vistazo rápido a los alumnos en riesgo.
class PanelScreen extends StatelessWidget {
  const PanelScreen({super.key});

  static Future<_DatosPanel> _cargar() async {
    final r = await Future.wait([
      AccesoService.habilitado('estudiante'),
      AccesoService.habilitado('profesor'),
      RiesgoService.resumen(),
      RiesgoService.alumnos(),
    ]);
    return _DatosPanel(
      estudiante: r[0] as bool,
      profesor: r[1] as bool,
      resumen: r[2] as ResumenRiesgo,
      alumnos: r[3] as List<AlumnoRiesgo>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_DatosPanel>(
      cargar: _cargar,
      builder: (context, d, _) {
        final criticos = d.alumnos.where((a) => a.nivel == NivelRiesgo.rojo).toList()
          ..sort((a, b) => b.porcentaje.compareTo(a.porcentaje));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text('Gestiona el acceso y configuración del sistema',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            SectionCard(
              titulo: 'Control de Acceso por Rol',
              icono: Icons.verified_user_outlined,
              child: Column(
                children: [
                  _InterruptorRol(
                    rol: 'estudiante',
                    titulo: 'Estudiante',
                    descripcion: 'Acceso para estudiantes del sistema',
                    icono: Icons.school_outlined,
                    inicial: d.estudiante,
                  ),
                  const Divider(height: 22),
                  _InterruptorRol(
                    rol: 'profesor',
                    titulo: 'Profesor',
                    descripcion: 'Acceso para docentes del sistema',
                    icono: Icons.badge_outlined,
                    inicial: d.profesor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: StatTile(
                      valor: '${d.resumen.rojo}',
                      etiqueta: 'Pierden la materia',
                      color: AppColors.ausente,
                      icono: Icons.dangerous_outlined)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      valor: '${d.resumen.amarillo}',
                      etiqueta: 'En riesgo',
                      color: AppColors.tarde,
                      icono: Icons.warning_amber_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      valor: '${d.resumen.verde}',
                      etiqueta: 'Sin riesgo',
                      color: AppColors.presente,
                      icono: Icons.check_circle_outline)),
            ]),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Requieren atención',
              icono: Icons.notification_important_outlined,
              child: criticos.isEmpty
                  ? const Text('Ningún alumno supera el umbral. 🎉')
                  : Column(
                      children: [
                        for (final a in criticos.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x22DC2626),
                              child: Icon(Icons.person_off_outlined, color: AppColors.ausente),
                            ),
                            title: Text(a.alumno, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${Clases.nombre(a.clase)} · ${a.ausencias} faltas'),
                            trailing: Text('${a.porcentaje.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    color: AppColors.ausente, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        if (criticos.length > 5)
                          Text('y ${criticos.length - 5} más en la pestaña Riesgo',
                              style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DatosPanel {
  final bool estudiante, profesor;
  final ResumenRiesgo resumen;
  final List<AlumnoRiesgo> alumnos;
  _DatosPanel({required this.estudiante, required this.profesor, required this.resumen, required this.alumnos});
}

class _InterruptorRol extends StatefulWidget {
  final String rol, titulo, descripcion;
  final IconData icono;
  final bool inicial;
  const _InterruptorRol({
    required this.rol,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.inicial,
  });

  @override
  State<_InterruptorRol> createState() => _InterruptorRolState();
}

class _InterruptorRolState extends State<_InterruptorRol> {
  late bool _habilitado = widget.inicial;
  bool _cambiando = false;

  Future<void> _cambiar(bool _) async {
    setState(() => _cambiando = true);
    try {
      final nuevo = await AccesoService.cambiar(widget.rol);
      setState(() => _habilitado = nuevo);
      if (mounted) {
        mostrarMensaje(context, '${widget.titulo}: acceso ${nuevo ? 'habilitado' : 'deshabilitado'}');
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _habilitado ? AppColors.presente : AppColors.ausente;
    return Row(
      children: [
        IconBadge(widget.icono),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(widget.descripcion, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_habilitado ? 'Habilitado' : 'Deshabilitado',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        _cambiando
            ? const SizedBox(width: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : Switch(value: _habilitado, onChanged: _cambiar, activeTrackColor: AppColors.primary),
      ],
    );
  }
}
