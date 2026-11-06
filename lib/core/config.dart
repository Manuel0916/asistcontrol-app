import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dirección del backend Spring Boot.
///
/// En el celular NO sirve "localhost" (sería el propio teléfono): hay que usar la IP
/// del PC en la misma red WiFi, p. ej. http://192.168.1.50:8080. Por eso la URL se
/// puede cambiar desde la pantalla de login (ícono de engranaje) y queda guardada.
class AppConfig {
  static const _key = 'servidor_url';

  /// URL fijada al compilar para la nube:
  ///   flutter build web --dart-define=API_URL=https://asistcontrol-api.onrender.com
  static const _desdeCompilacion = String.fromEnvironment('API_URL');

  /// Valor por defecto: la URL de compilación (nube); si no hay, en Chrome localhost
  /// y en el emulador de Android el PC es 10.0.2.2.
  static String get porDefecto => _desdeCompilacion.isNotEmpty
      ? _desdeCompilacion
      : (kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080');

  static String baseUrl = porDefecto;

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_key) ?? porDefecto;
  }

  static Future<void> guardar(String url) async {
    var limpia = url.trim();
    if (!limpia.startsWith('http')) limpia = 'http://$limpia';
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    baseUrl = limpia;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, limpia);
  }
}

/// Clases que maneja el sistema (las mismas de la web).
class Clases {
  static const valores = ['matematicas-A', 'historia-B', 'quimica-C'];

  static String nombre(String clase) {
    final c = clase.toLowerCase();
    if (c.startsWith('matematicas')) return 'Matemáticas ${_grupo(clase)}';
    if (c.startsWith('historia')) return 'Historia ${_grupo(clase)}';
    if (c.startsWith('quimica')) return 'Química ${_grupo(clase)}';
    return clase;
  }

  static String _grupo(String clase) {
    final i = clase.lastIndexOf('-');
    return i >= 0 ? clase.substring(i + 1).toUpperCase() : '';
  }

  /// Agrupa variantes como "Matematicas-A" y "matematicas-A".
  static String clave(String clase) => clase.trim().toLowerCase();
}
