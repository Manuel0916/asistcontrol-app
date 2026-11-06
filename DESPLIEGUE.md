# Despliegue gratis en la nube — AsistControl

```
 Cualquier teléfono                Render (gratis)                         Render (gratis)
 https://…vercel.app ──HTTPS──► Spring Boot (Docker) ──X-API-Key──► Servicio IA Python (Docker)
   Vercel (gratis)             JWT · asistencias · GPS                  Random Forest
                                  │            │                              │
                                  ▼            └──────────► MongoDB Atlas ◄───┘
                            MySQL (Aiven)               (historial de asistencias)
```

| Pieza | Servicio gratis | Carpeta |
|---|---|---|
| App Flutter (web) | **Vercel** | `control_asistencias_flutter` |
| Backend Spring Boot | **Render** (Web Service, Docker) | `control_asistencias-main` |
| Servicio de IA (Python) | **Render** (otro Web Service, Docker) | `control_asistencias_ia` |
| MySQL (usuarios + asistencias) | **Aiven** (plan Free) | — |
| MongoDB (historial para la IA) | **MongoDB Atlas** (M0 Free) | — |

> Todas las cuentas son gratis y **las creas tú**; yo te guío paso a paso.
> Revisa los límites del plan gratis al registrarte, porque pueden cambiar.

## 0. Subir el código a GitHub
Render toma el código desde GitHub. Se crean 2 repositorios (pueden ser privados):
`control_asistencias-main` y `control_asistencias_ia`.

## 1. MongoDB Atlas (historial)
1. https://www.mongodb.com/cloud/atlas → cuenta → *Create* → **M0 Free**.
2. *Database Access*: crea un usuario y contraseña. *Network Access*: **0.0.0.0/0**
   (Render no tiene IP fija).
3. *Connect → Drivers*: copia la cadena `mongodb+srv://…`.
4. Copia tus datos (en PowerShell, carpeta `control_asistencias_ia`):
   ```powershell
   .venv\Scripts\python herramientas\copiar_a_atlas.py "mongodb+srv://USUARIO:CLAVE@cluster.xxxx.mongodb.net"
   ```

## 2. MySQL en Aiven
1. https://aiven.io → *Create service* → **MySQL** → plan **Free**.
2. Copia **Host**, **Port**, **User** (`avnadmin`) y **Password**.
3. Copia tus datos locales:
   ```powershell
   & "C:\Program Files\MySQL\MySQL Server 9.1\bin\mysqldump.exe" -u root -p --databases control_asistencia --set-gtid-purged=OFF > respaldo.sql
   & "C:\Program Files\MySQL\MySQL Server 9.1\bin\mysql.exe" -h HOST -P PUERTO -u avnadmin -p --ssl-mode=REQUIRED < respaldo.sql
   ```

## 3. Servicio de IA en Render
*New → Web Service* → repo `control_asistencias_ia` → **Docker** → **Free**. Variables:

| Variable | Valor |
|---|---|
| `MONGO_URI` | la cadena de Atlas |
| `IA_API_KEY` | una clave inventada (la misma irá en Spring Boot) |

Al terminar, `https://TU-IA.onrender.com/salud` debe responder `"modelo_entrenado": true`.

## 4. Backend Spring Boot en Render
*New → Web Service* → repo `control_asistencias-main` → **Docker** → **Free**. Variables:

| Variable | Valor |
|---|---|
| `DB_URL` | `jdbc:mysql://HOST:PUERTO/control_asistencia?sslMode=REQUIRED` |
| `DB_USER` / `DB_PASSWORD` | los de Aiven |
| `MONGO_URI` | `mongodb+srv://…/control_asistencia_mongo` (la de Atlas con el nombre de la base al final) |
| `IA_URL` | `https://TU-IA.onrender.com` |
| `IA_API_KEY` | la misma clave del paso 3 |
| `JWT_SECRET` | una frase larga inventada (mínimo 32 caracteres) |
| `MCP_ENABLED` | `false` |
| `SHOW_SQL` | `false` |
| `CORS_ORIGINS` | `https://TU-APP.vercel.app` (se completa en el paso 5) |

Prueba: `https://TU-BACKEND.onrender.com/login` muestra el login web.

## 5. App Flutter en Vercel
1. Cuenta en https://vercel.com.
2. En PowerShell, carpeta `control_asistencias_flutter`:
   ```powershell
   .\desplegar_web.ps1 -ApiUrl https://TU-BACKEND.onrender.com
   ```
3. Te da la URL (p. ej. `https://asistcontrol.vercel.app`). Ponla en `CORS_ORIGINS` del
   backend en Render → *Save*.

## 6. Usarla en cualquier teléfono
Abre la URL de Vercel en Chrome/Safari → ⋮ → **Agregar a pantalla de inicio**.
La cámara (QR) y el GPS funcionan porque Vercel usa HTTPS.

## Limitaciones del plan gratis (dilo en la sustentación)
- **Render se duerme tras 15 min sin uso**: la primera petición tarda ~1 minuto (y la IA
  otro poco). Abre la app 2–3 minutos antes de presentar.
- **ControlBot (Ollama)** no corre en la nube gratis. La IA del proyecto es el modelo
  Random Forest del servicio de Python.
- Las sesiones de clase con GPS viven en memoria: si Render se reinicia, el profesor genera un QR nuevo.
