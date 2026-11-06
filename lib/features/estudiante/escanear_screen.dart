import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/ubicacion.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// El estudiante apunta la cámara al QR que muestra el profesor
/// y su asistencia queda registrada como "Presente".
class EscanearScreen extends StatefulWidget {
  final VoidCallback onRegistrada;
  const EscanearScreen({super.key, required this.onRegistrada});

  @override
  State<EscanearScreen> createState() => _EscanearScreenState();
}

enum _Fase { inicio, escaneando, ubicando, enviando, exito, error }

class _EscanearScreenState extends State<EscanearScreen> {
  MobileScannerController? _camara;
  _Fase _fase = _Fase.inicio;
  String _mensaje = '';
  String? _clase;

  @override
  void dispose() {
    _camara?.dispose();
    super.dispose();
  }

  void _abrirCamara() {
    _camara?.dispose();
    _camara = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    setState(() => _fase = _Fase.escaneando);
  }

  Future<void> _alDetectar(BarcodeCapture captura) async {
    if (_fase != _Fase.escaneando) return; // evita registrar dos veces
    final texto = captura.barcodes.firstOrNull?.rawValue;
    if (texto == null) return;

    final datos = _leerQr(texto);
    if (datos == null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _fase = _Fase.error;
        _mensaje = 'Este código QR no es de AsistControl.';
      });
      await _camara?.stop();
      return;
    }

    setState(() {
      _fase = datos.sesion != null ? _Fase.ubicando : _Fase.enviando;
      _clase = datos.clase;
    });
    await _camara?.stop();

    try {
      // GEOLOCALIZACIÓN: si el QR es de la app, se envía la ubicación del estudiante
      // y el servidor verifica que esté cerca del salón.
      double? lat, lng, precision;
      if (datos.sesion != null) {
        final pos = await Ubicacion.obtener();
        lat = pos.latitude;
        lng = pos.longitude;
        precision = pos.accuracy;
        if (mounted) setState(() => _fase = _Fase.enviando);
      }

      final r = await AsistenciaService.registrarPorQr(
        datos.clase,
        expira: datos.expira,
        sesion: datos.sesion,
        lat: lat,
        lng: lng,
        precision: precision,
      );
      HapticFeedback.mediumImpact();
      final distancia = r['distanciaMetros'];
      setState(() {
        _fase = _Fase.exito;
        _mensaje = 'Asistencia registrada en ${Clases.nombre(datos.clase)}'
            '${distancia != null ? '\n📍 Ubicación verificada: estás a $distancia m del salón' : ''}';
      });
      widget.onRegistrada();
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _fase = _Fase.error;
        _mensaje = e.toString();
      });
    }
  }

  /// Acepta el QR de la app móvil {clase, expira}, el de la web {clase, timestamp}
  /// o simplemente el nombre de la clase como texto.
  ({String clase, int? expira, String? sesion})? _leerQr(String texto) {
    try {
      final json = jsonDecode(texto);
      if (json is Map && json['clase'] is String && (json['clase'] as String).isNotEmpty) {
        return (
          clase: json['clase'] as String,
          expira: (json['expira'] as num?)?.toInt(),
          sesion: json['sesion'] as String?,
        );
      }
    } catch (_) {
      final limpio = texto.trim();
      if (Clases.valores.any((c) => Clases.clave(c) == Clases.clave(limpio))) {
        return (clase: limpio, expira: null, sesion: null);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          titulo: 'Escanear Código QR',
          icono: Icons.qr_code_scanner,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _contenido(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_fase == _Fase.inicio || _fase == _Fase.exito || _fase == _Fase.error)
          GradientButton(
            texto: _fase == _Fase.inicio ? 'Abrir cámara' : 'Escanear otro código',
            icono: Icons.photo_camera_outlined,
            onPressed: _abrirCamara,
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Escanea el código QR de la clase',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const SectionCard(
          titulo: 'Instrucciones',
          icono: Icons.lightbulb_outline,
          child: Row(
            children: [
              _Paso(Icons.photo_camera_outlined, 'Permitir Cámara', 'Acepta el acceso'),
              _Paso(Icons.qr_code_2, 'Enfocar QR', 'Dentro del recuadro'),
              _Paso(Icons.location_on_outlined, 'Ubicación', 'Debes estar en el salón'),
              _Paso(Icons.check_circle_outline, 'Confirmar', 'Espera el aviso'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenido() {
    switch (_fase) {
      case _Fase.inicio:
        return Container(
          key: const ValueKey('inicio'),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 90, color: AppColors.primary),
              SizedBox(height: 12),
              Text('Toca "Abrir cámara" para empezar', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        );
      case _Fase.escaneando:
      case _Fase.ubicando:
      case _Fase.enviando:
        return Stack(
          key: const ValueKey('camara'),
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camara,
              onDetect: _alDetectar,
              errorBuilder: (context, error) => Container(
                color: Colors.black,
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text(
                  'No se pudo abrir la cámara. Revisa que la app tenga permiso de cámara.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const _MarcoEscaner(),
            if (_fase == _Fase.ubicando || _fase == _Fase.enviando)
              Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_fase == _Fase.ubicando ? Icons.my_location : Icons.cloud_upload_outlined,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                        _fase == _Fase.ubicando
                            ? 'Verificando que estás en el salón...'
                            : 'Registrando en ${Clases.nombre(_clase ?? '')}...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
          ],
        );
      case _Fase.exito:
      case _Fase.error:
        final ok = _fase == _Fase.exito;
        final color = ok ? AppColors.presente : AppColors.ausente;
        return Container(
          key: ValueKey('resultado$ok'),
          color: color.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: color,
                  child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white, size: 58),
                ),
              ),
              const SizedBox(height: 18),
              Text(ok ? '¡Listo!' : 'No se pudo registrar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 6),
              Text(_mensaje, textAlign: TextAlign.center),
              if (ok) ...[
                const SizedBox(height: 4),
                Text(TimeOfDay.now().format(context), style: const TextStyle(color: AppColors.muted)),
              ],
            ],
          ),
        );
    }
  }
}

/// Recuadro con esquinas que indica dónde poner el QR.
class _MarcoEscaner extends StatelessWidget {
  const _MarcoEscaner();
  @override
  Widget build(BuildContext context) => Center(
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.7,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
}

class _Paso extends StatelessWidget {
  final IconData icono;
  final String titulo, sub;
  const _Paso(this.icono, this.titulo, this.sub);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icono, color: AppColors.primary, size: 30),
            const SizedBox(height: 6),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
}
