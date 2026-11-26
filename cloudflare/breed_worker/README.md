# Proxy gratuito de análisis de razas

Este Worker mantiene la clave de Nakordoni fuera de la aplicación y solo acepta
solicitudes autenticadas con un Firebase ID token de `pawtrack-espoch`.

## Preparación única en una cuenta Cloudflare Free

Desde PowerShell:

```powershell
cd cloudflare/breed_worker
npm install
npx wrangler login
npx wrangler secret put NAKORDONI_API_KEY
npx wrangler deploy
```

Cuando Wrangler pida `NAKORDONI_API_KEY`, pegar la clave de Nakordoni en el
prompt interactivo. No guardarla en archivos ni en Git. La URL que muestra el
despliegue será parecida a `https://pawtrack-breed-api.<cuenta>.workers.dev`.

## Ejecutar PawTrack con el Worker

Desde la raíz del proyecto Flutter, reemplazar la URL por la que imprimió
Wrangler:

```powershell
flutter run --dart-define=PAWTRACK_BREED_API_URL=https://pawtrack-breed-api.<cuenta>.workers.dev
```

El plan gratuito de Workers tiene una cuota diaria. Nakordoni aplica además la
cuota diaria del plan de la clave. Si un reporte está asociado a un perro, la
app intenta guardar la estimación en la ficha; el reporte conserva el resultado
si esa actualización no está permitida.
