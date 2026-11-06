import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Registro Manual de Asistencia (para quien no pudo escanear, llegó tarde, etc.).
class RegistroManualScreen extends StatelessWidget {
  final VoidCallback onGuardado;
  const RegistroManualScreen({super.key, required this.onGuardado});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Asistencia>>(
      cargar: AsistenciaService.todas,
      builder: (context, lista, _) {
        int n(Estado e) => lista.where((a) => a.estado == e).length;
        // Nombres ya conocidos, para autocompletar
        final nombres = {for (final a in lista) a.nombre}.toList()..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                StatTile(valor: '${n(Estado.presente)}', etiqueta: 'Presentes', color: AppColors.presente),
                StatTile(valor: '${n(Estado.tarde)}', etiqueta: 'Tardes', color: AppColors.tarde),
                StatTile(valor: '${n(Estado.ausente)}', etiqueta: 'Ausentes', color: AppColors.ausente),
                StatTile(valor: '${lista.length}', etiqueta: 'Total'),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Registrar Nueva Asistencia',
              icono: Icons.edit_note,
              child: _Formulario(nombres: nombres, onGuardado: onGuardado),
            ),
          ],
        );
      },
    );
  }
}

class _Formulario extends StatefulWidget {
  final List<String> nombres;
  final VoidCallback onGuardado;
  const _Formulario({required this.nombres, required this.onGuardado});

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _form = GlobalKey<FormState>();
  String _nombre = '';
  String? _clase;
  Estado _estado = Estado.presente;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fecha));
    setState(() => _fecha = DateTime(d.year, d.month, d.day, h?.hour ?? _fecha.hour, h?.minute ?? _fecha.minute));
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await AsistenciaService.registrarManual(
        nombre: _nombre.trim(),
        clase: _clase!,
        estado: _estado.texto,
        fecha: _fecha,
      );
      if (!mounted) return;
      mostrarMensaje(context, 'Asistencia de ${_nombre.trim()} registrada');
      widget.onGuardado(); // recarga contadores y lista
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Nombre del Alumno'),
          Autocomplete<String>(
            optionsBuilder: (v) => v.text.isEmpty
                ? const Iterable<String>.empty()
                : widget.nombres.where((n) => n.toLowerCase().contains(v.text.toLowerCase())).take(6),
            onSelected: (v) => _nombre = v,
            fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextFormField(
              controller: ctrl,
              focusNode: focus,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (v) => _nombre = v,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
            ),
          ),
          const SizedBox(height: 14),
          const _Label('Clase'),
          DropdownButtonFormField<String>(
            initialValue: _clase,
            hint: const Text('Seleccionar clase'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.class_outlined)),
            items: [
              for (final c in Clases.valores) DropdownMenuItem(value: c, child: Text(Clases.nombre(c))),
            ],
            onChanged: (v) => setState(() => _clase = v),
            validator: (v) => v == null ? 'Selecciona la clase' : null,
          ),
          const SizedBox(height: 14),
          const _Label('Estado'),
          SegmentedButton<Estado>(
            segments: [
              for (final e in Estado.values)
                ButtonSegment(
                  value: e,
                  label: Text(e.texto),
                  icon: Icon(switch (e) {
                    Estado.presente => Icons.check_circle_outline,
                    Estado.tarde => Icons.schedule,
                    Estado.ausente => Icons.cancel_outlined,
                  }),
                ),
            ],
            selected: {_estado},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? EstadoChip.color(_estado).withValues(alpha: 0.15) : null),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? EstadoChip.color(_estado) : null),
            ),
            onSelectionChanged: (s) => setState(() => _estado = s.first),
          ),
          const SizedBox(height: 14),
          const _Label('Fecha y hora'),
          InkWell(
            onTap: _elegirFecha,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.event_outlined)),
              child: Text(DateFormat("d 'de' MMMM yyyy · h:mm a").format(_fecha)),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            texto: 'Registrar Asistencia',
            icono: Icons.check_circle_outline,
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String t;
  const _Label(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
