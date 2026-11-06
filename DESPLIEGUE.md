# Despliegue gratis en la nube — AsistControl

```
 Cualquier teléfono               Render (gratis)                        Render (gratis)
 https://…vercel.app ──HTTPS──► Spring Boot (Docker) ──X-API-Key──► Servicio IA Python (Docker)
   Vercel (gratis)             web + APIs · JWT · GPS                   Random Forest
                                        │                                     │
                                        └────────► MongoDB Atlas ◄────────────┘
                                         (única base: usuarios, roles, asistencias)
```

| Pieza | Servicio gratis | Carpeta |
|---|---|---|
| App Flutter (web) | **Vercel** | `control_asistencias_flutter` |
| Backend Spring Boot (proyecto web + APIs) | **Render** (Web Service, Docker) | `control_asistencias-main` |
| Servicio de IA (Python) | **Render** (otro Web Service, Docker) | `control_asistencias_ia` |
| Base de datos (todo) | **MongoDB Atlas** (M0 Free) | base `asistcontrol` |

> Ya **no se usa MySQL**: todo vive en MongoDB. Todas las cuentas son gratis y sin tarjeta.

## 0. Código en GitHub ✅
Repositorios privados `Manuel0916/asistcontrol-backend`, `asistcontrol-ia` y `asistcontrol-app`.

## 1. MongoDB Atlas ✅
Cluster0 (M0 Free, AWS N. Virginia), usuario `asistcontrol`, acceso `0.0.0.0/0`.
Pasar los datos (usuarios, roles y asistencias sin repetidos) a la base `asistcontrol` de Atlas,
en PowerShell dentro de `control_asistencias_ia`:
```powershell
.venv\Scripts\python herramientas\migrar_a_mongo.py "mongodb+srv://asistcontrol:CLAVE@cluster0.bjss0sk.mongodb.net/"
```

## 2. Servicio de IA en Render
*New → Web Service* → repo `asistcontrol-ia` → **Docker** → **Free**. Variables:

| Variable | Valor |
|---|---|
| `MONGO_URI` | `mongodb+srv://asistcontrol:CLAVE@cluster0.bjss0sk.mongodb.net/` |
| `MONGO_DB` | `asistcontrol` |
| `IA_API_KEY` | una clave inventada (la misma irá en el backend) |

Prueba: `https://TU-IA.onrender.com/salud` → `"modelo_entrenado": true`.

## 3. Backend (web + APIs) en Render
*New → Web Service* → repo `asistcontrol-backend` → **Docker** → **Free**. Variables:

| Variable | Valor |
|---|---|
| `MONGO_URI` | `mongodb+srv://asistcontrol:CLAVE@cluster0.bjss0sk.mongodb.net/asistcontrol` (con `/asistcontrol` al final) |
| `IA_URL` | `https://TU-IA.onrender.com` |
| `IA_API_KEY` | la misma del paso 2 |
| `JWT_SECRET` | una frase larga inventada (mínimo 32 caracteres) |
| `MCP_ENABLED` | `false` |
| `CORS_ORIGINS` | `https://TU-APP.vercel.app` (se completa en el paso 4) |

Prueba: `https://TU-BACKEND.onrender.com/login` muestra el login web.

## 4. App Flutter en Vercel
1. Cuenta en https://vercel.com (con GitHub).
2. En PowerShell, carpeta `control_asistencias_flutter`:
   ```powershell
   .\desplegar_web.ps1 -ApiUrl https://TU-BACKEND.onrender.com
   ```
3. Pon la URL que te da en `CORS_ORIGINS` del backend en Render → *Save*.

## 5. Usarla en cualquier teléfono
Abre la URL de Vercel en Chrome/Safari → ⋮ → **Agregar a pantalla de inicio**.
La cámara (QR) y el GPS funcionan porque Vercel usa HTTPS.

## Limitaciones del plan gratis (dilo en la sustentación)
- **Render se duerme tras 15 min sin uso**: la primera petición tarda ~1 minuto. Abre la app
  2–3 minutos antes de presentar.
- **ControlBot (Ollama)** no corre en la nube gratis. La IA del proyecto es el Random Forest en Python.
- Las sesiones de clase con GPS viven en memoria: si Render se reinicia, el profesor genera un QR nuevo.
