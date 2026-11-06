import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/services.dart';
import '../../widgets/common.dart';

/// Registro de Usuario (solo coordinador), con medidor de seguridad de la contraseña.
class RegistrarUsuarioScreen extends StatefulWidget {
  const RegistrarUsuarioScreen({super.key});

  @override
  State<RegistrarUsuarioScreen> createState() => _RegistrarUsuarioScreenState();
}

class _RegistrarUsuarioScreenState extends State<RegistrarUsuarioScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _rol;
  bool _ocultar = true;
  bool _guardando = false;

  static const _roles = {
    'ESTUDIANTE': ('Estudiante', Icons.school_outlined),
    'ADMIN': ('Profesor', Icons.badge_outlined),
    'COORDINADOR': ('Coordinador', Icons.admin_panel_settings_outlined),
  };

  @override
  void dispose() {
    _usuario.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 0 a 4 puntos: largo, mayúscula, número, símbolo
  int get _fuerza {
    final p = _password.text;
    var f = 0;
    if (p.length >= 8) f++;
    if (RegExp(r'[A-Z]').hasMatch(p)) f++;
    if (RegExp(r'\d').hasMatch(p)) f++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) f++;
    return f;
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final msg = await AuthService.registrar(
        username: _usuario.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        rol: _rol!,
      );
      if (!mounted) return;
      mostrarMensaje(context, '$msg: ${_usuario.text.trim()}');
      _form.currentState!.reset();
      _usuario.clear();
      _email.clear();
      _password.clear();
      setState(() => _rol = null);
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _fuerza;
    final (colorF, textoF) = switch (f) {
      0 || 1 => (AppColors.ausente, 'Débil'),
      2 => (AppColors.tarde, 'Media'),
      3 => (AppColors.primary, 'Buena'),
      _ => (AppColors.presente, 'Fuerte'),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.white, size: 36),
              SizedBox(height: 8),
              Text('Registro de Usuario',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Crea una nueva cuenta en el sistema', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _L('Usuario'),
                  TextFormField(
                    controller: _usuario,
                    decoration: const InputDecoration(
                        hintText: 'Ingresa el usuario', suffixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
                  ),
                  const SizedBox(height: 14),
                  const _L('Correo Electrónico'),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'correo@ejemplo.com', suffixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                        ? 'Correo no válido'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const _L('Contraseña'),
                  TextFormField(
                    controller: _password,
                    obscureText: _ocultar,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Crea una contraseña segura',
                      suffixIcon: IconButton(
                        icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 5,
                            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: i < f ? colorF : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _password.text.isEmpty ? 'Seguridad de la contraseña' : 'Seguridad: $textoF',
                    style: TextStyle(fontSize: 12, color: _password.text.isEmpty ? AppColors.muted : colorF),
                  ),
                  const SizedBox(height: 14),
                  const _L('Selecciona un Rol'),
                  DropdownButtonFormField<String>(
                    initialValue: _rol,
                    hint: const Text('Elige un rol...'),
                    items: [
                      for (final e in _roles.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(e.value.$2, size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(e.value.$1),
                          ]),
                        ),
                    ],
                    onChanged: (v) => setState(() => _rol = v),
                    validator: (v) => v == null ? 'Selecciona un rol' : null,
                  ),
                  const SizedBox(height: 22),
                  GradientButton(
                    texto: 'Crear Cuenta',
                    icono: Icons.person_add_alt,
                    cargando: _guardando,
                    onPressed: _crear,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _L extends StatelessWidget {
  final String t;
  const _L(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
