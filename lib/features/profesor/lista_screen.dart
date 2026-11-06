import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Lista de Asistencias con buscador, filtros por estado y opción de eliminar.
class ListaScreen extends StatefulWidget {
  final VoidCallback onCambio;
  const ListaScreen({super.key, required this.onCambio});

  @override
  State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen> {
  Estado? _filtro; // null = Todos
  String _busqueda = '';
  final Set<int> _eliminados = {}; // se ocultan al instante, sin recargar todo

  Future<bool> _confirmarYEliminar(Asistencia a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.ausente, size: 36),
        title: const Text('¿Eliminar registro?'),
        content: Text('${a.nombre} · ${a.claseLegible}\n'
            '${DateFormat('d MMM yyyy, h:mm a').format(a.fechaHora)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ausente),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await AsistenciaService.eliminar(a.id);
      setState(() => _eliminados.add(a.id));
      if (mounted) mostrarMensaje(context, 'Registro eliminado');
      return true;
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Asistencia>>(
      cargar: AsistenciaService.todas,
      builder: (context, todas, _) {
        final q = _busqueda.toLowerCase();
        final lista = todas
            .where((a) => !_eliminados.contains(a.id))
            .where((a) => _filtro == null || a.estado == _filtro)
            .where((a) => q.isEmpty || a.nombre.toLowerCase().contains(q) || a.clase.toLowerCase().contains(q))
            .toList();

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar alumno o clase',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<Estado?>(
                        segments: const [
                          ButtonSegment(value: null, label: Text('Todos')),
                          ButtonSegment(value: Estado.presente, label: Text('Presentes')),
                          ButtonSegment(value: Estado.tarde, label: Text('Tardes')),
                          ButtonSegment(value: Estado.ausente, label: Text('Ausentes')),
                        ],
                        selected: {_filtro},
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                        ),
                        onSelectionChanged: (s) => setState(() => _filtro = s.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Text('${lista.length} registros',
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Text('Desliza ← para eliminar',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (lista.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(icono: Icons.search_off, titulo: 'No hay registros con ese filtro'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                // builder: solo dibuja las tarjetas visibles (hay miles de registros)
                sliver: SliverList.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) => _Item(
                    a: lista[i],
                    onEliminar: () => _confirmarYEliminar(lista[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  final Asistencia a;
  final Future<bool> Function() onEliminar;
  const _Item({required this.a, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(a.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onEliminar(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.ausente, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(a.nombre.isEmpty ? '?' : a.nombre[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
            title: Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${a.claseLegible} · ${DateFormat('d/M/yyyy, h:mm a').format(a.fechaHora)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EstadoChip(a.estado),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, color: AppColors.ausente),
                  onPressed: onEliminar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
