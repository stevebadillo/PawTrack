import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import 'data_service.dart';

// ============================================================================
// MANEJADOR DE MENSAJES FCM EN SEGUNDO PLANO (Background Handler)
// Debe ser una función de nivel superior con @pragma('vm:entry-point') para
// que Android e iOS puedan invocarla cuando la app está cerrada o minimizada.
// ============================================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// ============================================================================
// SERVICIO DE NOTIFICACIONES PUSH Y ALERTAS EN TIEMPO REAL (NotificationService)
// Gestiona permisos FCM, tokens de dispositivo, suscripción a temas ('personal'
// y 'todos'), recepción de mensajes en primer/segundo plano y alertas en
// tiempo real para:
//   1. Nuevos reportes de incidencia (Personal)
//   2. Cambios de estado en reportes (Estudiantes)
//   3. Próximas fechas de vacunación (Personal)
// ============================================================================
class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _currentUid;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<QuerySnapshot>? _reportsSub;
  static StreamSubscription? _vaccinesSub;

  // Registro para evitar mostrar banners duplicados si llegan por FCM y Firestore al mismo tiempo
  static final Map<String, DateTime> _recentAlerts = {};
  static final Set<String> _notifiedVaccineIds = {};

  static Future<void> init(String uid) async {
    if (_currentUid == uid) return;
    await dispose();
    _currentUid = uid;

    final db = FirebaseFirestore.instance;
    String role = 'estudiante';

    try {
      final userDoc = await db.collection('usuarios').doc(uid).get();
      role = (userDoc.data()?['role'] ?? 'estudiante').toString();
    } catch (_) {}

    // 1. Configuración de Firebase Cloud Messaging (FCM)
    try {
      final fcm = FirebaseMessaging.instance;

      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Obtiene y guarda el token FCM actual en el perfil del usuario
      final token = await fcm.getToken();
      if (token != null) {
        await db.collection('usuarios').doc(uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Escucha renovaciones automáticas del token FCM
      _tokenSub = fcm.onTokenRefresh.listen((newToken) async {
        try {
          await db.collection('usuarios').doc(uid).set({
            'fcmToken': newToken,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      });

      // Suscripción a temas (Topics) en plataformas nativas (Android / iOS)
      if (!kIsWeb) {
        if (role == 'personal') {
          await fcm.subscribeToTopic('personal');
        } else {
          await fcm.unsubscribeFromTopic('personal');
        }
        await fcm.subscribeToTopic('todos');
      }

      // Escucha mensajes FCM cuando la aplicación está abierta en primer plano
      _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        if (notif != null) {
          final title = notif.title ?? 'Notificación PawTrack';
          final body = notif.body ?? '';
          _showInAppBanner(
            key: '$title|$body',
            title: title,
            body: body,
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF0D3B73),
          );
        }
      });
    } catch (_) {
      // Si el navegador web o emulador no soporta FCM, los listeners de
      // Firestore en tiempo real seguirán entregando las notificaciones.
    }

    // 2. Listeners en tiempo real con Firestore (Funciona 100% en plan gratuito Spark)
    _startRealtimeListeners(uid: uid, isStaff: role == 'personal');
  }

  static void _startRealtimeListeners({
    required String uid,
    required bool isStaff,
  }) {
    final db = FirebaseFirestore.instance;

    if (isStaff) {
      // A) Personal: Escucha nuevos reportes creados en tiempo real
      bool initialReportsLoad = true;
      _reportsSub = db.collection('reportes').snapshots().listen((snapshot) {
        if (initialReportsLoad) {
          initialReportsLoad = false;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() ?? {};
            final reporterId = (data['reporterId'] ?? '').toString();
            if (reporterId == uid) continue; // No auto-notificar si lo creó la misma persona
            final dogName = (data['dogName'] ?? data['perroNombre'])?.toString();
            final label = (dogName != null && dogName.isNotEmpty)
                ? dogName
                : 'Perro sin identificar';
            final desc = (data['description'] ?? data['descripcion'] ?? '').toString();
            _showInAppBanner(
              key: 'new_report_${change.doc.id}',
              title: 'Nuevo reporte de incidencia',
              body: '$label: $desc',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            );
          }
        }
      });

      // B) Personal: Verifica vacunas próximas a vencer (en los próximos 7 días)
      _vaccinesSub =
          DataService.upcomingVaccines(withinDays: 7).listen((alerts) {
        for (final alert in alerts) {
          final alertKey = '${alert.dogId}_${alert.vaccineId}';
          if (_notifiedVaccineIds.add(alertKey)) {
            final d = alert.nextDate;
            final dateStr =
                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            _showInAppBanner(
              key: 'vaccine_$alertKey',
              title: 'Próxima vacunación: ${alert.dogName}',
              body: 'Dosis de ${alert.vaccineName} programada para el $dateStr.',
              icon: Icons.vaccines_rounded,
              color: const Color(0xFF7C3AED),
            );
          }
        }
      });
    } else {
      // C) Estudiante: Escucha cambios de estado en sus reportes en tiempo real
      final Map<String, String> knownStatuses = {};
      bool initialStudentLoad = true;

      _reportsSub = db
          .collection('reportes')
          .where('reporterId', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        if (initialStudentLoad) {
          for (final doc in snapshot.docs) {
            knownStatuses[doc.id] =
                (doc.data()['status'] ?? 'pendiente').toString();
          }
          initialStudentLoad = false;
          return;
        }

        for (final change in snapshot.docChanges) {
          final data = change.doc.data() ?? {};
          final newStatus = (data['status'] ?? 'pendiente').toString();
          final prevStatus = knownStatuses[change.doc.id];
          knownStatuses[change.doc.id] = newStatus;

          if (change.type == DocumentChangeType.modified &&
              prevStatus != null &&
              prevStatus != newStatus) {
            final dogName = (data['dogName'] ?? data['perroNombre'])?.toString();
            final label = (dogName != null && dogName.isNotEmpty)
                ? dogName
                : 'Perro sin identificar';
            final statusText = switch (newStatus) {
              'en_revision' || 'en_atencion' => 'En revisión',
              'resuelto' => 'Resuelto',
              _ => 'Pendiente',
            };
            _showInAppBanner(
              key: 'status_${change.doc.id}_$newStatus',
              title: 'Tu reporte fue actualizado',
              body: '$label — Nuevo estado: $statusText',
              icon: newStatus == 'resuelto'
                  ? Icons.check_circle_outline_rounded
                  : Icons.sync_rounded,
              color: newStatus == 'resuelto'
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            );
          }
        }
      });
    }
  }

  static void _showInAppBanner({
    required String key,
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    final now = DateTime.now();
    final lastShown = _recentAlerts[key];
    if (lastShown != null && now.difference(lastShown).inSeconds < 10) {
      return;
    }
    _recentAlerts[key] = now;

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF0F2B48),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> dispose() async {
    _currentUid = null;
    await _tokenSub?.cancel();
    await _onMessageSub?.cancel();
    await _reportsSub?.cancel();
    await _vaccinesSub?.cancel();
    _tokenSub = null;
    _onMessageSub = null;
    _reportsSub = null;
    _vaccinesSub = null;
  }
}
