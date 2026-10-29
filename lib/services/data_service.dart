import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Firestore para datos y reportes; Firebase Storage para fotos de perros.
class DataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<String> uploadPhoto(Uint8List bytes, String folder) async {
    final ref =
        _storage.ref('$folder/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

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

  /// Removes a dog and its vaccine subcollection while preserving old reports.
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

    final vaccines = await dogRef.collection('vaccines').get();
    for (var start = 0; start < vaccines.docs.length; start += 450) {
      final batch = _db.batch();
      for (final vaccine in vaccines.docs.skip(start).take(450)) {
        batch.delete(vaccine.reference);
      }
      await batch.commit();
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

  static Stream<List<Report>> reports({String? reporterId}) {
    Query q = _db.collection('reports');
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

  static Future<void> deleteReport(String id) =>
      _db.collection('reports').doc(id).delete();

  /// Identificación posterior de un perro reportado como no identificado.
  static Future<void> linkReportToDog(String reportId, Dog dog) => _db
      .collection('reports')
      .doc(reportId)
      .update({'dogId': dog.id, 'dogName': dog.name});
}
