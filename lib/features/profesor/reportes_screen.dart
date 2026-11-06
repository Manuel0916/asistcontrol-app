import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Reportes y Estadísticas: resumen visual + exportar a TXT o Excel.
/// En el celular el archivo se comparte (WhatsApp, correo, Drive...) o se guarda.
class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Asistencia>>(
      cargar: AsistenciaService.todas,
      builder: (context, lista, _) {
        int n(Estado e) => lista.where((a) => a.estado == e).length;
        final p = n(Estado.presente), t = n(Estado.tarde), au = n(Estado.ausente);

        // % de asistencia (presente + tarde) por clase
        final porClase = <String, List<Asistencia>>{};
        for (final a in lista) {
          porClase.putIfAbsent(Clases.clave(a.clase), () => []).add(a);
        }
        final barras = [
          for (final e in porClase.entries)
            (
              etiqueta: Clases.nombre(e.value.first.clase).replaceAll('Matemáticas', 'Mate.'),
              valor: e.value.where((a) => a.estado != Estado.ausente).length / e.value.length * 100,
              color: AppColors.primary,
            ),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SectionCard(
              titulo: 'Resumen',
              icono: Icons.pie_chart_outline,
              child: Row(
                children: [
                  DonaEstados(presentes: p, tardes: t, ausentes: au, size: 150),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LeyendaItem(AppColors.presente, 'Presentes', valor: '$p'),
                        LeyendaItem(AppColors.tarde, 'Tardes', valor: '$t'),
                        LeyendaItem(AppColors.ausente, 'Ausentes', valor: '$au'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              titulo: '% de asistencia por clase',
              icono: Icons.bar_chart_rounded,
              child: BarrasSimples(datos: barras, maxY: 100, sufijo: '%', alto: 210),
            ),
            const SizedBox(height: 14),
            SectionCard(
              titulo: 'Exportar Reportes',
              icono: Icons.download_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: _BotonExportar(
                      icono: Icons.description_outlined,
                      color: AppColors.primary,
                      titulo: 'Reporte TXT',
                      onTap: () => _compartir(context, _txt(lista), 'reporte_asistencias.txt', 'text/plain'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BotonExportar(
                      icono: Icons.table_chart_outlined,
                      color: AppColors.presente,
                      titulo: 'Reporte Excel',
                      onTap: () => _compartir(context, _excel(lista), 'reporte_asistencias.xlsx',
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _compartir(BuildContext context, Uint8List bytes, String nombre, String mime) async {
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: nombre, mimeType: mime)],
        fileNameOverrides: [nombre],
        subject: 'Reporte de asistencias - AsistControl',
      ));
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, 'No se pudo exportar: $e', error: true);
    }
  }

  static final _f = DateFormat('dd/MM/yyyy HH:mm');

  static Uint8List _txt(List<Asistencia> lista) {
    final b = StringBuffer()
      ..writeln('REPORTE DE ASISTENCIAS - AsistControl')
      ..writeln('Generado: ${_f.format(DateTime.now())}')
      ..writeln('Total de registros: ${lista.length}')
      ..writeln('=' * 72)
      ..writeln('${'ALUMNO'.padRight(24)}${'CLASE'.padRight(18)}${'FECHA'.padRight(20)}ESTADO')
      ..writeln('-' * 72);
    for (final a in lista) {
      b.writeln('${a.nombre.padRight(24)}${a.clase.padRight(18)}${_f.format(a.fechaHora).padRight(20)}${a.estado.texto}');
    }
    return Uint8List.fromList(utf8.encode(b.toString()));
  }

  static Uint8List _excel(List<Asistencia> lista) {
    final libro = xls.Excel.createExcel();
    libro.rename('Sheet1', 'Asistencias');
    final hoja = libro['Asistencias'];
    hoja.appendRow([
      for (final h in ['ID', 'Alumno', 'Clase', 'Fecha', 'Estado']) xls.TextCellValue(h),
    ]);
    for (final a in lista) {
      hoja.appendRow([
        xls.IntCellValue(a.id),
        xls.TextCellValue(a.nombre),
        xls.TextCellValue(a.clase),
        xls.TextCellValue(_f.format(a.fechaHora)),
        xls.TextCellValue(a.estado.texto),
      ]);
    }
    return Uint8List.fromList(libro.save()!);
  }
}

class _BotonExportar extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final VoidCallback onTap;
  const _BotonExportar({required this.icono, required this.color, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            children: [
              Icon(icono, color: color, size: 38),
              const SizedBox(height: 8),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Compartir', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
