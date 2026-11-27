# API gratuita de estimación de razas

Este Worker usa el modelo `@cf/microsoft/resnet-50` de Cloudflare Workers AI y
solo acepta solicitudes autenticadas con un Firebase ID token de
`pawtrack-espoch`. No necesita clave de Nakordoni ni otra API key. Cloudflare
incluye 10.000 Neurons diarios gratis; al agotarse, la inferencia falla hasta
que se reinicie la cuota al día siguiente (no activa cobros en el plan Free).

## Despliegue en una cuenta Cloudflare Free

Desde PowerShell:

```powershell
cd cloudflare/breed_worker
npm install
npx wrangler login
npx wrangler deploy
```

El Worker usa Workers AI mediante el binding `[ai]` de `wrangler.toml`.

## Ejecutar PawTrack con el Worker

Desde la raíz del proyecto Flutter, reemplazar la URL por la que imprimió
Wrangler:

```powershell
flutter run --dart-define=PAWTRACK_BREED_API_URL=https://pawtrack-breed-api.<cuenta>.workers.dev
```

La clasificación está basada en las razas y clases caninas de ImageNet, por lo
que ofrece una estimación, no una confirmación veterinaria. Si un reporte está
asociado a un perro, la app intenta guardar la estimación en su ficha; el
reporte conserva el resultado si esa actualización no está permitida.
