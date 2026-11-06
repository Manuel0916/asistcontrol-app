import '../core/config.dart';

/// Usuario autenticado (lo devuelve /api/auth/login y /api/auth/me).
class Usuario {
  final int? id;
  final String username;
  final String email;

  /// ADMIN (profesor), COORDINADOR o ESTUDIANTE
  final String rol;

  Usuario({this.id, required this.username, required this.email, required this.rol});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: (j['id'] as num?)?.toInt(),
        username: j['username'] ?? '',
        email: j['email'] ?? '',
        rol: (j['rol'] ?? 'ESTUDIANTE').toString().toUpperCase(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'email': email, 'rol': rol};

  String get rolLegible => switch (rol) {
        'ADMIN' => 'Profesor',
        'COORDINADOR' => 'Coordinador',
        _ => 'Estudiante',
      };
}

enum Estado { presente, tarde, ausente }

Estado estadoDesde(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'tarde':
      return Estado.tarde;
    case 'ausente':
      return Estado.ausente;
    default:
      return Estado.presente;
  }
}

extension EstadoTexto on Estado {
  String get texto => switch (this) {
        Estado.presente => 'Presente',
        Estado.tarde => 'Tarde',
        Estado.ausente => 'Ausente',
      };
}

/// Un registro de asistencia (tabla "asistencias" del backend).
class Asistencia {
  final int id;
  final String nombre;
  final String clase;
  final Estado estado;
  final DateTime fechaHora;

  Asistencia({
    required this.id,
    required this.nombre,
    required this.clase,
    required this.estado,
    required this.fechaHora,
  });

  factory Asistencia.fromJson(Map<String, dynamic> j) => Asistencia(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nombre: j['nombre'] ?? '',
        clase: j['clase'] ?? '',
        estado: estadoDesde(j['estado']),
        fechaHora: parseFecha(j['fechaHora']),
      );

  String get claseLegible => Clases.nombre(clase);
}

/// Spring puede enviar LocalDateTime como texto ISO o como lista [a, m, d, h, min, s].
DateTime parseFecha(dynamic v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is List && v.length >= 3) {
    int at(int i) => i < v.length ? (v[i] as num).toInt() : 0;
    return DateTime(at(0), at(1), at(2), at(3), at(4), at(5));
  }
  return DateTime.now();
}

// ---------------- Módulo de riesgo (coordinador) ----------------

enum NivelRiesgo { verde, amarillo, rojo }

NivelRiesgo nivelDesde(String? s) => switch ((s ?? '').toUpperCase()) {
      'ROJO' => NivelRiesgo.rojo,
      'AMARILLO' => NivelRiesgo.amarillo,
      _ => NivelRiesgo.verde,
    };

class ResumenRiesgo {
  final int total, rojo, amarillo, verde;
  final double umbralPerdida, umbralAlerta;
  ResumenRiesgo.fromJson(Map<String, dynamic> j)
      : total = (j['totalAlumnoMateria'] as num?)?.toInt() ?? 0,
        rojo = (j['rojo'] as num?)?.toInt() ?? 0,
        amarillo = (j['amarillo'] as num?)?.toInt() ?? 0,
        verde = (j['verde'] as num?)?.toInt() ?? 0,
        umbralPerdida = (j['umbralPerdida'] as num?)?.toDouble() ?? 25,
        umbralAlerta = (j['umbralAlerta'] as num?)?.toDouble() ?? 18;
}

class AlumnoRiesgo {
  final String alumno, clase;
  final int clasesRegistradas, ausencias, tardanzas, clasesSemestre, faltasRestantes;
  final double porcentaje, proyectado;
  final NivelRiesgo nivel;
  AlumnoRiesgo.fromJson(Map<String, dynamic> j)
      : alumno = j['alumno'] ?? '',
        clase = j['clase'] ?? '',
        clasesRegistradas = (j['clasesRegistradas'] as num?)?.toInt() ?? 0,
        ausencias = (j['ausencias'] as num?)?.toInt() ?? 0,
        tardanzas = (j['tardanzas'] as num?)?.toInt() ?? 0,
        clasesSemestre = (j['clasesSemestre'] as num?)?.toInt() ?? 0,
        faltasRestantes = (j['faltasRestantesPermitidas'] as num?)?.toInt() ?? 0,
        porcentaje = (j['porcentajeInasistencia'] as num?)?.toDouble() ?? 0,
        proyectado = (j['porcentajeProyectado'] as num?)?.toDouble() ?? 0,
        nivel = nivelDesde(j['nivel']);
}

class Tendencia {
  final List<String> meses;
  final List<double> porcentaje;
  Tendencia.fromJson(Map<String, dynamic> j)
      : meses = List<String>.from(j['meses'] ?? const []),
        porcentaje = ((j['porcentajeAusencia'] ?? const []) as List)
            .map((e) => (e as num?)?.toDouble() ?? 0)
            .toList();
}

class MapaCalor {
  final List<String> clases, dias;
  final List<List<double?>> valores;
  MapaCalor.fromJson(Map<String, dynamic> j)
      : clases = List<String>.from(j['clases'] ?? const []),
        dias = List<String>.from(j['dias'] ?? const []),
        valores = ((j['valores'] ?? const []) as List)
            .map((fila) => (fila as List).map((v) => (v as num?)?.toDouble()).toList())
            .toList();
}

class PrediccionFalta {
  final String alumno, clase, nivel;
  final double probabilidad, tasaHistorica;
  PrediccionFalta.fromJson(Map<String, dynamic> j)
      : alumno = j['alumno'] ?? '',
        clase = j['clase'] ?? '',
        nivel = (j['nivel'] ?? '').toString(),
        probabilidad = (j['probabilidadFalta'] as num?)?.toDouble() ?? 0,
        tasaHistorica = (j['tasaHistorica'] as num?)?.toDouble() ?? 0;
}

// ---------------- Modelo de IA (Random Forest, servicio en Python) ----------------

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Resultado de POST /api/ia/predecir
class PrediccionIA {
  final String alumno, clase, diaSemana, mes, nivel, prediccion;
  final double probabilidad; // 0 a 1
  final double tasaHistorica, tasaEnMateria;
  final int faltasUltimas5, clasesRegistradas;

  PrediccionIA.fromJson(Map<String, dynamic> j)
      : alumno = j['alumno'] ?? '',
        clase = j['clase'] ?? '',
        diaSemana = j['dia_semana'] ?? '',
        mes = j['mes'] ?? '',
        nivel = j['nivel'] ?? 'BAJA',
        prediccion = j['prediccion'] ?? '',
        probabilidad = _d(j['probabilidad_falta']),
        tasaHistorica = _d(j['factores']?['tasa_historica']),
        tasaEnMateria = _d(j['factores']?['tasa_en_materia']),
        faltasUltimas5 = (j['factores']?['faltas_ultimas5'] as num?)?.toInt() ?? 0,
        clasesRegistradas = (j['factores']?['clases_registradas'] as num?)?.toInt() ?? 0;
}

/// Resultado de GET /api/ia/modelo
class ModeloIA {
  final String algoritmo, entrenadoEn;
  final String? advertencia;
  final int registros, registrosPrueba, alumnos;
  final double tasaBase, umbral, accuracy, auc, precision, recall, f1;
  final int vn, fp, fn, vp; // matriz de confusión
  final List<({String nombre, double importancia})> importancia;

  ModeloIA.fromJson(Map<String, dynamic> j)
      : algoritmo = j['algoritmo'] ?? '',
        entrenadoEn = j['entrenado_en'] ?? '',
        advertencia = j['advertencia'],
        registros = (j['registros'] as num?)?.toInt() ?? 0,
        registrosPrueba = (j['registros_prueba'] as num?)?.toInt() ?? 0,
        alumnos = (j['alumnos'] as num?)?.toInt() ?? 0,
        tasaBase = _d(j['tasa_base_ausencia']),
        umbral = _d(j['umbral_falta']),
        accuracy = _d(j['accuracy']),
        auc = _d(j['auc']),
        precision = _d(j['precision']),
        recall = _d(j['recall']),
        f1 = _d(j['f1']),
        vn = (j['matriz_confusion']?['asistio_predijo_asiste'] as num?)?.toInt() ?? 0,
        fp = (j['matriz_confusion']?['asistio_predijo_falta'] as num?)?.toInt() ?? 0,
        fn = (j['matriz_confusion']?['falto_predijo_asiste'] as num?)?.toInt() ?? 0,
        vp = (j['matriz_confusion']?['falto_predijo_falta'] as num?)?.toInt() ?? 0,
        importancia = ((j['importancia'] ?? const []) as List)
            .map((e) => (nombre: (e['nombre'] ?? '').toString(), importancia: _d(e['importancia'])))
            .toList();
}
