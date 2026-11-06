import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';

/// Inicio de sesión, con el mismo estilo de la tarjeta "Registro de Usuario" de la web.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_usuario.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _configurarServidor() async {
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dirección del backend Spring Boot. En el celular usa la IP de tu PC '
              '(misma WiFi), por ejemplo http://192.168.1.50:8080',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.dns_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (guardar == true) {
      await AppConfig.guardar(ctrl.text);
      if (mounted) {
        setState(() {});
        mostrarMensaje(context, 'Servidor: ${AppConfig.baseUrl}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.violet],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  tooltip: 'Configurar servidor',
                  onPressed: _configurarServidor,
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        _Logo(),
                        const SizedBox(height: 14),
                        const Text('AsistControl',
                            style: TextStyle(
                                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                        const Text('Sistema Inteligente de Gestión Educativa',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 28),
                        _tarjeta(context),
                        const SizedBox(height: 18),
                        Text('Servidor: ${AppConfig.baseUrl}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(BuildContext context) {
    return Card(
      elevation: 12,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Iniciar Sesión',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Ingresa con tu usuario o correo',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 20),
              const _Etiqueta('Usuario o correo'),
              TextFormField(
                controller: _usuario,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  hintText: 'Ingresa tu usuario',
                  suffixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
              ),
              const SizedBox(height: 14),
              const _Etiqueta('Contraseña'),
              TextFormField(
                controller: _password,
                obscureText: _ocultar,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  hintText: 'Tu contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox(height: 20)
                    : Container(
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.ausente.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.ausente),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(color: AppColors.ausente))),
                          ],
                        ),
                      ),
              ),
              GradientButton(
                texto: 'Ingresar',
                icono: Icons.login_rounded,
                cargando: _cargando,
                onPressed: _entrar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white38),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: const Text('AC',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20)),
        ),
      );
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
