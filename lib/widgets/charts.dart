import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Dona de Presentes / Tardes / Ausentes con el total al centro.
class DonaEstados extends StatelessWidget {
  final int presentes, tardes, ausentes;
  final String? centroTitulo, centroSub;
  final double size;

  const DonaEstados({
    super.key,
    required this.presentes,
    required this.tardes,
    required this.ausentes,
    this.centroTitulo,
    this.centroSub,
    this.size = 170,
  });

  @override
  Widget build(BuildContext context) {
    final total = presentes + tardes + ausentes;
    PieChartSectionData sec(int v, Color c) => PieChartSectionData(
          value: v.toDouble(),
          color: c,
          radius: 22,
          showTitle: false,
        );

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: size / 2 - 26,
              startDegreeOffset: -90,
              sections: total == 0
                  ? [PieChartSectionData(value: 1, color: AppColors.border, radius: 22, showTitle: false)]
                  : [
                      if (presentes > 0) sec(presentes, AppColors.presente),
                      if (tardes > 0) sec(tardes, AppColors.tarde),
                      if (ausentes > 0) sec(ausentes, AppColors.ausente),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centroTitulo ?? '$total',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(centroSub ?? 'registros',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Puntico de color + texto + valor, para leyendas.
class LeyendaItem extends StatelessWidget {
  final Color color;
  final String texto;
  final String? valor;
  const LeyendaItem(this.color, this.texto, {super.key, this.valor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Text(texto),
            if (valor != null) ...[
              const SizedBox(width: 8),
              Text(valor!, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      );
}

/// Barras verticales simples (etiqueta, valor, color).
class BarrasSimples extends StatelessWidget {
  final List<({String etiqueta, double valor, Color color})> datos;
  final double? maxY;
  final double? lineaUmbral;
  final String sufijo;
  final double alto;
  final bool etiquetasRotadas;

  const BarrasSimples({
    super.key,
    required this.datos,
    this.maxY,
    this.lineaUmbral,
    this.sufijo = '',
    this.alto = 220,
    this.etiquetasRotadas = false,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = maxY ??
        (datos.isEmpty ? 1.0 : datos.map((d) => d.valor).reduce((a, b) => a > b ? a : b) * 1.2);
    final grid = Theme.of(context).brightness == Brightness.dark ? Colors.white10 : AppColors.border;

    return SizedBox(
      height: alto,
      child: BarChart(
        BarChartData(
          maxY: maximo <= 0 ? 1 : maximo,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          ),
          extraLinesData: lineaUmbral == null
              ? null
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: lineaUmbral!,
                    color: AppColors.ausente,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ]),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${datos[group.x].etiqueta}\n${rod.toY.toStringAsFixed(rod.toY % 1 == 0 ? 0 : 1)}$sufijo',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.toStringAsFixed(0)}$sufijo',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: etiquetasRotadas ? 70 : 30,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    angle: etiquetasRotadas ? -0.8 : 0,
                    child: Text(datos[i].etiqueta,
                        style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < datos.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: datos[i].valor,
                  color: datos[i].color,
                  width: datos.length > 8 ? 12 : 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
