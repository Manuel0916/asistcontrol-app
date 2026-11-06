import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

/// Botón principal con el degradado azul → violeta de la web.
class GradientButton extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;
  final Gradient gradient;

  const GradientButton({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.cargando = false,
    this.gradient = AppColors.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: activo ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: activo ? onPressed : null,
            child: SizedBox(
              height: 52,
              child: Center(
                child: cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icono != null) ...[
                            Icon(icono, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            texto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con título e ícono, como las secciones de la web.
class SectionCard extends StatelessWidget {
  final String? titulo;
  final IconData? icono;
  final Widget child;
  final Widget? accion;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.titulo,
    this.icono,
    required this.child,
    this.accion,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icono != null) ...[
                    IconBadge(icono!),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(titulo!,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (accion != null) accion!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Ícono dentro de un cuadrito suave (como "Control de Acceso por Rol").
class IconBadge extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double size;
  const IconBadge(this.icono, {super.key, this.color = AppColors.primary, this.size = 36});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icono, color: color, size: size * 0.55),
      );
}

/// Etiqueta de color para Presente / Tarde / Ausente.
class EstadoChip extends StatelessWidget {
  final Estado estado;
  const EstadoChip(this.estado, {super.key});

  static Color color(Estado e) => switch (e) {
        Estado.presente => AppColors.presente,
        Estado.tarde => AppColors.tarde,
        Estado.ausente => AppColors.ausente,
      };

  @override
  Widget build(BuildContext context) {
    final c = color(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(estado.texto,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Número grande con etiqueta (1629 Presentes, 85% Puntualidad...).
class StatTile extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final Color color;
  final IconData? icono;

  const StatTile({
    super.key,
    required this.valor,
    required this.etiqueta,
    this.color = AppColors.primary,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, color: color, size: 22),
              const SizedBox(height: 4),
            ],
            FittedBox(
              child: Text(valor,
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(etiqueta,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// Mensaje cuando no hay datos.
class EmptyState extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  const EmptyState({super.key, required this.icono, required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            Icon(icono, size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(subtitulo!,
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
          ],
        ),
      );
}

/// Error con botón de reintentar.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.ausente),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}

/// Carga datos de forma asíncrona y muestra cargando / error / contenido,
/// con "jalar para actualizar" incluido.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T data, Future<void> Function() recargar) builder;

  const AsyncView({super.key, required this.cargar, required this.builder});

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cargar();
  }

  Future<void> _recargar() async {
    final f = widget.cargar();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _recargar);
        return RefreshIndicator(
          onRefresh: _recargar,
          child: widget.builder(context, snap.data as T, _recargar),
        );
      },
    );
  }
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ]),
      backgroundColor: error ? AppColors.ausente : AppColors.presente,
    ));
}
