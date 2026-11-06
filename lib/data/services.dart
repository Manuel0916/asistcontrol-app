import 'api_client.dart';
import 'models.dart';

/// Todas las llamadas al backend, agrupadas por módulo.
/// Las pantallas nunca usan http directamente: llaman a estos servicios.
final _api = ApiClient.instance;

class AuthService {
  /// POST /api/auth/login → { token, username, email, rol, ... }
  static Future<(String token, Usuario usuario)> login(String usuario, String password) async {
    final data = await _api.post('/api/auth/login', {'usuario': usuario, 'password': password});
    return (data['token'] as String, Usuario.fromJson(data));
  }

  static Future<Usuario> me() async => Usuario.fromJson(await _api.get('/api/auth/me'));

  static Future<String> registrar({
    required String username,
    required String email,
    required String password,
    required String rol,
  }) async {
    final data = await _api.post('/api/auth/registro',
        {'username': username, 'email': email, 'password': password, 'rol': rol});
    return (data['mensaje'] ?? 'Usuario registrado').toString();
  }
}

class AsistenciaService {
  static List<Asistencia> _lista(dynamic data) => (data as List)
      .map((e) => Asistencia.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

  /// Todas (profesor / coordinador)
  static Future<List<Asistencia>> todas() async => _lista(await _api.get('/api/asistencias'));

  /// Del estudiante que inició sesión
  static Future<List<Asistencia>> mias() async =>
      _lista(await _api.get('/api/asistencias/mis-asistencias'));

  /// El estudiante escanea el QR de la clase (con su ubicación si la sesión la exige)
  static Future<Map<String, dynamic>> registrarPorQr(
    String clase, {
    int? expira,
    String? sesion,
    double? lat,
    double? lng,
    double? precision,
  }) async =>
      Map<String, dynamic>.from(await _api.post('/api/asistencias', {
        'clase': clase,
        'expira': ?expira,
        'sesion': ?sesion,
        'lat': ?lat,
        'lng': ?lng,
        'precision': ?precision,
      }));

  /// El profesor abre la toma de asistencia con la ubicación del salón.
  /// Devuelve { id, clase, conUbicacion, radioMetros }.
  static Future<Map<String, dynamic>> crearSesion(String clase, {double? lat, double? lng}) async =>
      Map<String, dynamic>.from(
          await _api.post('/api/sesiones', {'clase': clase, 'lat': ?lat, 'lng': ?lng}));

  /// El profesor registra manualmente
  static Future<void> registrarManual({
    required String nombre,
    required String clase,
    required String estado,
    required DateTime fecha,
  }) =>
      _api.post('/api/asistencias/manual', {
        'nombre': nombre,
        'clase': clase,
        'estado': estado,
        // LocalDateTime de Java: sin zona horaria
        'fechaHora': fecha.toIso8601String().split('.').first,
      });

  static Future<void> eliminar(int id) => _api.delete('/api/asistencias/$id');
}

class AccesoService {
  /// rol: "estudiante" o "profesor"
  static Future<bool> habilitado(String rol) async =>
      (await _api.get('/api/login-config/$rol/habilitado')) == true;

  static Future<bool> cambiar(String rol) async {
    final data = await _api.put('/api/login-config/$rol/toggle');
    return data is Map && data['loginHabilitado'] == true;
  }
}

/// Modelo de IA (Random Forest en el servicio de Python), siempre a través de Spring Boot.
class IaService {
  /// Alumnos y materias que conoce el modelo
  static Future<({List<String> alumnos, List<String> clases})> opciones() async {
    final d = Map<String, dynamic>.from(await _api.get('/api/ia/opciones'));
    return (alumnos: List<String>.from(d['alumnos'] ?? const []), clases: List<String>.from(d['clases'] ?? const []));
  }

  /// Probabilidad de que el alumno falte a esa clase en esa fecha
  static Future<PrediccionIA> predecir({
    required String alumno,
    required String clase,
    required DateTime fecha,
  }) async =>
      PrediccionIA.fromJson(await _api.post('/api/ia/predecir', {
        'alumno': alumno,
        'clase': clase,
        'fecha': fecha.toIso8601String().substring(0, 10),
      }));

  /// Métricas, matriz de confusión e importancia de variables
  static Future<ModeloIA> modelo() async => ModeloIA.fromJson(await _api.get('/api/ia/modelo'));

  /// Reentrena con todo el historial de MongoDB
  static Future<ModeloIA> reentrenar() async => ModeloIA.fromJson(await _api.post('/api/ia/modelo/entrenar'));
}

class RiesgoService {
  static const _base = '/coordinador/riesgo/api';

  static Future<ResumenRiesgo> resumen() async => ResumenRiesgo.fromJson(await _api.get('$_base/resumen'));

  static Future<List<AlumnoRiesgo>> alumnos({String? clase}) async {
    final data = await _api.get('$_base/alumnos', query: clase == null ? null : {'clase': clase});
    return (data as List).map((e) => AlumnoRiesgo.fromJson(e)).toList();
  }

  static Future<List<String>> clases() async => List<String>.from(await _api.get('$_base/clases'));

  static Future<Tendencia> tendencia() async => Tendencia.fromJson(await _api.get('$_base/tendencia'));

  static Future<MapaCalor> mapaCalor() async => MapaCalor.fromJson(await _api.get('$_base/mapa-calor'));

  static Future<List<PrediccionFalta>> prediccion({DateTime? fecha, String? clase}) async {
    final data = await _api.get('$_base/prediccion', query: {
      if (fecha != null) 'fecha': fecha.toIso8601String().substring(0, 10),
      'clase': ?clase,
    });
    return (data as List).map((e) => PrediccionFalta.fromJson(e)).toList();
  }

  static Future<void> reentrenar() => _api.post('$_base/modelo/reentrenar');
}
