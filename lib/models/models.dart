import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid, name, email, role; // role: 'estudiante' | 'personal'
  AppUser(
      {required this.uid,
      required this.name,
      required this.email,
      required this.role});
  bool get isStaff => role == 'personal';

  factory AppUser.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return AppUser(
        uid: d.id,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        role: m['role'] ?? 'estudiante');
  }
}

class Dog {
  final String id, name, sex, color, description, photoUrl;
  final bool hasRedCollar;
  final DateTime createdAt;
  Dog({
    required this.id,
    required this.name,
    required this.sex,
    required this.color,
    required this.description,
    required this.photoUrl,
    required this.hasRedCollar,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) => other is Dog && other.id == id;
  @override
  int get hashCode => id.hashCode;

  factory Dog.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Dog(
      id: d.id,
      name: m['name'] ?? '',
      sex: m['sex'] ?? '',
      color: m['color'] ?? '',
      description: m['description'] ?? '',
      photoUrl: m['photoUrl'] ?? '',
      hasRedCollar: m['hasRedCollar'] ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Vaccine {
  final String id, name, notes;
  final DateTime appliedAt;
  final DateTime? nextDate;
  Vaccine(
      {required this.id,
      required this.name,
      required this.notes,
      required this.appliedAt,
      this.nextDate});

  factory Vaccine.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Vaccine(
      id: d.id,
      name: m['name'] ?? '',
      notes: m['notes'] ?? '',
      appliedAt: (m['appliedAt'] as Timestamp).toDate(),
      nextDate: (m['nextDate'] as Timestamp?)?.toDate(),
    );
  }
}

const reportStatuses = ['pendiente', 'en_atencion', 'resuelto'];

class Report {
  final String id,
      description,
      photoUrl,
      photoBase64,
      status,
      staffNote,
      reporterId,
      reporterName;
  final String? dogId, dogName;
  final bool dogDeleted;
  final double lat, lng;
  final DateTime createdAt;
  Report({
    required this.id,
    required this.description,
    required this.photoUrl,
    required this.photoBase64,
    required this.status,
    required this.staffNote,
    required this.reporterId,
    required this.reporterName,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.dogId,
    this.dogName,
    this.dogDeleted = false,
  });
  bool get unidentified => dogId == null && dogName == null;

  factory Report.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Report(
      id: d.id,
      description: m['description'] ?? '',
      photoUrl: m['photoUrl'] ?? '',
      photoBase64: m['photoBase64'] ?? '',
      status: m['status'] ?? 'pendiente',
      staffNote: m['staffNote'] ?? '',
      reporterId: m['reporterId'] ?? '',
      reporterName: m['reporterName'] ?? '',
      lat: (m['lat'] ?? 0).toDouble(),
      lng: (m['lng'] ?? 0).toDouble(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dogId: m['dogId'],
      dogName: m['dogName'],
      dogDeleted: m['dogDeleted'] ?? false,
    );
  }
}
