# AsistControl — App móvil (Flutter)

App móvil del sistema de control de asistencias. Usa el **mismo backend Spring Boot**
(`../control_asistencias-main`), que guarda los datos y se comunica con la app por HTTP + JSON
con autenticación **JWT**. La predicción la hace un **servicio de IA en Python**
(`../control_asistencias_ia`, FastAPI + Random Forest) que lee el historial de **MongoDB**.

```
 Celular (Flutter) ──JWT──► Spring Boot ──► MongoDB (usuarios, roles, asistencias)
                                 └──X-API-Key──► IA Python (Random Forest) ──► MongoDB
```

### IA: predicción de faltas
Pestaña **Predicción** (coordinador): eliges alumno, materia y fecha y el modelo da la
probabilidad de que falte (semáforo BAJA/MEDIA/ALTA) y los factores que vio. Debajo,
**"¿Cómo decide el modelo?"**: importancia de cada variable, exactitud, AUC, precisión y
matriz de confusión, y un botón para reentrenar. La pestaña **Riesgo** usa el mismo modelo.

## Roles y pantallas

| Rol (backend) | En la app | Pestañas |
|---|---|---|
| ESTUDIANTE | Estudiante | Escanear QR · Historial · Estadísticas |
| ADMIN | Profesor | Registro manual · Lista · Generar QR · Reportes |
| COORDINADOR | Coordinador | Panel (control de acceso) · Usuarios · Predicción (IA) · Riesgo |

### Funcionalidad avanzada: geolocalización anti-fraude (sensor GPS)
1. El profesor pulsa *Generar QR*: su teléfono lee el GPS (ubicación del salón) y crea una
   **sesión de clase** en el servidor (`POST /api/sesiones`). El QR solo lleva el id de la sesión.
2. El estudiante escanea: su app lee su GPS y lo envía con el QR (`POST /api/asistencias`).
3. El servidor calcula la distancia con la **fórmula de Haversine** y rechaza si está a más de
   100 m (+ margen del GPS, máximo 50 m). También impide registrar dos veces la misma clase.

Código: `lib/core/ubicacion.dart` (permisos y lectura del GPS), `generar_qr_screen.dart`,
`escanear_screen.dart`; en el backend `SesionClaseService.java` (con pruebas en
`SesionClaseServiceTest.java`).

Despliegue en la nube gratis (Vercel + Render + Aiven): ver [DESPLIEGUE.md](DESPLIEGUE.md).

### Mejoras frente a la web
- **QR dinámico**: se renueva cada 20 s y cada código vence a los 45 s (una foto del QR
  enviada por WhatsApp deja de servir). El profesor ve **en vivo** quién va llegando.
- **Estadísticas reales del estudiante**: % de asistencia, racha sin faltar, dona de estados,
  semáforo por materia (umbral 25 % / aviso 18 %) y asistencias por mes.
- **Control de acceso real**: si el coordinador deshabilita "Estudiante" o "Profesor",
  ese rol ya no puede iniciar sesión en la app.
- Lista con buscador, filtros y deslizar para eliminar; reportes TXT/Excel que se
  **comparten** (WhatsApp, correo, Drive); modo oscuro automático; "jalar para actualizar".

## Estructura

```
lib/
  main.dart              arranque; muestra login o el panel según el rol
  core/
    theme.dart           colores y estilos (degradado azul→violeta de la web)
    config.dart          dirección del servidor (editable desde el login) y clases
  data/
    api_client.dart      cliente HTTP: agrega el token y traduce errores
    models.dart          Usuario, Asistencia, datos de riesgo
    services.dart        una función por cada endpoint del backend
  state/
    auth_provider.dart   sesión: login, logout, token guardado cifrado
  widgets/               componentes reutilizables (botones, tarjetas, gráficas, barra inferior)
  features/
    auth/                login
    estudiante/          escanear, historial, estadísticas
    profesor/            registro manual, lista, generar QR, reportes
    coordinador/         panel, registrar usuario, predicción, riesgo
```

**Flujo de una pantalla**: Pantalla → `services.dart` → `api_client.dart` → backend → JSON →
`models.dart` → se dibuja.

## Cómo funciona el login (JWT)
1. La app envía usuario + contraseña a `POST /api/auth/login`.
2. El backend verifica (BCrypt) y devuelve un **token** firmado que dice quién eres y tu rol
   (válido 8 horas).
3. La app lo guarda cifrado (`flutter_secure_storage`) y lo manda en cada petición:
   `Authorization: Bearer <token>`.
4. `JwtAuthFilter` (backend) valida el token. La web sigue usando su sesión normal.

## Cambios hechos en el backend
- `security/JwtService.java`, `security/JwtAuthFilter.java`: crear y validar tokens.
- `controller/AuthApiController.java`: `/api/auth/login`, `/api/auth/me`, `/api/auth/registro`.
- `SecurityConfig.java`: filtro JWT, **las APIs `/api/**` ya no son públicas** (antes cualquiera
  podía leer o borrar datos), CORS para probar en Chrome, respuestas 401 en JSON.
- `asistenciaController.java`: `DELETE /api/asistencias/{id}` (el botón de borrar de la web
  lo llamaba pero no existía) y validación del QR vencido.
- **Weka y Power BI eliminados**: `PrediccionFaltaService` y `AsistenciaAlumnoService` ahora llaman
  al servicio de Python (`IaClient`); `IaController` expone `/api/ia/**` a la app (solo coordinador).
- **MySQL eliminado**: todo vive en MongoDB (base `asistcontrol`). Las entidades usan ids numéricos
  (`IdNumericoCallback`, como el AUTO_INCREMENT de MySQL), así que la app y la web no cambiaron.
- `IAConfig.java`: las herramientas MCP (Docker) son opcionales; sin Docker el backend arranca igual.
- `application.properties`: `app.jwt.secret`, `server.address=0.0.0.0`; `pom.xml`: librería jjwt.

## Cómo probarla

### En el PC (rápido, sin cámara)
```bash
flutter run -d chrome
```

### En tu celular Android (recomendado: el escáner necesita cámara real)
1. Instala **Android Studio** (trae el Android SDK). Ábrelo una vez y deja que instale todo.
   Luego `flutter doctor` debe mostrar ✓ en *Android toolchain* (`flutter doctor --android-licenses`).
2. En el celular: Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" →
   Opciones de desarrollador → activa **Depuración USB**. Conéctalo por cable.
3. PC y celular en la **misma red WiFi**. Averigua la IP del PC con `ipconfig`
   (Adaptador WiFi → Dirección IPv4, p. ej. 192.168.1.50).
4. Arranca el backend y permite Java en el Firewall de Windows (redes privadas).
5. `flutter run` (con el celular conectado). En el login toca ⚙ y pon `http://192.168.1.50:8080`.

Para generar un instalable: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
