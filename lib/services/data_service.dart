import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Firestore para datos y reportes; Firebase Storage para fotos de perros.
class DataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // Nombres de colecciones de PawTrack (un solo lugar para cambiarlos).
  // Deben coincidir con los de firestore.rules.
  static const dogCollection = 'canes';
  static const medicalCollection = 'registros_medicos';
  static const vaccineCollection = 'vacunas';
  static const reportCollection = 'reportes';

  static Future<String> uploadPhoto(
    Uint8List bytes,
    String folder, {
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('La imagen está vacía.');
    if (bytes.length >= 5 * 1024 * 1024) {
      throw ArgumentError('La imagen debe pesar menos de 5 MB.');
    }
    final ref =
        _storage.ref('$folder/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final progressSubscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      try {
        await task.timeout(const Duration(seconds: 90));
      } on TimeoutException {
        await task.cancel();
        throw TimeoutException(
          'La carga tardó demasiado. Revisa Firebase Storage y la conexión.',
        );
      }
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } finally {
      await progressSubscription.cancel();
    }
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
          DateTime? next, String notes) =>
      _db.collection('$dogCollection/$dogId/$vaccineCollection').add({
        'name': name,
        'appliedAt': Timestamp.fromDate(applied),
        'nextDate': next == null ? null : Timestamp.fromDate(next),
        'notes': notes,
      });

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

  static Future<void> addReport(Map<String, dynamic> data) =>
      _db.collection(reportCollection).add({
        ...data,
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateReportStatus(String id, String status) =>
      _db.collection(reportCollection).doc(id).update({'status': status});

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

  /// Notificaciones del usuario
  static Stream<List<AppNotificationItem>> notifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map(AppNotificationItem.fromDoc).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      final alt = await _db
          .collection('notificaciones')
          .where('userId', isEqualTo: userId)
          .get();
      if (alt.docs.isNotEmpty) {
        final list = alt.docs.map(AppNotificationItem.fromDoc).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return <AppNotificationItem>[];
    });
  }
}