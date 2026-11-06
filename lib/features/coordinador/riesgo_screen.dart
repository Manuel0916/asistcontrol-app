import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Riesgo de inasistencia: las mismas 4 gráficas de la web, adaptadas al celular.
class RiesgoScreen extends StatefulWidget {
  const RiesgoScreen({super.key});

  @override
  State<RiesgoScreen> createState() => _RiesgoScreenState();
}

class _RiesgoScreenState extends State<RiesgoScreen> {
  String? _clase; // null = Todas
  DateTime _fecha = DateTime.now();
  int _version = 0;
  bool _reentrenando = false;

  Future<_DatosRiesgo> _cargar() async {
    final r = await Future.wait([
      RiesgoService.resumen(),
      RiesgoService.alumnos(clase: _clase),
      RiesgoService.clases(),
      RiesgoService.tendencia(),
      RiesgoService.mapaCalor(),
      RiesgoService.prediccion(fecha: _fecha, clase: _clase),
    ]);
    return _DatosRiesgo(
      resumen: r[0] as ResumenRiesgo,
      alumnos: r[1] as List<AlumnoRiesgo>,
      clases: r[2] as List<String>,
      tendencia: r[3] as Tendencia,
      mapa: r[4] as MapaCalor,
      prediccion: r[5] as List<PrediccionFalta>,
    );
  }

  Future<void> _reentrenar() async {
    setState(() => _reentrenando = true);
    try {
      await RiesgoService.reentrenar();
      if (mounted) mostrarMensaje(context, 'Modelo reentrenado con los datos actuales');
      setState(() => _version++);
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _reentrenando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_DatosRiesgo>(
      key: ValueKey('$_clase-${_fecha.toIso8601String()}-$_version'),
      cargar: _cargar,
      builder: (context, d, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${d.resumen.total} combinaciones alumno–materia · umbral ${d.resumen.umbralPerdida.round()}% · '
            'aviso desde ${d.resumen.umbralAlerta.round()}%',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: StatTile(
                    valor: '${d.resumen.rojo}',
                    etiqueta: 'Pierden (≥ 25%)',
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
          _filtros(d.clases),
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Alumnos con mayor inasistencia',
            icono: Icons.bar_chart_rounded,
            child: _barrasAlumnos(d),
          ),
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Tendencia mensual de ausencias',
            icono: Icons.show_chart,
            child: _Tendencia(d.tendencia),
          ),
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Mapa de calor: materia × día',
            icono: Icons.grid_on_outlined,
            child: _MapaCalor(d.mapa),
          ),
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Inasistencia actual vs. probabilidad de faltar',
            icono: Icons.scatter_plot_outlined,
            child: _Dispersion(alumnos: d.alumnos, prediccion: d.prediccion),
          ),
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Detalle por alumno',
            icono: Icons.people_outline,
            child: _Detalle(d.alumnos),
          ),
        ],
      ),
    );
  }

  Widget _filtros(List<String> clases) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _clase,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Materia'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    for (final c in clases) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _clase = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (f != null) setState(() => _fecha = f);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha a predecir'),
                    child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _reentrenando ? null : _reentrenar,
              icon: _reentrenando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.model_training),
              label: const Text('Reentrenar modelo'),
            ),
          ],
        ),
      );

  Widget _barrasAlumnos(_DatosRiesgo d) {
    final top = [...d.alumnos]..sort((a, b) => b.porcentaje.compareTo(a.porcentaje));
    final datos = [
      for (final a in top.take(12))
        (
          etiqueta: a.alumno.split(' ').first,
          valor: a.porcentaje,
          color: _colorNivel(a.nivel),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('% de clases con ausencia. La línea marca el umbral para perder la materia.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        const Wrap(spacing: 14, children: [
          LeyendaItem(AppColors.ausente, 'Pierde'),
          LeyendaItem(AppColors.tarde, 'En riesgo'),
          LeyendaItem(AppColors.presente, 'Sin riesgo'),
        ]),
        const SizedBox(height: 12),
        BarrasSimples(
          datos: datos,
          lineaUmbral: d.resumen.umbralPerdida,
          sufijo: '%',
          etiquetasRotadas: true,
          alto: 260,
        ),
      ],
    );
  }
}

Color _colorNivel(NivelRiesgo n) => switch (n) {
      NivelRiesgo.rojo => AppColors.ausente,
      NivelRiesgo.amarillo => AppColors.tarde,
      NivelRiesgo.verde => AppColors.presente,
    };

class _DatosRiesgo {
  final ResumenRiesgo resumen;
  final List<AlumnoRiesgo> alumnos;
  final List<String> clases;
  final Tendencia tendencia;
  final MapaCalor mapa;
  final List<PrediccionFalta> prediccion;
  _DatosRiesgo({
    required this.resumen,
    required this.alumnos,
    required this.clases,
    required this.tendencia,
    required this.mapa,
    required this.prediccion,
  });
}

class _Tendencia extends StatelessWidget {
  final Tendencia t;
  const _Tendencia(this.t);

  @override
  Widget build(BuildContext context) {
    if (t.meses.isEmpty) return const Text('Sin datos');
    final grid = Theme.of(context).brightness == Brightness.dark ? Colors.white10 : AppColors.border;
    final paso = math.max(1, (t.meses.length / 6).ceil()); // no amontonar etiquetas

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (t.porcentaje.fold<double>(0, math.max) * 1.2).clamp(10, 100),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, m) => SideTitleWidget(
                  meta: m,
                  child: Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= t.meses.length || i % paso != 0) return const SizedBox.shrink();
                  final f = DateTime.tryParse('${t.meses[i]}-01');
                  return SideTitleWidget(
                    meta: m,
                    child: Text(f == null ? t.meses[i] : DateFormat('MMM yy').format(f),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('${t.meses[s.x.toInt()]}\n${s.y.toStringAsFixed(1)}%',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < t.porcentaje.length; i++) FlSpot(i.toDouble(), t.porcentaje[i])],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.primary.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaCalor extends StatelessWidget {
  final MapaCalor m;
  const _MapaCalor(this.m);

  @override
  Widget build(BuildContext context) {
    final valores = m.valores.expand((f) => f).whereType<double>();
    final maximo = valores.isEmpty ? 1.0 : valores.reduce(math.max);
    final minimo = valores.isEmpty ? 0.0 : valores.reduce(math.min);

    Widget celda(double? v) {
      final t = v == null || maximo == minimo ? 0.0 : (v - minimo) / (maximo - minimo);
      final fondo = v == null
          ? Colors.transparent
          : Color.lerp(const Color(0xFFDCE7FF), const Color(0xFF0B3A8C), t)!;
      return Container(
        width: 58,
        height: 40,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
        child: Text(v == null ? '–' : '${v.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: v == null ? AppColors.muted : (t > 0.45 ? Colors.white : AppColors.text))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('% de ausencia. Más oscuro = más ausencias. Desliza → para ver todos los días.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const SizedBox(width: 104),
                for (final d in m.dias)
                  SizedBox(
                    width: 62,
                    child: Text(d.length > 3 ? d.substring(0, 3) : d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ]),
              for (var i = 0; i < m.clases.length; i++)
                Row(children: [
                  SizedBox(
                    width: 104,
                    child: Text(m.clases[i],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  for (var j = 0; j < m.dias.length; j++)
                    celda(j < m.valores[i].length ? m.valores[i][j] : null),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Rango: ${minimo.toStringAsFixed(1)}% – ${maximo.toStringAsFixed(1)}%',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _Dispersion extends StatelessWidget {
  final List<AlumnoRiesgo> alumnos;
  final List<PrediccionFalta> prediccion;
  const _Dispersion({required this.alumnos, required this.prediccion});

  @override
  Widget build(BuildContext context) {
    // Une cada alumno-materia con su probabilidad de faltar
    final prob = {
      for (final p in prediccion) '${p.alumno}|${Clases.clave(p.clase)}': p.probabilidad,
    };
    final puntos = <({AlumnoRiesgo a, double y})>[];
    for (final a in alumnos) {
      final y = prob['${a.alumno}|${Clases.clave(a.clase)}'];
      if (y != null) puntos.add((a: a, y: y <= 1 ? y * 100 : y));
    }
    if (puntos.isEmpty) {
      return const Text('No hay predicciones para la fecha seleccionada.',
          style: TextStyle(color: AppColors.muted));
    }

    final maxX = (puntos.map((p) => p.a.porcentaje).reduce(math.max) * 1.15).clamp(10.0, 100.0);
    final maxY = (puntos.map((p) => p.y).reduce(math.max) * 1.15).clamp(10.0, 100.0);
    final grid = Theme.of(context).brightness == Brightness.dark ? Colors.white10 : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cada punto es un alumno en una materia. Arriba a la derecha: los casos más urgentes.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ScatterChart(
            ScatterChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
                getDrawingVerticalLine: (_) => FlLine(color: grid, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('Prob. de falta (%)', style: TextStyle(fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => SideTitleWidget(
                      meta: m,
                      child: Text(v.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('% inasistencia actual', style: TextStyle(fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, m) => SideTitleWidget(
                      meta: m,
                      child: Text(v.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ),
                  ),
                ),
              ),
              scatterTouchData: ScatterTouchData(
                touchTooltipData: ScatterTouchTooltipData(
                  getTooltipItems: (s) {
                    final p = puntos.firstWhere((p) => p.a.porcentaje == s.x && p.y == s.y);
                    return ScatterTooltipItem(
                      '${p.a.alumno}\n${p.a.clase}\n${s.x.toStringAsFixed(1)}% · ${s.y.toStringAsFixed(1)}%',
                      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              scatterSpots: [
                for (final p in puntos)
                  ScatterSpot(
                    p.a.porcentaje,
                    p.y,
                    dotPainter: FlDotCirclePainter(radius: 5, color: _colorNivel(p.a.nivel)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Detalle extends StatefulWidget {
  final List<AlumnoRiesgo> alumnos;
  const _Detalle(this.alumnos);

  @override
  State<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends State<_Detalle> {
  bool _todos = false;

  @override
  Widget build(BuildContext context) {
    final orden = [...widget.alumnos]..sort((a, b) => b.porcentaje.compareTo(a.porcentaje));
    final visibles = _todos ? orden : orden.take(8).toList();
    return Column(
      children: [
        for (final a in visibles)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            leading: CircleAvatar(radius: 6, backgroundColor: _colorNivel(a.nivel)),
            title: Text(a.alumno, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(a.clase),
            trailing: Text('${a.porcentaje.toStringAsFixed(1)}%',
                style: TextStyle(color: _colorNivel(a.nivel), fontWeight: FontWeight.w800)),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _dato('Clases', '${a.clasesRegistradas}'),
                    _dato('Ausencias', '${a.ausencias}'),
                    _dato('Tardanzas', '${a.tardanzas}'),
                    _dato('Proyectado', '${a.proyectado.toStringAsFixed(1)}%'),
                    _dato('Faltas que le quedan', '${a.faltasRestantes}'),
                  ],
                ),
              ),
            ],
          ),
        if (orden.length > 8)
          TextButton(
            onPressed: () => setState(() => _todos = !_todos),
            child: Text(_todos ? 'Ver menos' : 'Ver los ${orden.length}'),
          ),
      ],
    );
  }

  Widget _dato(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k: ', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ])),
      );
}
