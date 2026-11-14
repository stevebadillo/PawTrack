import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// MODELO DE USUARIO (AppUser)
// Representa a la persona autenticada en PawTrack y su rol dentro del campus
// ('estudiante' o 'personal').
// ============================================================================
class AppUser {
  final String uid, name, email, role; // role: 'estudiante' | 'personal'
  AppUser(
      {required this.uid,
      required this.name,
      required this.email,
      required this.role});

  // Indica si el usuario pertenece al personal autorizado del campus
  bool get isStaff => role == 'personal';

  // Construye una instancia de AppUser a partir de un documento de Firestore
  factory AppUser.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return AppUser(
        uid: d.id,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        role: m['role'] ?? 'estudiante');
  }
}

// ============================================================================
// MODELO DE CAN COMUNITARIO (Dog)
// Almacena los datos de identificación, rasgos físicos y estado sanitario
// de cada perro registrado en el catálogo de la ESPOCH.
// ============================================================================
class Dog {
  final String id, name, sex, color, description, photoUrl;
  final bool hasRedCollar;
  final DateTime createdAt;
  final String age; // Edad aproximada en años
  final String allergies; // Alergias conocidas
  final bool isSterilized; // Estado de esterilización

  Dog({
    required this.id,
    required this.name,
    required this.sex,
    required this.color,
    required this.description,
    required this.photoUrl,
    required this.hasRedCollar,
    required this.createdAt,
    this.age = '3',
    this.allergies = 'Ninguna conocida',
    this.isSterilized = true,
  });

  // Comparación por ID para que funcione correctamente en selectores (Dropdown)
  @override
  bool operator ==(Object other) => other is Dog && other.id == id;
  @override
  int get hashCode => id.hashCode;

  // Convierte un documento de la colección 'dogs' de Firestore en un objeto Dog
  factory Dog.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Dog(
      id: d.id,
      name: m['name'] ?? m['nombre'] ?? '',
      sex: m['sex'] ?? m['sexo'] ?? 'Macho',
      color: m['color'] ?? '',
      description: m['description'] ?? m['descripcion'] ?? '',
      photoUrl: m['photoUrl'] ?? '',
      hasRedCollar: m['hasRedCollar'] ?? m['collarRojo'] ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      age: m['age']?.toString() ?? m['edad']?.toString() ?? '3',
      allergies: m['allergies'] ?? m['alergias'] ?? 'Ninguna conocida',
      isSterilized: m['isSterilized'] ?? m['esterilizado'] ?? false,
    );
  }
}

// ============================================================================
// MODELO DE ENTRADA MÉDICA (MedicalEntry)
// Representa una consulta, diagnóstico o tratamiento dentro del historial
// clínico de un perro.
// ============================================================================
class MedicalEntry {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String? vetOrClinic;
  final String? diagnosis;
  final String? treatment;
  final DateTime? nextVisit;
  final List<String> documents;

  MedicalEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.vetOrClinic,
    this.diagnosis,
    this.treatment,
    this.nextVisit,
    this.documents = const [],
  });

  // Construye una entrada médica desde la subcolección 'medical_entries'
  factory MedicalEntry.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return MedicalEntry(
      id: d.id,
      title: m['title'] ?? m['titulo'] ?? 'Revisión médica',
      description: m['description'] ?? m['descripcion'] ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ??
          (m['fecha'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      vetOrClinic: m['vetOrClinic'] ?? m['veterinario'],
      diagnosis: m['diagnosis'] ?? m['diagnostico'],
      treatment: m['treatment'] ?? m['tratamiento'],
      nextVisit: (m['nextVisit'] as Timestamp?)?.toDate(),
      documents: (m['documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// ============================================================================
// MODELO DE VACUNA (Vaccine)
// Registra una vacuna o desparasitación aplicada a un perro y su próxima dosis.
// ============================================================================
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

  // Construye un registro de vacuna desde la subcolección 'vaccines'
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

// Lista de estados posibles por los que pasa un reporte de incidencia
const reportStatuses = ['pendiente', 'en_revision', 'en_atencion', 'resuelto'];

// ============================================================================
// MODELO DE REPORTE DE INCIDENCIA (Report)
// Contiene toda la información de un reporte enviado en el campus: evidencia
// fotográfica, ubicación GPS, estado del perro, tipo de incidencia y notas.
// ============================================================================
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
  final List<String> photos; // Lista de fotos en base64 o URL

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

  // Verifica si el reporte corresponde a un perro aún no identificado
  bool get unidentified => dogId == null && dogName == null;

  // Convierte un documento de la colección 'reports' de Firestore en un Report
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

// ============================================================================
// MODELO DE CONTACTO DE EMERGENCIA (Contact)
// Representa una entidad o unidad de apoyo y rescate animal en la ESPOCH.
// ============================================================================
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

  // Construye un Contacto a partir de un documento de Firestore
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

// ============================================================================
// MODELO DE NOTIFICACIÓN (AppNotificationItem)
// Representa un aviso o alerta enviada al usuario sobre nuevos reportes,
// cambios de estado o próximas fechas de vacunación.
// ============================================================================
class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? reportId;
  final String? dogId;
  final String? vaccineId;
  final String type; // 'nuevo_reporte' | 'cambio_estado' | 'proxima_vacuna' | 'general'

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.reportId,
    this.dogId,
    this.vaccineId,
    this.type = 'general',
  });

  // Construye una notificación a partir de un documento de Firestore
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
      dogId: m['dogId'] ?? m['perroId'],
      vaccineId: m['vaccineId'] ?? m['vacunaId'],
      type: m['type'] ?? m['tipo'] ?? 'general',
    );
  }
}

// ============================================================================
// MODELO DE ALERTA DE PRÓXIMA VACUNACIÓN (UpcomingVaccineAlert)
// Combina la información del perro y la vacuna cuya próxima dosis está cercana.
// ============================================================================
class UpcomingVaccineAlert {
  final String dogId;
  final String dogName;
  final String vaccineId;
  final String vaccineName;
  final DateTime nextDate;
  final String notes;

  const UpcomingVaccineAlert({
    required this.dogId,
    required this.dogName,
    required this.vaccineId,
    required this.vaccineName,
    required this.nextDate,
    this.notes = '',
  });
}
