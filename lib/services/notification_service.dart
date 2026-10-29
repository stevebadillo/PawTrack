import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Firebase Cloud Messaging (RF15). Guarda el token y se suscribe a temas.
/// El envío lo hacen las Cloud Functions de /functions/index.js.
class NotificationService {
  static bool _done = false;

  static Future<void> init(String uid) async {
    if (_done) return;
    _done = true;
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      final token = await fcm.getToken();
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (token != null) {
        await userDoc.reference
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      if (userDoc.data()?['role'] == 'personal')
        await fcm.subscribeToTopic('personal');
      await fcm.subscribeToTopic('todos');
    } catch (_) {
      _done = false;
    }
  }
}
