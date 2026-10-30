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

const reportStatuses = ['pendiente', 'en_revision', 'en_atencion', 'resuelto'];

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
  final String dogStatus; // 'con_vida', 'herido', 'sin_vida', 'no_se'
  final String incidentType; // 'perdido', 'agresivo', 'otro'
  final List<String> photos; // base64 or url list

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
    this.dogStatus = 'herido',
    this.incidentType = 'perdido',
    this.photos = const [],
  });

  bool get unidentified => dogId == null && dogName == null;

  factory Report.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    final rawPhotos = m['photos'] ?? m['evidencias'] ?? m['imagenes'];
    List<String> parsedPhotos = [];
    if (rawPhotos is List) {
      parsedPhotos = rawPhotos.map((e) => e.toString()).toList();
    } else if (m['photoBase64'] != null && (m['photoBase64'] as String).isNotEmpty) {
      parsedPhotos = [m['photoBase64'] as String];
    } else if (m['photoUrl'] != null && (m['photoUrl'] as String).isNotEmpty) {
      parsedPhotos = [m['photoUrl'] as String];
    }

    return Report(
      id: d.id,
      description: m['description'] ?? m['descripcion'] ?? '',
      photoUrl: m['photoUrl'] ?? '',
      photoBase64: m['photoBase64'] ?? '',
      status: m['status'] ?? m['estado'] ?? 'pendiente',
      staffNote: m['staffNote'] ?? m['notaPersonal'] ?? '',
      reporterId: m['reporterId'] ?? m['usuarioId'] ?? '',
      reporterName: m['reporterName'] ?? m['usuarioNombre'] ?? '',
      lat: (m['lat'] ?? m['latitud'] ?? 0).toDouble(),
      lng: (m['lng'] ?? m['longitud'] ?? 0).toDouble(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ??
          (m['fecha'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      dogId: m['dogId'] ?? m['perroId'],
      dogName: m['dogName'] ?? m['perroNombre'],
      dogDeleted: m['dogDeleted'] ?? false,
      dogStatus: m['dogStatus'] ?? m['estadoPerro'] ?? 'herido',
      incidentType: m['incidentType'] ?? m['tipoIncidencia'] ?? m['tipo'] ?? 'perdido',
      photos: parsedPhotos,
    );
  }
}

class Contact {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String email;
  final String description;

  Contact({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.email = '',
    this.description = '',
  });

  factory Contact.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return Contact(
      id: d.id,
      name: m['name'] ?? m['nombre'] ?? '',
      role: m['role'] ?? m['cargo'] ?? m['departamento'] ?? 'Contacto ESPOCH',
      phone: m['phone'] ?? m['telefono'] ?? m['celular'] ?? '',
      email: m['email'] ?? m['correo'] ?? '',
      description: m['description'] ?? m['descripcion'] ?? '',
    );
  }
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? reportId;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.reportId,
  });

  factory AppNotificationItem.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return AppNotificationItem(
      id: d.id,
      title: m['title'] ?? m['titulo'] ?? 'Notificación',
      body: m['body'] ?? m['mensaje'] ?? m['descripcion'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ??
          (m['fecha'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      isRead: m['isRead'] ?? m['leido'] ?? false,
      reportId: m['reportId'] ?? m['reporteId'],
    );
  }
}
