# Compila la app Flutter para web y la publica en Vercel.
# Uso (PowerShell, dentro de esta carpeta):
#   .\desplegar_web.ps1 -ApiUrl https://asistcontrol-api.onrender.com
# La primera vez, Vercel pedirá iniciar sesión en el navegador y crear el proyecto.

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
$ApiUrl = $ApiUrl.TrimEnd('/')

Write-Host "1/2 Compilando Flutter web contra $ApiUrl ..." -ForegroundColor Cyan
flutter build web --release --dart-define=API_URL=$ApiUrl
if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación de Flutter' }

Write-Host '2/2 Publicando build/web en Vercel ...' -ForegroundColor Cyan
npx vercel deploy build/web --prod
