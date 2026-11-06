import 'package:asistcontrol/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Asistencia.fromJson interpreta estado y fecha del backend', () {
    final a = Asistencia.fromJson({
      'id': 7,
      'nombre': 'Ana Torres',
      'clase': 'matematicas-A',
      'estado': 'ausente',
      'fechaHora': '2026-05-12T15:54:29.751927',
    });
    expect(a.estado, Estado.ausente);
    expect(a.fechaHora.hour, 15);
    expect(a.claseLegible, 'Matemáticas A');
  });

  test('parseFecha acepta el formato de lista de Spring', () {
    final f = parseFecha([2026, 10, 31, 16, 20]);
    expect(f, DateTime(2026, 10, 31, 16, 20));
  });

  test('Usuario ADMIN se muestra como Profesor', () {
    final u = Usuario.fromJson({'username': 'admin', 'email': 'a@a.co', 'rol': 'ADMIN'});
    expect(u.rolLegible, 'Profesor');
  });
}
