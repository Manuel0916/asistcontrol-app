import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Predicción con IA: el modelo Random Forest (servicio en Python) estima la
/// probabilidad de que un alumno falte a una clase en una fecha.
/// Debajo se explica cómo decide el modelo y qué tan bien acierta.
class PrediccionScreen extends StatelessWidget {
  const PrediccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncView<({List<String> alumnos, List<String> clases})>(
      cargar: IaService.opciones,
      builder: (context, op, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Formulario(alumnos: op.alumnos, clases: op.clases),
          const SizedBox(height: 14),
          const _TarjetaModelo(),
        ],
      ),
    );
  }
}

// ======================================================================= formulario

class _Formulario extends StatefulWidget {
  final List<String> alumnos, clases;
  const _Formulario({required this.alumnos, required this.clases});

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _form = GlobalKey<FormState>();
  String? _alumno, _clase;
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  bool _cargando = false;
  PrediccionIA? _resultado;

  Future<void> _predecir() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _resultado = null;
    });
    try {
      final r = await IaService.predecir(alumno: _alumno!, clase: _clase!, fecha: _fecha);
      setState(() => _resultado = r);
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.psychology_alt_outlined, color: AppColors.violet, size: 44),
                  const SizedBox(height: 6),
                  const Text('Predicción con IA',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('¿Qué tan probable es que el alumno falte?',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 18),
                  // Autocompletar: hay muchos alumnos
                  Autocomplete<String>(
                    optionsBuilder: (v) => widget.alumnos
                        .where((a) => a.toLowerCase().contains(v.text.toLowerCase()))
                        .take(8),
                    onSelected: (v) => setState(() {
                      _alumno = v;
                      _resultado = null;
                    }),
                    fieldViewBuilder: (context, ctrl, focus, _) => TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                          labelText: 'Alumno', prefixIcon: Icon(Icons.person_search_outlined)),
                      validator: (_) => _alumno == null ? 'Elige un alumno de la lista' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _clase,
                    decoration: const InputDecoration(labelText: 'Materia', prefixIcon: Icon(Icons.class_outlined)),
                    items: [for (final c in widget.clases) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() {
                      _clase = v;
                      _resultado = null;
                    }),
                    validator: (v) => v == null ? 'Elige la materia' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final f = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (f != null) {
                        setState(() {
                          _fecha = f;
                          _resultado = null;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Fecha de la clase', prefixIcon: Icon(Icons.event_outlined)),
                      child: Text(DateFormat("EEEE d 'de' MMMM yyyy").format(_fecha)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GradientButton(
                    texto: 'Predecir',
                    icono: Icons.auto_graph,
                    cargando: _cargando,
                    onPressed: _predecir,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, child: FadeTransition(opacity: a, child: c)),
          child: _resultado == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(_resultado),
                  padding: const EdgeInsets.only(top: 14),
                  child: _Resultado(_resultado!),
                ),
        ),
      ],
    );
  }
}

Color colorNivel(String nivel) => switch (nivel) {
      'ALTA' => AppColors.ausente,
      'MEDIA' => AppColors.tarde,
      _ => AppColors.presente,
    };

class _Resultado extends StatelessWidget {
  final PrediccionIA r;
  const _Resultado(this.r);

  @override
  Widget build(BuildContext context) {
    final color = colorNivel(r.nivel);
    final (titulo, consejo) = switch (r.nivel) {
      'ALTA' => ('Riesgo ALTO de falta', 'Conviene contactar al estudiante antes de la clase.'),
      'MEDIA' => ('Riesgo MEDIO', 'Vale la pena un recordatorio.'),
      _ => ('Riesgo BAJO', 'Lo más probable es que asista.'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                // Medidor animado de la probabilidad
                SizedBox(
                  width: 110,
                  height: 110,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.probabilidad),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: v,
                            strokeWidth: 11,
                            strokeCap: StrokeCap.round,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.12),
                          ),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${(v * 100).round()}%',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                          const Text('de faltar', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${r.alumno} · ${r.clase}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${r.diaSemana} de ${r.mes}', style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text(consejo, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Lo que vio el modelo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Dato('Faltas históricas', '${(r.tasaHistorica * 100).round()}%'),
                _Dato('Faltas en la materia', '${(r.tasaEnMateria * 100).round()}%'),
                _Dato('Últimas 5 clases', '${r.faltasUltimas5} faltas'),
                _Dato('Clases registradas', '${r.clasesRegistradas}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String k, v;
  const _Dato(this.k, this.v);
  @override
  Widget build(BuildContext context) => Container(
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

// ======================================================================= el modelo

/// Explica el modelo: qué tan bien acierta y qué variables pesan más.
class _TarjetaModelo extends StatefulWidget {
  const _TarjetaModelo();

  @override
  State<_TarjetaModelo> createState() => _TarjetaModeloState();
}

class _TarjetaModeloState extends State<_TarjetaModelo> {
  late Future<ModeloIA> _futuro = IaService.modelo();
  bool _entrenando = false;

  Future<void> _reentrenar() async {
    setState(() => _entrenando = true);
    try {
      final m = await IaService.reentrenar();
      setState(() => _futuro = Future.value(m));
      if (mounted) mostrarMensaje(context, 'Modelo reentrenado con ${m.registros} asistencias');
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _entrenando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      titulo: '¿Cómo decide el modelo?',
      icono: Icons.forest_outlined,
      accion: IconButton(
        tooltip: 'Reentrenar con los datos actuales',
        onPressed: _entrenando ? null : _reentrenar,
        icon: _entrenando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.model_training),
      ),
      child: FutureBuilder<ModeloIA>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) return Text('${snap.error}', style: const TextStyle(color: AppColors.ausente));
          final m = snap.data!;
          final maxImp = m.importancia.isEmpty ? 1.0 : m.importancia.first.importancia;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.algoritmo}: 300 árboles de decisión que "votan". Aprendió de ${m.registros} '
                'asistencias de ${m.alumnos} alumnos guardadas en MongoDB.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Qué pesa más al predecir', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final i in m.importancia)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 150, child: Text(i.nombre, style: const TextStyle(fontSize: 12))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: i.importancia / maxImp,
                          minHeight: 10,
                          color: AppColors.violet,
                          backgroundColor: AppColors.violet.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 36,
                        child: Text('${(i.importancia * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  ]),
                ),
              const SizedBox(height: 10),
              Text('Qué tan bien acierta (probado con ${m.registrosPrueba} asistencias que NO vio)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Metrica('Exactitud', m.accuracy, 'aciertos totales')),
                const SizedBox(width: 8),
                Expanded(child: _Metrica('AUC', m.auc, '0.5 = azar, 1 = perfecto')),
                const SizedBox(width: 8),
                Expanded(child: _Metrica('Precisión', m.precision, 'de las alertas, faltaron')),
              ]),
              const SizedBox(height: 12),
              _MatrizConfusion(m),
              if (m.advertencia != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tarde.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, color: AppColors.tarde, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.advertencia!, style: const TextStyle(fontSize: 12))),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              Text('Entrenado: ${m.entrenadoEn.replaceFirst('T', ' ')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String titulo, ayuda;
  final double valor;
  const _Metrica(this.titulo, this.valor, this.ayuda);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(titulo == 'AUC' ? valor.toStringAsFixed(2) : '${(valor * 100).round()}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(ayuda, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      );
}

/// Tabla 2x2: lo que pasó de verdad vs. lo que dijo el modelo.
class _MatrizConfusion extends StatelessWidget {
  final ModeloIA m;
  const _MatrizConfusion(this.m);

  @override
  Widget build(BuildContext context) {
    Widget celda(int n, String texto, bool acierto) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (acierto ? AppColors.presente : AppColors.ausente).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('$n', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            ]),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Matriz de confusión', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Row(children: [
          celda(m.vn, 'Asistió y dijo\n"asiste" ✓', true),
          celda(m.fp, 'Asistió pero dijo\n"falta" ✗', false),
        ]),
        Row(children: [
          celda(m.fn, 'Faltó pero dijo\n"asiste" ✗', false),
          celda(m.vp, 'Faltó y dijo\n"falta" ✓', true),
        ]),
      ],
    );
  }
}
