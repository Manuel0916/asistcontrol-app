import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Error legible para mostrar al usuario.
class ApiException implements Exception {
  final String mensaje;
  final int? status;
  ApiException(this.mensaje, {this.status});
  @override
  String toString() => mensaje;
}

/// Cliente HTTP único de la app: agrega el token JWT a cada petición
/// y convierte las respuestas/errores del backend a Dart.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;

  /// Se llama cuando el backend responde 401 (token vencido): la app vuelve al login.
  void Function()? onSesionExpirada;

  /// En la nube gratis (Render) el servidor se duerme sin uso y tarda ~1 min en despertar.
  static const _timeout = Duration(seconds: 90);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado. Si estaba dormido, intenta de nuevo en unos segundos.');
    } catch (_) {
      throw ApiException(
          'No se pudo conectar con ${AppConfig.baseUrl}. ¿Está encendido el backend y en la misma red?');
    }

    final texto = utf8.decode(res.bodyBytes);
    dynamic data;
    if (texto.isNotEmpty) {
      try {
        data = jsonDecode(texto);
      } catch (_) {
        data = texto;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && token != null) {
      onSesionExpirada?.call();
      throw ApiException('Tu sesión expiró. Inicia sesión de nuevo.', status: 401);
    }
    // 403 genérico de Spring Security (trae "status"): rol sin permiso
    if (res.statusCode == 403 && (data is! Map || data.containsKey('status'))) {
      throw ApiException('No tienes permiso para esta acción.', status: 403);
    }

    // Página de error de la nube mientras el servidor despierta
    if (res.statusCode >= 502 && res.statusCode <= 504 && data is! Map) {
      throw ApiException('El servidor está despertando. Intenta de nuevo en unos segundos.',
          status: res.statusCode);
    }

    final msg = data is Map
        ? (data['error'] ?? data['mensaje'] ?? 'Error ${res.statusCode}').toString()
        : (data is String && data.length < 200 && data.isNotEmpty ? data : 'Error ${res.statusCode}');
    throw ApiException(msg, status: res.statusCode);
  }
}
