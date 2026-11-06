import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Historial de asistencias del estudiante, agrupado por mes y filtrable por clase.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  String? _filtroClase; // null = todas

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Asistencia>>(
      cargar: AsistenciaService.mias,
      builder: (context, todas, _) {
        if (todas.isEmpty) {
          return ListView(children: const [
            EmptyState(
              icono: Icons.event_busy_outlined,
              titulo: 'Aún no tienes asistencias',
              subtitulo: 'Escanea el QR de tu clase para registrar la primera.',
            ),
          ]);
        }

        final clases = {for (final a in todas) Clases.clave(a.clase): a.clase};
        final lista = _filtroClase == null
            ? todas
            : todas.where((a) => Clases.clave(a.clase) == _filtroClase).toList();

        // Agrupar por mes: "mayo 2026" -> registros
        final grupos = <String, List<Asistencia>>{};
        for (final a in lista) {
          final mes = DateFormat('MMMM yyyy').format(a.fechaHora);
          grupos.putIfAbsent(mes, () => []).add(a);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Todas (${todas.length})', _filtroClase == null, () => setState(() => _filtroClase = null)),
                  for (final e in clases.entries)
                    _chip(Clases.nombre(e.value), _filtroClase == e.key,
                        () => setState(() => _filtroClase = e.key)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final g in grupos.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: Text(
                  '${g.key[0].toUpperCase()}${g.key.substring(1)}  ·  ${g.value.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ),
              for (final a in g.value) _TarjetaAsistencia(a),
            ],
          ],
        );
      },
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: activo,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: activo ? Colors.white : null,
            fontWeight: FontWeight.w600,
          ),
          showCheckmark: false,
        ),
      );
}

class _TarjetaAsistencia extends StatelessWidget {
  final Asistencia a;
  const _TarjetaAsistencia(this.a);

  @override
  Widget build(BuildContext context) {
    final color = EstadoChip.color(a.estado);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('dd').format(a.fechaHora),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
                Text(DateFormat('EEE').format(a.fechaHora),
                    style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          title: Text(a.claseLegible, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(DateFormat('d MMM yyyy · h:mm a').format(a.fechaHora)),
          trailing: EstadoChip(a.estado),
        ),
      ),
    );
  }
}
