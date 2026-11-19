import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// Gestiona permisos FCM, tokens de dispositivo, suscripción a temas ('personal',
// 'usuario_{uid}' y 'todos') y muestra 1 sola notificación por cada evento nuevo:
//   1. Nuevos reportes de incidencia (Personal)
//   2. Cambios de estado en reportes (Estudiantes)
//   3. Próximas fechas de vacunación (Personal)
// ============================================================================
class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const MethodChannel _androidNotificationChannel =
      MethodChannel('ec.edu.espoch.pawtrack/notifications');

  static String? _currentUid;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<QuerySnapshot>? _reportsSub;
  static StreamSubscription? _vaccinesSub;
  static OverlayEntry? _activeOverlay;
  static Timer? _overlayTimer;

  // Conjunto permanente de claves ya notificadas para que cada evento se
  // muestre exactamente 1 sola vez y jamás entre en bucle.
  static final Set<String> _shownAlertKeys = {};
  static DateTime _lastBannerTime = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> init(String uid) async {
    if (_currentUid == uid) return;
    final previousUid = _currentUid;
    await dispose();
    _currentUid = uid;

    final db = FirebaseFirestore.instance;
    String role = 'estudiante';

    try {
      final userDoc = await db.collection('usuarios').doc(uid).get();
      final userData = userDoc.data() ?? {};
      role = (userData['role'] ?? 'estudiante').toString();
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

      // Obtiene y guarda el token FCM actual en el perfil del usuario ('usuarios')
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
        if (previousUid != null && previousUid != uid) {
          await fcm.unsubscribeFromTopic('usuario_$previousUid');
        }
        await fcm.subscribeToTopic('usuario_$uid');
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
          final reportId = message.data['reportId']?.toString() ?? '';
          final status = message.data['status']?.toString() ?? '';
          final vaccineId = message.data['vaccineId']?.toString() ?? '';
          final type = message.data['type']?.toString() ?? 'fcm';

          final dedupKey = switch (type) {
            'nuevo_reporte' => 'nuevo_reporte_$reportId',
            'cambio_estado' => 'cambio_estado_${reportId}_$status',
            'proxima_vacuna' => 'proxima_vacuna_$vaccineId',
            _ => 'fcm_${message.messageId ?? '$title|$body'}',
          };

          _showSingleAlert(
            key: dedupKey,
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

    // 2. Listeners en tiempo real con Firestore (sin escrituras internas para evitar bucles)
    _startRealtimeListeners(
      uid: uid,
      isStaff: role == 'personal',
    );
  }

  static void _startRealtimeListeners({
    required String uid,
    required bool isStaff,
  }) {
    final db = FirebaseFirestore.instance;

    if (isStaff) {
      // A) Personal: Escucha ÚNICAMENTE reportes nuevos creados después de abrir la app
      final Set<String> existingReportIds = {};
      bool initialReportsLoad = true;

      _reportsSub = db.collection('reportes').snapshots().listen((snapshot) {
        if (initialReportsLoad) {
          for (final doc in snapshot.docs) {
            existingReportIds.add(doc.id);
          }
          initialReportsLoad = false;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added &&
              existingReportIds.add(change.doc.id)) {
            final data = change.doc.data() ?? {};
            final reporterId = (data['reporterId'] ?? '').toString();
            if (reporterId == uid) continue;

            final dogName =
                (data['dogName'] ?? data['perroNombre'])?.toString();
            final label = (dogName != null && dogName.isNotEmpty)
                ? dogName
                : 'Perro sin identificar';
            final desc =
                (data['description'] ?? data['descripcion'] ?? '').toString();

            _showSingleAlert(
              key: 'nuevo_reporte_${change.doc.id}',
              title: 'Nuevo reporte de incidencia',
              body: '$label: $desc',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            );
          }
        }
      });

      // B) Personal: Verifica vacunas próximas (registra las existentes al inicio
      // y solo notifica 1 vez cuando se agrega una nueva vacuna próxima)
      bool initialVaccinesLoad = true;
      _vaccinesSub =
          DataService.upcomingVaccines(withinDays: 7).listen((alerts) {
        if (initialVaccinesLoad) {
          for (final alert in alerts) {
            _shownAlertKeys.add('proxima_vacuna_${alert.vaccineId}');
          }
          initialVaccinesLoad = false;
          return;
        }

        for (final alert in alerts) {
          final d = alert.nextDate;
          final dateStr =
              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          _showSingleAlert(
            key: 'proxima_vacuna_${alert.vaccineId}',
            title: 'Próxima vacunación: ${alert.dogName}',
            body: 'Dosis de ${alert.vaccineName} programada para el $dateStr.',
            icon: Icons.vaccines_rounded,
            color: const Color(0xFF7C3AED),
          );
        }
      });
    } else {
      // C) Estudiante: Guarda el estado actual de sus reportes al abrir la app
      // y dispara 1 sola notificación únicamente cuando un estado cambia en vivo.
      final Map<String, String> knownStatuses = {};
      bool initialStudentLoad = true;

      _reportsSub = db
          .collection('reportes')
          .where('reporterId', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        if (initialStudentLoad) {
          for (final doc in snapshot.docs) {
            final currentStatus =
                (doc.data()['status'] ?? 'pendiente').toString();
            knownStatuses[doc.id] = currentStatus;
            _shownAlertKeys.add('cambio_estado_${doc.id}_$currentStatus');
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
            final dogName =
                (data['dogName'] ?? data['perroNombre'])?.toString();
            final label = (dogName != null && dogName.isNotEmpty)
                ? dogName
                : 'Perro sin identificar';
            final statusText = switch (newStatus) {
              'en_revision' || 'en_atencion' => 'En revisión',
              'resuelto' => 'Resuelto',
              _ => 'Pendiente',
            };

            _showSingleAlert(
              key: 'cambio_estado_${change.doc.id}_$newStatus',
              title: 'Estado actualizado: $statusText',
              body:
                  'El reporte sobre $label cambió de estado a "$statusText".',
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

  /// Muestra la notificación 1 sola vez por clave única ([key]). Si la clave ya
  /// fue mostrada anteriormente (por FCM o por Firestore), la ignora por completo.
  static void _showSingleAlert({
    required String key,
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    // Si esta alerta ya se mostró antes en la sesión, no se vuelve a repetir jamás
    if (!_shownAlertKeys.add(key)) {
      return;
    }

    // Protección adicional contra dos eventos simultáneos en menos de 2 segundos
    final now = DateTime.now();
    if (now.difference(_lastBannerTime).inMilliseconds < 1500) {
      return;
    }
    _lastBannerTime = now;

    // 1. Notificación nativa en la barra de estado de Android
    if (!kIsWeb) {
      _androidNotificationChannel.invokeMethod('showSystemNotification', {
        'id': key.hashCode.abs() % 100000,
        'title': title,
        'body': body,
      }).catchError((_) {});
    }

    // 2. Banner superior desplegable dentro de la app
    Future.delayed(const Duration(milliseconds: 300), () {
      final overlayState = navigatorKey.currentState?.overlay;
      if (overlayState == null) return;

      _overlayTimer?.cancel();
      _activeOverlay?.remove();
      _activeOverlay = null;

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) {
          final topPadding = MediaQuery.of(context).padding.top;
          return Positioned(
            top: topPadding + 10,
            left: 14,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: -80.0, end: 0.0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) {
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    _overlayTimer?.cancel();
                    entry.remove();
                    if (_activeOverlay == entry) _activeOverlay = null;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2B48),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.pets,
                                      size: 12, color: Color(0xFF93C5FD)),
                                  SizedBox(width: 5),
                                  Text(
                                    'PAWTRACK · AHORA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF93C5FD),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
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
                                    fontSize: 12.5,
                                    color: Color(0xFFE2E8F0),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      _activeOverlay = entry;
      overlayState.insert(entry);

      _overlayTimer = Timer(const Duration(seconds: 5), () {
        if (_activeOverlay == entry) {
          entry.remove();
          _activeOverlay = null;
        }
      });
    });
  }

  static Future<void> dispose() async {
    _currentUid = null;
    _overlayTimer?.cancel();
    _activeOverlay?.remove();
    _activeOverlay = null;
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
