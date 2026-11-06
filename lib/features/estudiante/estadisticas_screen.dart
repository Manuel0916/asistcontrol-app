import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Estadísticas personales del estudiante.
/// (En la web esta sección estaba casi vacía; aquí se calcula todo con su historial.)
class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  /// Mismo umbral del módulo de riesgo: con 25% de inasistencia se pierde la materia.
  static const umbralPerdida = 25.0;
  static const umbralAlerta = 18.0;

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Asistencia>>(
      cargar: AsistenciaService.mias,
      builder: (context, lista, _) {
        if (lista.isEmpty) {
          return ListView(children: const [
            EmptyState(
              icono: Icons.insights_outlined,
              titulo: 'Sin datos todavía',
              subtitulo: 'Tus estadísticas aparecerán cuando registres asistencias.',
            ),
          ]);
        }

        final p = lista.where((a) => a.estado == Estado.presente).length;
        final t = lista.where((a) => a.estado == Estado.tarde).length;
        final au = lista.where((a) => a.estado == Estado.ausente).length;
        final total = lista.length;
        final asistencia = (p + t) / total * 100;
        final puntualidad = (p + t) == 0 ? 0.0 : p / (p + t) * 100;
        final racha = _racha(lista);

        // Por clase
        final porClase = <String, List<Asistencia>>{};
        for (final a in lista) {
          porClase.putIfAbsent(Clases.clave(a.clase), () => []).add(a);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Hero(asistencia: asistencia, racha: racha),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: StatTile(valor: '$total', etiqueta: 'Asistencias totales')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      valor: '${puntualidad.round()}%',
                      etiqueta: 'Puntualidad',
                      color: AppColors.presente)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      valor: '${porClase.length}', etiqueta: 'Clases', color: AppColors.violet)),
            ]),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Resumen de Asistencia',
              icono: Icons.donut_large,
              child: Row(
                children: [
                  DonaEstados(presentes: p, tardes: t, ausentes: au, size: 150),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LeyendaItem(AppColors.presente, 'Presente', valor: '$p'),
                        LeyendaItem(AppColors.tarde, 'Tarde', valor: '$t'),
                        LeyendaItem(AppColors.ausente, 'Ausente', valor: '$au'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Semáforo por materia',
              icono: Icons.traffic_outlined,
              child: Column(
                children: [
                  for (final e in porClase.entries) _FilaMateria(e.value),
                  const SizedBox(height: 4),
                  const Text(
                    'Con 25% o más de inasistencia se pierde la materia. Desde 18% es aviso temprano.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Asistencias por mes',
              icono: Icons.bar_chart_rounded,
              child: BarrasSimples(datos: _porMes(lista), alto: 200),
            ),
          ],
        );
      },
    );
  }

  /// Registros seguidos (del más reciente hacia atrás) sin ausencias.
  static int _racha(List<Asistencia> lista) {
    final ordenada = [...lista]..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    var n = 0;
    for (final a in ordenada) {
      if (a.estado == Estado.ausente) break;
      n++;
    }
    return n;
  }

  /// Últimos 6 meses con registros.
  static List<({String etiqueta, double valor, Color color})> _porMes(List<Asistencia> lista) {
    final conteo = <DateTime, int>{};
    for (final a in lista) {
      if (a.estado == Estado.ausente) continue;
      final m = DateTime(a.fechaHora.year, a.fechaHora.month);
      conteo[m] = (conteo[m] ?? 0) + 1;
    }
    final meses = conteo.keys.toList()..sort();
    final ultimos = meses.length > 6 ? meses.sublist(meses.length - 6) : meses;
    return [
      for (final m in ultimos)
        (etiqueta: DateFormat('MMM').format(m), valor: conteo[m]!.toDouble(), color: AppColors.primary),
    ];
  }
}

class _Hero extends StatelessWidget {
  final double asistencia;
  final int racha;
  const _Hero({required this.asistencia, required this.racha});

  String get _mensaje {
    if (asistencia >= 90) return '¡Excelente! Sigue así 🎉';
    if (asistencia >= 75) return 'Vas bien, no bajes la guardia 💪';
    return 'Ojo: tu asistencia está baja ⚠️';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: asistencia / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text('${(v * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Asistencia general',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_mensaje,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🔥 Racha: $racha sin faltar',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaMateria extends StatelessWidget {
  final List<Asistencia> registros;
  const _FilaMateria(this.registros);

  @override
  Widget build(BuildContext context) {
    final ausencias = registros.where((a) => a.estado == Estado.ausente).length;
    final pct = ausencias / registros.length * 100;
    final (color, texto) = pct >= EstadisticasScreen.umbralPerdida
        ? (AppColors.ausente, 'En riesgo de perder')
        : pct >= EstadisticasScreen.umbralAlerta
            ? (AppColors.tarde, 'Aviso temprano')
            : (AppColors.presente, 'Vas bien');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Clases.nombre(registros.first.clase),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 4),
          Text('${pct.toStringAsFixed(1)}% de inasistencia · $ausencias de ${registros.length} clases',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
