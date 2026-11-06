import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/services.dart';

enum EstadoSesion { cargando, sinSesion, conSesion }

/// Estado global de la sesión. La app escucha este objeto (Provider)
/// y muestra el login o el panel del rol según corresponda.
class AuthProvider extends ChangeNotifier {
  // El token se guarda cifrado en el teléfono (Keystore en Android, Keychain en iOS)
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'jwt_token';
  static const _kUsuario = 'usuario';

  EstadoSesion estado = EstadoSesion.cargando;
  Usuario? usuario;

  AuthProvider() {
    ApiClient.instance.onSesionExpirada = () => logout();
  }

  /// Al abrir la app: si hay un token guardado, se valida contra el backend.
  Future<void> restaurar() async {
    try {
      final token = await _storage.read(key: _kToken);
      final guardado = await _storage.read(key: _kUsuario);
      if (token == null || guardado == null) {
        estado = EstadoSesion.sinSesion;
      } else {
        ApiClient.instance.token = token;
        usuario = Usuario.fromJson(jsonDecode(guardado));
        estado = EstadoSesion.conSesion;
        // Verifica en segundo plano; si el token venció, ApiClient llama a logout()
        AuthService.me().then((u) {
          usuario = u;
          notifyListeners();
        }).catchError((_) {});
      }
    } catch (_) {
      estado = EstadoSesion.sinSesion;
    }
    notifyListeners();
  }

  Future<void> login(String user, String password) async {
    final (token, u) = await AuthService.login(user, password);
    ApiClient.instance.token = token;
    usuario = u;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUsuario, value: jsonEncode(u.toJson()));
    estado = EstadoSesion.conSesion;
    notifyListeners();
  }

  Future<void> logout() async {
    ApiClient.instance.token = null;
    usuario = null;
    estado = EstadoSesion.sinSesion;
    await _storage.deleteAll();
    notifyListeners();
  }
}
