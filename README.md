# PawTrack (Flutter + Firebase)

App móvil para registro, seguimiento sanitario y reporte de incidencias de perros de la ESPOCH.

## Qué incluye
- Login / registro con Firebase Authentication (correo y Google; roles: estudiante y personal)
- Perros: listado, conteo, registro con foto (solo personal), detalle
- Vacunas: historial, fecha aplicada y próxima dosis
- Reportes: foto + descripción + GPS, perro identificado o "sin identificar"
- Gestión de reportes (personal): cambiar estado e identificar perros después
- OpenStreetMap con reportes (colores por estado, sin clave de API)
- FCM: notificaciones (Cloud Functions en /functions)
- Reglas de seguridad de Firestore y Storage

## Pasos
1. Instala Flutter y Android Studio.
2. En esta carpeta:
   ```
   flutter create . --org ec.edu.espoch --platforms android,ios
   flutter pub get
   ```
3. En https://console.firebase.google.com crea un proyecto y activa Authentication (correo/contraseña), Firestore y Cloud Messaging. Firebase Storage es opcional; las fotos de perros usan Storage y requieren el plan Blaze. Las fotos de reportes se guardan comprimidas en Firestore (máximo 600 KB), así que no necesitan Storage.
   Para Google Sign-In, activa también el proveedor Google en Authentication → Método de acceso e indica nombre público y correo de asistencia. En Authentication → Configuración → Dominios autorizados agrega `localhost` y `127.0.0.1` para desarrollo local. No publiques el servidor de desarrollo en Internet.
4. Conecta Firebase (reemplaza lib/firebase_options.dart):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Mapas: la app usa mosaicos de OpenStreetMap mediante `flutter_map`. No requiere clave de API. Mantén visible la atribución © OpenStreetMap contributors y respeta la política de uso de mosaicos de OpenStreetMap.
6. Permisos (encima de `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```
   En android/app/build.gradle: `minSdkVersion 23`.
   Para Google Sign-In nativo en Android, añade además la huella SHA-1 de la app en Configuración del proyecto → Tus apps Android; después descarga de nuevo `google-services.json`. En iOS se necesita registrar la configuración OAuth del cliente iOS.
7. Copia firestore.rules y storage.rules en la consola de Firebase (pestaña Reglas).
8. `flutter run`

## Vista en un teléfono
Para revisar la versión web en un teléfono conectado a la misma red Wi-Fi, ejecuta el servidor local incluido y abre desde el teléfono `http://<IP-LOCAL-DE-TU-PC>:5101`. Es solo para pruebas en una red de confianza; el servidor de desarrollo no debe exponerse a Internet.

## Usuario "personal"
Regístrate (quedas como estudiante) y en Firestore → usuarios → tu documento cambia `role` a `personal`.

El catálogo de perros se almacena en la colección existente `CANES` (Firebase distingue entre mayúsculas y minúsculas). Las vacunas e historial médico son subcolecciones de cada documento de `CANES`.

Los perfiles se guardan en la colección `usuarios`. Firebase Authentication es independiente de Firestore: borrar el perfil bloquea el acceso a PawTrack, pero no elimina la cuenta de inicio de sesión. Para borrar también las credenciales, elimina la cuenta en Authentication → Users. Durante la transición, los perfiles antiguos de `users` se copian a `usuarios` al iniciar sesión; la colección antigua debe retirarse después de verificar la migración.

## Avatares automáticos (DiceBear)

PawTrack genera avatares con la API pública y gratuita de [DiceBear](https://www.dicebear.com) (sin clave ni registro):

- **Usuarios:** en Ajustes → Personalizar avatar se elige un estilo (`critters`, `fun-emoji`, `thumbs`); se guardan `avatarStyle` y `avatarSeed` en `usuarios`.
- **Perros sin foto:** se muestra un avatar `thumbs` generado con el id del documento de `CANES`, así no cambia si se edita el nombre. Si la foto real falla al cargar, también se usa el avatar; sin conexión se muestra el ícono de huella.

Toda la construcción de URLs está en `lib/services/avatar_service.dart` y el widget reutilizable en `lib/widgets/dog_avatar.dart`. Ejemplo: `https://api.dicebear.com/9.x/thumbs/png?seed=abc123&size=160`.

## Avatar con IA (Pollinations.AI)

**Foto de perfil → avatar IA:** en Ajustes → *Personalizar avatar* → **Crear avatar con IA**, el usuario elige una foto; la app la sube a Cloudinary (Pollinations necesita una URL pública), la manda a `gen.pollinations.ai/image/...?model=kontext&image=<url>` y muestra el resultado. Al pulsar *Guardar avatar* se guarda en `usuarios` con `avatarType: 'ai'`. Requiere `--dart-define=POLLINATIONS_KEY=...`.

En la ficha de un perro, el personal ve la tarjeta **Avatar con IA** con el botón *Generar avatar*. La imagen se pide a [Pollinations.AI](https://pollinations.ai), se sube a Cloudinary y queda guardada en el campo `aiAvatarUrl` del perro. Se muestra cuando el perro no tiene foto; si falla, se usa el avatar de DiceBear.

- **Gratis, sin clave (por defecto):** `https://image.pollinations.ai/prompt/{prompt}`. Es texto→imagen: el prompt se arma con color, sexo, raza estimada y collar. Límite aproximado de una petición cada 45 s por IP.
- **A partir de la foto (opcional):** Pollinations exige clave para imagen→imagen. Crea una en https://enter.pollinations.ai y ejecuta `flutter run --dart-define=POLLINATIONS_KEY=sk_xxx`. Se usa `gen.pollinations.ai` con `model=kontext` y la foto del perro como referencia. Consume créditos ("pollen") de tu cuenta.

Código: `lib/services/ai_avatar_service.dart` y `lib/widgets/ai_avatar_card.dart`.

## Notificaciones (opcional, plan Blaze)
```
npm install -g firebase-tools
firebase login
firebase init functions   # NO sobrescribas index.js
cd functions && npm install && firebase deploy --only functions
```
Si Firestore pide crear un índice, abre el enlace del error y dale "Crear".
