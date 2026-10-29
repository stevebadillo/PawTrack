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
Regístrate (quedas como estudiante) y en Firestore → users → tu documento cambia `role` a `personal`.

## Notificaciones (opcional, plan Blaze)
```
npm install -g firebase-tools
firebase login
firebase init functions   # NO sobrescribas index.js
cd functions && npm install && firebase deploy --only functions
```
Si Firestore pide crear un índice, abre el enlace del error y dale "Crear".
