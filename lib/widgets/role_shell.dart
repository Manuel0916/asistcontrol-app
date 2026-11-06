import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/auth_provider.dart';

/// Una pestaña de la barra inferior.
class SeccionRol {
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
  const SeccionRol(this.titulo, this.icono, this.iconoActivo, this.pantalla);
}

/// Estructura común de los tres roles: encabezado con el usuario arriba
/// y barra de navegación inferior (reemplaza la barra lateral de la web).
class RoleShell extends StatefulWidget {
  final List<SeccionRol> secciones;
  const RoleShell({super.key, required this.secciones});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final seccion = widget.secciones[_indice];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Text('AC',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seccion.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                  const Text('AsistControl',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: const [_AvatarMenu(), SizedBox(width: 12)],
      ),
      // IndexedStack mantiene el estado de cada pestaña al cambiar entre ellas
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _indice,
          children: widget.secciones.map((s) => s.pantalla).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          for (final s in widget.secciones)
            NavigationDestination(
              icon: Icon(s.icono),
              selectedIcon: Icon(s.iconoActivo, color: AppColors.primary),
              label: s.titulo,
            ),
        ],
      ),
    );
  }
}

/// Avatar del usuario: al tocarlo muestra el perfil y "Cerrar sesión".
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu();

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;
    final inicial = (usuario?.username.isNotEmpty ?? false) ? usuario!.username[0].toUpperCase() : '?';

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.violet,
                  child: Text(inicial,
                      style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                Text(usuario?.username ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(usuario?.email ?? '', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Chip(
                  label: Text(usuario?.rolLegible.toUpperCase() ?? ''),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ausente,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      context.read<AuthProvider>().logout();
                    },
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.violet,
        child: Text(inicial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
