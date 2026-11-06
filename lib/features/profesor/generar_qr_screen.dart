import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/ubicacion.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Genera el QR que los estudiantes escanean.
///
/// Mejora frente a la web: el QR es DINÁMICO. Cada 20 s se genera uno nuevo y
/// cada código vence a los 45 s, así una foto del QR enviada por WhatsApp
/// deja de servir enseguida. Además muestra en vivo quién va llegando.
///
/// GEOLOCALIZACIÓN: al empezar se toma la ubicación GPS del teléfono del profesor
/// (el salón) y se crea una "sesión" en el servidor. El QR solo lleva el id de la
/// sesión; el servidor rechaza a quien escanee lejos del salón.
class GenerarQrScreen extends StatefulWidget {
  const GenerarQrScreen({super.key});

  @override
  State<GenerarQrScreen> createState() => _GenerarQrScreenState();
}

class _GenerarQrScreenState extends State<GenerarQrScreen> {
  static const _renovarCada = Duration(seconds: 20);
  static const _validez = Duration(seconds: 45);

  String? _clase;
  bool _activo = false;
  String _payload = '';
  DateTime _generado = DateTime.now();
  Timer? _tick;
  Timer? _poll;
  List<Asistencia> _llegadas = [];

  // Sesión de clase en el servidor
  String? _sesionId;
  bool _preparando = false;
  bool _conUbicacion = false;
  double? _precisionSalon;
  double _radio = 100;

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (_clase == null) {
      mostrarMensaje(context, 'Selecciona una clase', error: true);
      return;
    }
    setState(() => _preparando = true);

    // 1) Ubicación del salón (sensor GPS del teléfono del profesor)
    double? lat, lng;
    _precisionSalon = null;
    try {
      final pos = await Ubicacion.obtener();
      lat = pos.latitude;
      lng = pos.longitude;
      _precisionSalon = pos.accuracy;
    } catch (e) {
      if (!mounted) return;
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.location_off_outlined, color: AppColors.tarde, size: 36),
          title: const Text('Sin ubicación'),
          content: Text('$e\n\nPuedes continuar, pero el QR no verificará que los estudiantes '
              'estén en el salón.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (seguir != true) {
        if (mounted) setState(() => _preparando = false);
        return;
      }
    }

    // 2) Crear la sesión de clase en el servidor
    try {
      final sesion = await AsistenciaService.crearSesion(_clase!, lat: lat, lng: lng);
      _sesionId = sesion['id'] as String;
      _conUbicacion = sesion['conUbicacion'] == true;
      _radio = (sesion['radioMetros'] as num?)?.toDouble() ?? 100;
    } catch (e) {
      if (mounted) {
        mostrarMensaje(context, e.toString(), error: true);
        setState(() => _preparando = false);
      }
      return;
    }
    if (!mounted) return;

    // 3) QR que se renueva solo + llegadas en vivo
    _nuevoCodigo();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().difference(_generado) >= _renovarCada) _nuevoCodigo();
      setState(() {}); // actualiza la barra de cuenta regresiva
    });
    _poll?.cancel();
    _cargarLlegadas();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _cargarLlegadas());
    setState(() {
      _activo = true;
      _preparando = false;
    });
  }

  void _detener() {
    _tick?.cancel();
    _poll?.cancel();
    setState(() => _activo = false);
  }

  void _nuevoCodigo() {
    _generado = DateTime.now();
    _payload = jsonEncode({
      'tipo': 'asistencia',
      'clase': _clase,
      'sesion': _sesionId,
      'expira': _generado.add(_validez).millisecondsSinceEpoch,
    });
  }

  /// Registros de HOY en esta clase (consulta cada 8 s)
  Future<void> _cargarLlegadas() async {
    try {
      final data = await ApiClient.instance.get('/api/asistencias/clase/${Uri.encodeComponent(_clase!)}');
      final hoy = DateTime.now();
      final lista = (data as List)
          .map((e) => Asistencia.fromJson(e))
          .where((a) =>
              a.fechaHora.year == hoy.year && a.fechaHora.month == hoy.month && a.fechaHora.day == hoy.day)
          .toList()
        ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
      if (mounted) setState(() => _llegadas = lista);
    } catch (_) {/* se reintenta en el siguiente ciclo */}
  }

  void _pantallaCompleta() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _QrPantallaCompleta(
        clase: _clase!,
        payload: () => _payload,
        progreso: () => _progreso,
      ),
    ));
  }

  double get _progreso =>
      1 - DateTime.now().difference(_generado).inMilliseconds / _renovarCada.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          titulo: 'Configuración',
          icono: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clase,
                hint: const Text('Seleccionar clase'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.class_outlined)),
                items: [
                  for (final c in Clases.valores) DropdownMenuItem(value: c, child: Text(Clases.nombre(c))),
                ],
                onChanged: _activo ? null : (v) => setState(() => _clase = v),
              ),
              const SizedBox(height: 14),
              _activo
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppColors.ausente,
                        side: const BorderSide(color: AppColors.ausente),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _detener,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Terminar toma de asistencia'),
                    )
                  : GradientButton(
                      texto: _preparando ? 'Ubicando el salón…' : 'Generar QR',
                      icono: Icons.qr_code_2,
                      cargando: _preparando,
                      onPressed: _iniciar,
                    ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          titulo: 'Código QR',
          icono: Icons.qr_code_2,
          accion: _activo
              ? IconButton(
                  tooltip: 'Pantalla completa',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _pantallaCompleta,
                )
              : null,
          child: _activo
              ? Column(
                  children: [
                    _QrCaja(payload: _payload, size: 240),
                    const SizedBox(height: 12),
                    Text(Clases.nombre(_clase!),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _ChipUbicacion(conUbicacion: _conUbicacion, precision: _precisionSalon, radio: _radio),
                    const SizedBox(height: 10),
                    _BarraRenovacion(progreso: _progreso),
                  ],
                )
              : const EmptyState(
                  icono: Icons.qr_code_2,
                  titulo: 'Selecciona una clase y genera el código',
                  subtitulo: 'El código se renueva solo cada 20 segundos.',
                ),
        ),
        if (_activo) ...[
          const SizedBox(height: 14),
          SectionCard(
            titulo: 'Llegadas de hoy',
            icono: Icons.groups_outlined,
            accion: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.presente,
              child: Text('${_llegadas.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            child: _llegadas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Esperando a que los estudiantes escaneen…',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  )
                : Column(
                    children: [
                      for (final a in _llegadas.take(30))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle, color: AppColors.presente),
                          title: Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(DateFormat('h:mm a').format(a.fechaHora),
                              style: const TextStyle(color: AppColors.muted)),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _QrCaja extends StatelessWidget {
  final String payload;
  final double size;
  const _QrCaja({required this.payload, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, // el QR siempre sobre blanco, también en modo oscuro
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: QrImageView(
            key: ValueKey(payload),
            data: payload,
            size: size,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.text),
            dataModuleStyle:
                const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.text),
          ),
        ),
      );
}

class _BarraRenovacion extends StatelessWidget {
  final double progreso;
  const _BarraRenovacion({required this.progreso});

  @override
  Widget build(BuildContext context) {
    final p = progreso.clamp(0.0, 1.0);
    final segundos = (p * 20).ceil();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 6,
            color: AppColors.primary,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 6),
        Text('Nuevo código en $segundos s',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

/// QR grande para proyectar o mostrar al salón.
class _QrPantallaCompleta extends StatefulWidget {
  final String clase;
  final String Function() payload;
  final double Function() progreso;
  const _QrPantallaCompleta({required this.clase, required this.payload, required this.progreso});

  @override
  State<_QrPantallaCompleta> createState() => _QrPantallaCompletaState();
}

class _QrPantallaCompletaState extends State<_QrPantallaCompleta> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = MediaQuery.sizeOf(context).shortestSide * 0.8;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(foregroundColor: AppColors.text),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Clases.nombre(widget.clase),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 16),
            _QrCaja(payload: widget.payload(), size: lado - 30),
            const SizedBox(height: 16),
            SizedBox(width: lado, child: _BarraRenovacion(progreso: widget.progreso())),
          ],
        ),
      ),
    );
  }
}

/// Indica si el QR está protegido por ubicación.
class _ChipUbicacion extends StatelessWidget {
  final bool conUbicacion;
  final double? precision;
  final double radio;
  const _ChipUbicacion({required this.conUbicacion, required this.precision, required this.radio});

  @override
  Widget build(BuildContext context) {
    final color = conUbicacion ? AppColors.presente : AppColors.tarde;
    final texto = conUbicacion
        ? 'Salón ubicado (±${precision?.round() ?? '?'} m) · radio ${radio.round()} m'
        : 'Sin verificación de ubicación';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(conUbicacion ? Icons.location_on : Icons.location_off_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
