import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

// ============================================================================
// SERVICIO DE DATOS (DataService)
// Centraliza todas las operaciones con Cloud Firestore y Firebase Storage
// para perros, historial médico, vacunas, reportes, contactos y notificaciones.
// ============================================================================
class DataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // --------------------------------------------------------------------------
  // SUBIDA DE IMÁGENES A FIREBASE STORAGE
  // Guarda una foto en la carpeta indicada y devuelve su URL pública
  // --------------------------------------------------------------------------
  static Future<String> uploadPhoto(Uint8List bytes, String folder) async {
    final ref =
        _storage.ref('$folder/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  // --------------------------------------------------------------------------
  // GESTIÓN DEL CATÁLOGO DE PERROS DEL CAMPUS
  // Consultas en tiempo real, creación, actualización y eliminación de perros
  // --------------------------------------------------------------------------
  static Stream<List<Dog>> dogs() => _db
      .collection('dogs')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Dog.fromDoc).toList());

  static Stream<Dog> dog(String id) =>
      _db.collection('dogs').doc(id).snapshots().map(Dog.fromDoc);

  static Future<String> addDog(Map<String, dynamic> data) async {
    final ref = await _db
        .collection('dogs')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  static Future<void> updateDog(String id, Map<String, dynamic> data) async {
    await _db.collection('dogs').doc(id).update(data);
  }

  // --------------------------------------------------------------------------
  // GESTIÓN DEL HISTORIAL MÉDICO DE CADA PERRO
  // Obtiene y añade registros clínicos en la subcolección 'medical_entries'
  // --------------------------------------------------------------------------
  static Stream<List<MedicalEntry>> medicalEntries(String dogId) => _db
      .collection('dogs/$dogId/medical_entries')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MedicalEntry.fromDoc).toList());

  static Future<void> addMedicalEntry(
          String dogId, Map<String, dynamic> data) =>
      _db.collection('dogs/$dogId/medical_entries').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // --------------------------------------------------------------------------
  // ELIMINACIÓN DE UN PERRO DEL CATÁLOGO
  // Borra la ficha del perro y sus subcolecciones médicas, pero conserva los
  // reportes antiguos manteniendo el nombre del perro como referencia histórica.
  // --------------------------------------------------------------------------
  static Future<void> deleteDog(Dog dog) async {
    final dogRef = _db.collection('dogs').doc(dog.id);
    final reports =
        await _db.collection('reports').where('dogId', isEqualTo: dog.id).get();
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

    for (final subcollection in ['vaccines', 'medical_entries']) {
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
        // Si la imagen no existe en Storage, no interrumpe el borrado de la ficha.
      }
    }
  }

  // --------------------------------------------------------------------------
  // GESTIÓN DE VACUNAS Y DESPARASITACIONES
  // Lee y registra dosis aplicadas en la subcolección 'vaccines' de cada perro
  // --------------------------------------------------------------------------
  static Stream<List<Vaccine>> vaccines(String dogId) => _db
      .collection('dogs/$dogId/vaccines')
      .orderBy('appliedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Vaccine.fromDoc).toList());

  static Future<void> addVaccine(String dogId, String name, DateTime applied,
          DateTime? next, String notes) =>
      _db.collection('dogs/$dogId/vaccines').add({
        'name': name,
        'appliedAt': Timestamp.fromDate(applied),
        'nextDate': next == null ? null : Timestamp.fromDate(next),
        'notes': notes,
      });

  // --------------------------------------------------------------------------
  // GESTIÓN DE REPORTES DE INCIDENCIAS CANINAS
  // Permite listar reportes (filtrados por estudiante o todos para el personal),
  // crear nuevos reportes, cambiar su estado, agregar notas y eliminarlos.
  // --------------------------------------------------------------------------
  static Stream<List<Report>> reports({String? reporterId}) {
    Query q = _db.collection('reports');
    if (reporterId != null) {
      // Filtra por el usuario que creó el reporte cuando es vista de estudiante
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
      _db.collection('reports').add({
        ...data,
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateReportStatus(String id, String status) =>
      _db.collection('reports').doc(id).update({'status': status});

  static Future<void> updateReportDescription(String id, String description) =>
      _db.collection('reports').doc(id).update({'description': description});

  static Future<void> updateReportStaffNote(String id, String note) =>
      _db.collection('reports').doc(id).update({'staffNote': note});

  static Future<void> updateReportFull(String id, Map<String, dynamic> data) =>
      _db.collection('reports').doc(id).update(data);

  static Future<void> deleteReport(String id) =>
      _db.collection('reports').doc(id).delete();

  // Vincula un reporte previamente "Sin identificar" con un perro del catálogo
  static Future<void> linkReportToDog(String reportId, Dog dog) => _db
      .collection('reports')
      .doc(reportId)
      .update({'dogId': dog.id, 'dogName': dog.name});

  // --------------------------------------------------------------------------
  // DIRECTORIO DE CONTACTOS DE EMERGENCIA DEL CAMPUS
  // Obtiene los contactos desde Firestore o muestra la lista oficial por defecto
  // --------------------------------------------------------------------------
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

  // Contactos predeterminados de bienestar animal y seguridad en la ESPOCH
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

  // --------------------------------------------------------------------------
  // CONSULTA DE NOTIFICACIONES DEL USUARIO
  // Escucha los avisos almacenados para el usuario actual en Firestore
  // --------------------------------------------------------------------------
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
