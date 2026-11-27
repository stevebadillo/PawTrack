import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';
import 'cloudinary_service.dart';

/// Acceso centralizado a las APIs de datos de PawTrack.
///
/// - Cloud Firestore: usuarios, perros, vacunas, reportes y notificaciones.
/// - Cloudinary: almacenamiento principal de fotos en la nube (HTTP REST).
/// - Firebase Storage: almacenamiento de respaldo opcional.
class DataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // Nombres de colecciones de PawTrack (un solo lugar para cambiarlos).
  // Deben coincidir con los de firestore.rules.
  static const dogCollection = 'canes';
  static const medicalCollection = 'registros_medicos';
  static const vaccineCollection = 'vacunas';
  static const reportCollection = 'reportes';

  /// Sube la foto usando Cloudinary como proveedor principal.
  /// Si Cloudinary falla por falta de configuración o red, intenta con Firebase Storage.
  static Future<String> uploadPhoto(
    Uint8List bytes,
    String folder, {
    String? filename,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('La imagen está vacía.');

    // 1. Intentar subir a Cloudinary primero
    try {
      final cloudinaryUrl = await CloudinaryService.uploadImage(
        bytes,
        folder: folder,
        filename: filename,
        onProgress: onProgress,
      );
      return cloudinaryUrl;
    } catch (cloudinaryError) {
      // 2. Si falla Cloudinary, intentar Firebase Storage como respaldo
      try {
        final safeFilename = filename?.replaceAll(RegExp(r'[^\w.-]'), '_');
        final extension = filename?.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        final ref = _storage.ref(
            '$folder/${DateTime.now().millisecondsSinceEpoch}_${safeFilename ?? 'photo.jpg'}');
        final task = ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        final progressSubscription = task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
        try {
          await task.timeout(const Duration(seconds: 40));
          return await ref
              .getDownloadURL()
              .timeout(const Duration(seconds: 15));
        } finally {
          await progressSubscription.cancel();
        }
      } catch (_) {
        // Relanzar el error informativo de Cloudinary para guiar la configuración
        throw Exception(
            'No se pudo subir la foto a Cloudinary: $cloudinaryError');
      }
    }
  }

  /// Guarda los PDFs en Firebase Storage para que puedan abrirse desde el navegador.
  static Future<String> uploadPdf(
    Uint8List bytes,
    String filename,
  ) async {
    if (bytes.isEmpty) throw ArgumentError('El archivo está vacío.');
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('El PDF no debe superar los 10 MB.');
    }
    if (filename.toLowerCase().split('.').last != 'pdf' ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw ArgumentError('Selecciona un archivo PDF válido.');
    }

    final safeFilename = filename.replaceAll(RegExp(r'[^\w.-]'), '_');
    final ref = _storage.ref(
        'registros_medicos/${DateTime.now().microsecondsSinceEpoch}_$safeFilename');
    final task = ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        contentDisposition: 'inline; filename="$safeFilename"',
      ),
    );
    await task.timeout(const Duration(seconds: 40));
    return ref.getDownloadURL().timeout(const Duration(seconds: 15));
  }

  static Stream<List<Dog>> dogs() => _db
      .collection(dogCollection)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Dog.fromDoc).toList());

  static Stream<Dog> dog(String id) =>
      _db.collection(dogCollection).doc(id).snapshots().map(Dog.fromDoc);

  /// Crea el perro y, opcionalmente, su primer registro médico y su primera
  /// vacuna en una sola operación atómica.
  static Future<String> addDog(
    Map<String, dynamic> data, {
    Map<String, dynamic>? initialMedicalEntry,
    Map<String, dynamic>? initialVaccine,
  }) async {
    final ref = _db.collection(dogCollection).doc();
    final batch = _db.batch()
      ..set(ref, {...data, 'createdAt': FieldValue.serverTimestamp()});
    if (initialMedicalEntry != null) {
      batch.set(ref.collection(medicalCollection).doc(), initialMedicalEntry);
    }
    if (initialVaccine != null) {
      batch.set(ref.collection(vaccineCollection).doc(), initialVaccine);
    }
    await batch.commit();
    return ref.id;
  }

  static Future<void> updateDog(String id, Map<String, dynamic> data) async {
    await _db.collection(dogCollection).doc(id).update(data);
  }

  static Stream<List<MedicalEntry>> medicalEntries(String dogId) => _db
      .collection('$dogCollection/$dogId/$medicalCollection')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MedicalEntry.fromDoc).toList());

  static Future<void> addMedicalEntry(
          String dogId, Map<String, dynamic> data) =>
      _db.collection('$dogCollection/$dogId/$medicalCollection').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Elimina una entrada médica específica de un perro.
  static Future<void> deleteMedicalEntry(
          String dogId, String entryId) =>
      _db
          .collection('$dogCollection/$dogId/$medicalCollection')
          .doc(entryId)
          .delete();

  /// Elimina un perro con sus vacunas y su historial médico,
  /// conservando los reportes antiguos.
  static Future<void> deleteDog(Dog dog) async {
    final dogRef = _db.collection(dogCollection).doc(dog.id);
    final reports = await _db
        .collection(reportCollection)
        .where('dogId', isEqualTo: dog.id)
        .get();
    for (var start = 0; start < reports.docs.length; start += 450) {
      final batch = _db.batch();
      for (final report in reports.docs.skip(start).take(450)) {
        batch.update(report.reference, {
          'dogId': FieldValue.delete(),
          'dogName': report.data()['dogName'] ?? dog.name,
          'dogDeleted': true,
        });
      }
      await batch.commit();
    }

    for (final subcollection in [vaccineCollection, medicalCollection]) {
      final records = await dogRef.collection(subcollection).get();
      for (var start = 0; start < records.docs.length; start += 450) {
        final batch = _db.batch();
        for (final record in records.docs.skip(start).take(450)) {
          batch.delete(record.reference);
        }
        await batch.commit();
      }
    }

    await dogRef.delete();
    if (dog.photoUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(dog.photoUrl).delete();
      } catch (_) {
        // Storage is optional; a missing object must not block dog deletion.
      }
    }
  }

  static Stream<List<Vaccine>> vaccines(String dogId) => _db
      .collection('$dogCollection/$dogId/$vaccineCollection')
      .orderBy('appliedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Vaccine.fromDoc).toList());

  static Future<void> addVaccine(String dogId, String name, DateTime applied,
      DateTime? next, String notes) async {
    final docRef =
        await _db.collection('$dogCollection/$dogId/$vaccineCollection').add({
      'name': name,
      'appliedAt': Timestamp.fromDate(applied),
      'nextDate': next == null ? null : Timestamp.fromDate(next),
      'notes': notes,
    });

    if (next != null) {
      try {
        final dogDoc = await _db.collection(dogCollection).doc(dogId).get();
        final dogName = dogDoc.data()?['name'] ??
            dogDoc.data()?['nombre'] ??
            'Perro del campus';
        final dateStr =
            '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
        await _db.collection('notificaciones').add({
          'userId': 'personal',
          'targetRole': 'personal',
          'type': 'proxima_vacuna',
          'dogId': dogId,
          'vaccineId': docRef.id,
          'title': 'Próxima vacunación: $dogName',
          'body': 'Refuerzo de $name programado para el $dateStr.',
          'nextDate': Timestamp.fromDate(next),
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  /// Elimina una vacuna específica de un perro.
  static Future<void> deleteVaccine(String dogId, String vaccineId) =>
      _db
          .collection('$dogCollection/$dogId/$vaccineCollection')
          .doc(vaccineId)
          .delete();

  /// Obtiene las vacunas con próxima fecha programada dentro de los próximos
  /// [withinDays] días (incluyendo las que vencen hoy) sin requerir índices
  /// compuestos especiales en Firestore.
  static Stream<List<UpcomingVaccineAlert>> upcomingVaccines(
      {int withinDays = 7}) {
    return _db.collection(dogCollection).snapshots().asyncMap((dogsSnap) async {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final limitDate = now.add(Duration(days: withinDays));
      final alerts = <UpcomingVaccineAlert>[];

      for (final dogDoc in dogsSnap.docs) {
        final dog = Dog.fromDoc(dogDoc);
        try {
          final vacSnap =
              await dogDoc.reference.collection(vaccineCollection).get();
          for (final vDoc in vacSnap.docs) {
            final v = Vaccine.fromDoc(vDoc);
            if (v.nextDate != null &&
                !v.nextDate!.isBefore(startOfToday) &&
                !v.nextDate!.isAfter(limitDate)) {
              alerts.add(
                UpcomingVaccineAlert(
                  dogId: dog.id,
                  dogName: dog.name.isNotEmpty ? dog.name : 'Perro',
                  vaccineId: v.id,
                  vaccineName: v.name,
                  nextDate: v.nextDate!,
                  notes: v.notes,
                ),
              );
            }
          }
        } catch (_) {}
      }

      alerts.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      return alerts;
    });
  }

  static Stream<List<Report>> reports({String? reporterId}) {
    Query q = _db.collection(reportCollection);
    if (reporterId != null) {
      // Avoid requiring a composite index for the common student view.
      q = q.where('reporterId', isEqualTo: reporterId);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }
    return q.snapshots().map((snapshot) {
      final reports = snapshot.docs.map(Report.fromDoc).toList();
      if (reporterId != null) {
        reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return reports;
    });
  }

  static Future<String> addReport(Map<String, dynamic> data) async {
    final docRef = await _db.collection(reportCollection).add({
      ...data,
      'status': 'pendiente',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Registra la notificación para el personal en Firestore
    try {
      final dogLabel = (data['dogName'] as String?)?.isNotEmpty == true
          ? data['dogName']
          : 'Perro sin identificar';
      final reporterName = (data['reporterName'] as String?)?.isNotEmpty == true
          ? data['reporterName']
          : 'Estudiante';
      final desc = (data['description'] ?? '').toString();
      await _db.collection('notificaciones').add({
        'userId': 'personal',
        'targetRole': 'personal',
        'type': 'nuevo_reporte',
        'reportId': docRef.id,
        'title': 'Nuevo reporte: $dogLabel',
        'body': '$reporterName reportó: "$desc"',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    return docRef.id;
  }

  static Future<void> updateDogBreedAnalysisFromReport(
    String dogId,
    String reportId,
    List<Map<String, dynamic>> breedAnalysis,
  ) =>
      _db.collection(dogCollection).doc(dogId).update({
        'breedAnalysis': breedAnalysis,
        'breedAnalyzedAt': FieldValue.serverTimestamp(),
        'breedSourceReportId': reportId,
      });

  static Future<void> updateReportStatus(String id, String status) async {
    await _db.collection(reportCollection).doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Registra la notificación de cambio de estado para el estudiante que reportó
    try {
      final reportDoc = await _db.collection(reportCollection).doc(id).get();
      final rData = reportDoc.data();
      if (rData != null) {
        final reporterId = (rData['reporterId'] ?? rData['usuarioId'])?.toString();
        final dogLabel = (rData['dogName'] ?? rData['perroNombre'])?.toString() ??
            'Perro sin identificar';
        final readableStatus = switch (status) {
          'en_revision' || 'en_atencion' => 'En revisión',
          'resuelto' => 'Resuelto',
          _ => 'Pendiente',
        };
        if (reporterId != null && reporterId.isNotEmpty) {
          await _db.collection('notificaciones').add({
            'userId': reporterId,
            'type': 'cambio_estado',
            'reportId': id,
            'title': 'Estado actualizado: $readableStatus',
            'body':
                'El reporte sobre $dogLabel cambió de estado a "$readableStatus".',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  static Future<void> updateReportDescription(String id, String description) =>
      _db
          .collection(reportCollection)
          .doc(id)
          .update({'description': description});

  static Future<void> updateReportStaffNote(String id, String note) =>
      _db.collection(reportCollection).doc(id).update({'staffNote': note});

  static Future<void> updateReportFull(String id, Map<String, dynamic> data) =>
      _db.collection(reportCollection).doc(id).update(data);

  static Future<void> deleteReport(String id) =>
      _db.collection(reportCollection).doc(id).delete();

  /// Identificación posterior de un perro reportado como no identificado.
  static Future<void> linkReportToDog(String reportId, Dog dog) => _db
      .collection(reportCollection)
      .doc(reportId)
      .update({'dogId': dog.id, 'dogName': dog.name});

  /// Contactos de emergencia y bienestar animal en el campus.
  static Stream<List<Contact>> contacts() {
    return _db.collection('contactos').snapshots().asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        return snap.docs.map(Contact.fromDoc).toList();
      }
      final altSnap = await _db.collection('contacts').get();
      if (altSnap.docs.isNotEmpty) {
        return altSnap.docs.map(Contact.fromDoc).toList();
      }
      return _defaultContacts;
    });
  }

  static final List<Contact> _defaultContacts = [
    Contact(
      id: 'c1',
      name: 'Seguridad Universitaria ESPOCH',
      role: 'Seguridad y Vigilancia Campus Central',
      phone: '032998200',
      email: 'seguridad@espoch.edu.ec',
      description:
          'Atención 24/7 para emergencias o perros en riesgo dentro del campus.',
    ),
    Contact(
      id: 'c2',
      name: 'Clínica Veterinaria Docente ESPOCH',
      role: 'Facultad de Ciencias Pecuarias',
      phone: '0991234567',
      email: 'clinica.veterinaria@espoch.edu.ec',
      description:
          'Atención médica canina, cirugías y vacunas para perros de la comunidad.',
    ),
    Contact(
      id: 'c3',
      name: 'Dirección de Bienestar Estudiantil',
      role: 'Bienestar Universitario y Voluntariado',
      phone: '0987654321',
      email: 'bienestar@espoch.edu.ec',
      description:
          'Coordinación del programa de protección animal y voluntariado PawTrack.',
    ),
    Contact(
      id: 'c4',
      name: 'Rescate Canino Politécnico',
      role: 'Colectivo Estudiantil de Rescate',
      phone: '0961122334',
      email: 'patitas.espoch@gmail.com',
      description:
          'Hogares temporales, alimentación y adopciones de perros comunitarios.',
    ),
  ];

  /// Notificaciones del usuario (en tiempo real desde 'notificaciones')
  static Stream<List<AppNotificationItem>> notifications(String userId,
      {bool isStaff = false}) {
    final targets = isStaff ? <String>[userId, 'personal'] : <String>[userId];
    return _db
        .collection('notificaciones')
        .where('userId', whereIn: targets)
        .snapshots()
        .asyncMap((snap) async {
      final byId = <String, AppNotificationItem>{};
      for (final doc in snap.docs) {
        byId[doc.id] = AppNotificationItem.fromDoc(doc);
      }
      try {
        final legacy = await _db
            .collection('notifications')
            .where('userId', whereIn: targets)
            .get();
        for (final doc in legacy.docs) {
          byId.putIfAbsent(doc.id, () => AppNotificationItem.fromDoc(doc));
        }
      } catch (_) {}
      final list = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
