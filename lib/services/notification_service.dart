import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ============================================================================
// SERVICIO DE NOTIFICACIONES PUSH (NotificationService)
// Solicita permiso para mostrar notificaciones, guarda el token FCM del
// dispositivo en Firestore y suscribe al usuario a los temas del campus.
// ============================================================================
class NotificationService {
  static bool _done = false;

  static Future<void> init(String uid) async {
    // Evita inicializar más de una vez durante la misma sesión
    if (_done) return;
    _done = true;
    try {
      final fcm = FirebaseMessaging.instance;

      // Solicita permiso al sistema operativo para recibir alertas push
      await fcm.requestPermission();

      // Obtiene el token único de Firebase Cloud Messaging y lo guarda en el perfil
      final token = await fcm.getToken();
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (token != null) {
        await userDoc.reference
            .set({'fcmToken': token}, SetOptions(merge: true));
      }

      // Suscribe al usuario al canal de 'personal' (si aplica) y al canal general 'todos'
      if (userDoc.data()?['role'] == 'personal') {
        await fcm.subscribeToTopic('personal');
      }
      await fcm.subscribeToTopic('todos');
    } catch (_) {
      _done = false;
    }
  }
}
