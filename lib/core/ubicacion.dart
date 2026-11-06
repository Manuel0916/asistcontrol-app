import 'package:geolocator/geolocator.dart';

/// Ubicación del teléfono (sensor GPS) para la geolocalización anti-fraude.
///
/// Pide permiso al usuario la primera vez y devuelve la posición actual
/// con su margen de error (precisión en metros).
class Ubicacion {
  static Future<Position> obtener() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw UbicacionException('El GPS está apagado. Actívalo en los ajustes del teléfono.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission(); // muestra el diálogo del sistema
    }
    if (permiso == LocationPermission.denied) {
      throw UbicacionException('Necesitamos tu ubicación para verificar que estás en el salón.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw UbicacionException(
          'El permiso de ubicación está bloqueado. Actívalo en Ajustes > Aplicaciones > AsistControl.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Si no logra una lectura nueva a tiempo, usa la última conocida
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return ultima;
      throw UbicacionException('No se pudo obtener tu ubicación. Intenta junto a una ventana.');
    }
  }
}

class UbicacionException implements Exception {
  final String mensaje;
  UbicacionException(this.mensaje);
  @override
  String toString() => mensaje;
}
