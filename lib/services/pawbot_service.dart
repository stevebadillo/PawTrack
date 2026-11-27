import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'data_service.dart';

// ============================================================================
// MODELO DE MENSAJE DEL CHATBOT (PawBotMessage)
// Representa cada intervención en la conversación entre el usuario y PawBot,
// indicando el origen de la información (Firestore vs. Conocimiento General).
// ============================================================================
class PawBotMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? sourceLabel; // 'Cloud Firestore' | 'Orientación General' | null
  final bool isError;

  PawBotMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.sourceLabel,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================================
// SERVICIO INTELIGENTE DE PAWBOT (PawBotService)
// Implementa la arquitectura de consulta controlada a Cloud Firestore con
// validación de autenticación y roles (Estudiante / Personal), combinada con
// generación de lenguaje natural mediante API REST (Gemini Developer API via
// variable de entorno sin claves privadas en código + endpoint IA gratuito
// + motor determinístico local sin límites).
// ============================================================================
class PawBotService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

  // Clave opcional de Gemini inyectada por entorno (--dart-define=GEMINI_API_KEY=...)
  // Cumple la restricción de seguridad de NO exponer claves privadas en el código fuente.
  static const String _geminiEnvKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Endpoint REST gratuito de IA generativa (sin clave privada en cliente)
  static const String _freeAiEndpoint = 'https://text.pollinations.ai/openai';

  // --------------------------------------------------------------------------
  // PUNTO DE ENTRADA PRINCIPAL PARA PROCESAR UNA PREGUNTA DEL USUARIO
  // Siga los 10 pasos de la arquitectura definida:
  // 1-5: Verifica sesión en Firebase Auth y permisos según el rol (AppUser).
  // 6-7: Determina la intención (Function Calling) y consulta Firestore.
  // 8-10: Genera la respuesta fundamentada en los datos reales sin inventar.
  // --------------------------------------------------------------------------
  static Future<PawBotMessage> ask({
    required String question,
    required AppUser user,
    List<PawBotMessage> history = const [],
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) {
      return PawBotMessage(
        text: 'Por favor escribe una pregunta para poder ayudarte.',
        isUser: false,
      );
    }

    // Paso 4 y 5: Verificación obligatoria de identidad en Firebase Auth
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != user.uid) {
      return PawBotMessage(
        text:
            'Tu sesión no está activa o no pudo verificarse. Por favor vuelve a iniciar sesión para realizar consultas.',
        isUser: false,
        isError: true,
      );
    }

    final qLower = _normalize(cleanQuestion);

    // Regla 1: Verificar si la pregunta está fuera del alcance de PawTrack / cuidado canino
    if (_isOutOfScope(qLower)) {
      return PawBotMessage(
        text:
            'Soy **PawBot**, el asistente virtual de **Paw Track ESPOCH** 🐾.\n\n'
            'Solo puedo responder consultas relacionadas con:\n'
            '• Caninos registrados en el campus ESPOCH\n'
            '• Historial de vacunación y próximas dosis\n'
            '• Registros e historial médico veterinario\n'
            '• Reportes de incidencias en el campus\n'
            '• Cuidado general, bienestar canino y uso de la app Paw Track.',
        isUser: false,
        sourceLabel: 'Regla de alcance PawBot',
      );
    }

    try {
      // Paso 6 y 7: Identificar qué función controlada de Firestore ejecutar
      final intent = _detectIntent(qLower);

      if (intent == _PawBotIntent.firestoreDogs ||
          intent == _PawBotIntent.firestoreVaccines ||
          intent == _PawBotIntent.firestoreMedical ||
          intent == _PawBotIntent.firestoreReports ||
          intent == _PawBotIntent.firestoreContacts ||
          intent == _PawBotIntent.firestoreFullSummary) {
        final firestoreResponse = await _executeFirestoreFunction(
          intent: intent,
          qLower: qLower,
          originalQuestion: cleanQuestion,
          user: user,
        );
        return PawBotMessage(
          text: firestoreResponse,
          isUser: false,
          sourceLabel: 'Datos reales de Cloud Firestore',
        );
      }

      // Si el usuario menciona el nombre de algún perro registrado en Firestore
      // (incluso por voz), priorizamos buscar en la base de datos según lo que pida.
      final matchedDog = await _findDogMentionedInQuestion(qLower);
      if (matchedDog != null) {
        if (_containsAny(qLower, ['vacuna', 'vacunas', 'dosis', 'refuerzo'])) {
          return PawBotMessage(
            text: await _consultarVacunasFirestore(_normalize(matchedDog.name)),
            isUser: false,
            sourceLabel: 'Datos reales de Cloud Firestore',
          );
        }
        if (_containsAny(qLower, ['medico', 'historial', 'tratamiento', 'diagnostico', 'cita'])) {
          return PawBotMessage(
            text: await _consultarHistorialMedicoFirestore(_normalize(matchedDog.name)),
            isUser: false,
            sourceLabel: 'Datos reales de Cloud Firestore',
          );
        }
        final dogSummary = await _buildCompleteDogFicha(matchedDog, user: user);
        return PawBotMessage(
          text: dogSummary,
          isUser: false,
          sourceLabel: 'Datos reales de Cloud Firestore',
        );
      }

      // Paso 8 y 9: Consulta de orientación sobre cuidado canino o ayuda de PawTrack
      final answer = await _answerGeneralOrAppQuestion(
        cleanQuestion: cleanQuestion,
        qLower: qLower,
        user: user,
        history: history,
      );

      return PawBotMessage(
        text: answer,
        isUser: false,
        sourceLabel: 'Orientación general · IA PawBot',
      );
    } catch (e) {
      return PawBotMessage(
        text:
            'Ocurrió un inconveniente al consultar la información. Verifica tu conexión a internet e inténtalo nuevamente.',
        isUser: false,
        isError: true,
      );
    }
  }

  // --------------------------------------------------------------------------
  // DETECCIÓN DE INTENCIÓN (FUNCTION CALLING ROUTER)
  // Determina si la pregunta requiere consultar 'canes', 'vacunas',
  // 'registros_medicos', 'reportes', 'contactos' o conocimientos generales.
  // --------------------------------------------------------------------------
  static _PawBotIntent _detectIntent(String q) {
    // 1. Consultas sobre vacunas
    if (_containsAny(q, [
      'vacuna',
      'vacunas',
      'vacunacion',
      'dosis',
      'refuerzo',
      'rabia',
      'parvovirus',
      'moquillo',
      'sextuple',
      'polivalente',
      'desparasitacion',
      'carnet',
      'pendiente de vacuna',
      'proximas vacunas',
      'proxima vacuna',
    ])) {
      // Si pregunta cómo registrar una vacuna en la app
      if (_containsAny(q, ['como registro', 'como registrar', 'donde registro', 'pasos para'])) {
        return _PawBotIntent.appHelp;
      }
      // Si es una pregunta puramente educativa general sobre cachorros/perros en general
      if (_containsAny(q, ['que vacunas necesita un cachorro', 'calendario general', 'cada cuanto se vacuna un perro']) &&
          !_containsAny(q, ['registrad', 'campus', 'tiene', 'perros de', 'pendiente', 'proxima'])) {
        return _PawBotIntent.generalCare;
      }
      return _PawBotIntent.firestoreVaccines;
    }

    // 2. Consultas sobre historial médico
    if (_containsAny(q, [
      'historial medico',
      'registro medico',
      'registros medicos',
      'consulta medica',
      'atencion veterinaria',
      'atenciones',
      'diagnostico',
      'tratamiento',
      'proxima cita',
      'proxima visita',
      'ultimo registro medico',
      'ficha medica',
      'enfermo',
      'operado',
      'cirugia',
    ])) {
      if (_containsAny(q, ['como registrar', 'como consulto', 'donde veo'])) {
        return _PawBotIntent.appHelp;
      }
      return _PawBotIntent.firestoreMedical;
    }

    // 3. Consultas sobre incidencias / reportes
    if (_containsAny(q, [
      'incidencia',
      'incidencias',
      'reporte',
      'reportes',
      'pendiente',
      'pendientes',
      'en revision',
      'resuelto',
      'resueltos',
      'reportado',
      'reportados',
      'ultimos reportes',
      'reportes de hoy',
    ])) {
      if (_containsAny(q, [
        'como puedo reportar',
        'como reportar',
        'como hago un reporte',
        'como crear un reporte',
        'como envio un reporte',
        'pasos para reportar',
      ])) {
        return _PawBotIntent.appHelp;
      }
      return _PawBotIntent.firestoreReports;
    }

    // 4. Consultas sobre contactos de emergencia
    if (_containsAny(q, [
      'contacto',
      'contactos',
      'telefono',
      'llamar',
      'emergencia',
      'seguridad universitaria',
      'clinica veterinaria',
      'bienestar estudiantil',
      'numero de',
    ])) {
      return _PawBotIntent.firestoreContacts;
    }

    // 5. Consultas sobre los caninos registrados en el campus (flexible para voz y texto)
    final mentionsDogs = _containsAny(q, [
      'canino',
      'caninos',
      'perro',
      'perros',
      'perrito',
      'perritos',
      'can',
      'canes',
    ]);
    final asksCatalogOrCount = _containsAny(q, [
      'cuanto',
      'cuantos',
      'registrad',
      'lista',
      'cuales',
      'que perros',
      'que caninos',
      'hay en',
      'campus',
      'espoch',
      'catalogo',
      'todos los',
      'mostrar',
      'dime los',
      'ver los',
      'collar rojo',
      'esterilizad',
      'alergia',
      'edad',
      'nombres',
      'informacion',
    ]);
    if ((mentionsDogs && asksCatalogOrCount) ||
        _containsAny(q, [
          'cuantos caninos',
          'cuantos perros',
          'caninos registrados',
          'perros registrados',
          'collar rojo',
        ])) {
      return _PawBotIntent.firestoreDogs;
    }

    // 6. Ayuda sobre el funcionamiento de la app Paw Track
    if (_containsAny(q, [
      'como funciona paw',
      'como usar',
      'como puedo',
      'donde puedo',
      'para que sirve paw',
      'que es pawtrack',
      'que es paw track',
      'navegar',
      'menu',
      'pestana',
      'registrar un canino',
      'registrar un perro',
      'notificaciones',
      'mapa',
    ])) {
      return _PawBotIntent.appHelp;
    }

    return _PawBotIntent.generalCare;
  }

  // --------------------------------------------------------------------------
  // EJECUCIÓN DE FUNCIONES CONTROLADAS SOBRE CLOUD FIRESTORE
  // Respeta los permisos del usuario autenticado y nunca inventa datos.
  // --------------------------------------------------------------------------
  static Future<String> _executeFirestoreFunction({
    required _PawBotIntent intent,
    required String qLower,
    required String originalQuestion,
    required AppUser user,
  }) async {
    switch (intent) {
      case _PawBotIntent.firestoreDogs:
        return _consultarCaninosFirestore(qLower);
      case _PawBotIntent.firestoreVaccines:
        return _consultarVacunasFirestore(qLower);
      case _PawBotIntent.firestoreMedical:
        return _consultarHistorialMedicoFirestore(qLower);
      case _PawBotIntent.firestoreReports:
        return _consultarIncidenciasFirestore(qLower, user: user);
      case _PawBotIntent.firestoreContacts:
        return _consultarContactosFirestore();
      default:
        return _consultarCaninosFirestore(qLower);
    }
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN A: CONSULTA DE INFORMACIÓN DE LOS CANINOS ('canes')
  // --------------------------------------------------------------------------
  static Future<String> _consultarCaninosFirestore(String qLower) async {
    final snap = await _db.collection(DataService.dogCollection).orderBy('name').get();
    if (snap.docs.isEmpty) {
      return '📋 **Consulta en Cloud Firestore:**\n\n'
          'Actualmente no existen caninos registrados en la colección `canes` de la base de datos.';
    }

    final dogs = snap.docs.map(Dog.fromDoc).toList();

    // Verificar si pregunta por un canino específico (soporta voz y texto)
    for (final d in dogs) {
      if (_matchesDogName(qLower, d.name)) {
        return _formatSingleDogInfo(d);
      }
    }

    // Filtro especial si pregunta por el significado o caninos con collar rojo
    if (qLower.contains('collar rojo')) {
      final redCollarDogs = dogs.where((d) => d.hasRedCollar).toList();
      final dogsListText = redCollarDogs.isEmpty
          ? 'Actualmente ninguno de los **${dogs.length}** caninos registrados figura con collar rojo en la base de datos.'
          : 'Caninos registrados que portan collar rojo (**${redCollarDogs.length} de ${dogs.length}**):\n'
              '${redCollarDogs.map((d) => '• **${d.name}** (${d.sex}, ${d.color}, ${d.age} años)').join('\n')}';

      return '🔴 **¿Qué significa el collar rojo?**\n\n'
          'El **collar rojo** es un **identificativo** que llevan los caninos comunitarios y contiene:\n'
          '• **El nombre del perro**\n'
          '• **El nombre de la universidad (ESPOCH)**\n'
          '• **Un número de emergencia**\n\n'
          '📋 **Registro en Cloud Firestore:**\n$dogsListText';
    }

    // Listado general y conteo de caninos registrados
    final buffer = StringBuffer();
    buffer.writeln(
        '📋 **Caninos registrados en Cloud Firestore:**\n'
        'Actualmente hay **${dogs.length} canino(s)** registrados en Paw Track ESPOCH:\n');

    for (final d in dogs) {
      final collar = d.hasRedCollar ? '🔴 Con collar rojo identificativo' : '⚪ Sin collar rojo';
      final esteril = d.isSterilized ? 'Esterilizado/a' : 'No esterilizado/a';
      buffer.writeln(
          '• **${d.name}** — ${d.sex} · Color: ${d.color} · Edad: ${d.age} año(s)\n'
          '  Estado: $collar · $esteril · Alergias: ${d.allergies}');
      if (d.description.isNotEmpty) {
        buffer.writeln('  Rasgos: *${d.description}*');
      }
    }

    buffer.writeln(
        '\nPuedes preguntarme por cualquiera de ellos (por ejemplo: *"¿Qué vacunas tiene ${dogs.first.name}?"* o *"Historial médico de ${dogs.first.name}"*).');
    return buffer.toString().trim();
  }

  static String _formatSingleDogInfo(Dog d) {
    final collar = d.hasRedCollar ? 'Sí (identificativo del campus ESPOCH)' : 'No';
    final esteril = d.isSterilized ? 'Sí' : 'No';
    return '📋 **Ficha del canino en Cloud Firestore:**\n\n'
        '• **Nombre:** ${d.name}\n'
        '• **ID de registro:** `${d.id}`\n'
        '• **Sexo:** ${d.sex}\n'
        '• **Edad aproximada:** ${d.age} año(s)\n'
        '• **Color / Pelaje:** ${d.color}\n'
        '• **Collar rojo:** $collar\n'
        '• **Esterilizado/a:** $esteril\n'
        '• **Alergias conocidas:** ${d.allergies}\n'
        '• **Descripción:** ${d.description.isNotEmpty ? d.description : "Sin descripción adicional"}';
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN B: CONSULTA DE VACUNACIÓN ('canes/{dogId}/vacunas')
  // --------------------------------------------------------------------------
  static Future<String> _consultarVacunasFirestore(String qLower) async {
    final dogsSnap =
        await _db.collection(DataService.dogCollection).orderBy('name').get();
    if (dogsSnap.docs.isEmpty) {
      return '📋 **Datos de Cloud Firestore:**\n\n'
          'No existen caninos registrados en la base de datos para consultar vacunas.';
    }

    final dogs = dogsSnap.docs.map(Dog.fromDoc).toList();
    Dog? targetDog;
    for (final d in dogs) {
      if (_matchesDogName(qLower, d.name)) {
        targetDog = d;
        break;
      }
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Si pregunta por un canino específico
    if (targetDog != null) {
      final vacSnap = await _db
          .collection(
              '${DataService.dogCollection}/${targetDog.id}/${DataService.vaccineCollection}')
          .orderBy('appliedAt', descending: true)
          .get();

      if (vacSnap.docs.isEmpty) {
        return '📋 **Datos de Cloud Firestore:**\n\n'
            'El canino **${targetDog.name}** no tiene vacunas registradas actualmente en su historial.';
      }

      final vaccines = vacSnap.docs.map(Vaccine.fromDoc).toList();
      final buffer = StringBuffer();
      buffer.writeln(
          '📋 **Historial de vacunación de ${targetDog.name} (${vaccines.length} registro(s)):**\n');

      for (final v in vaccines) {
        final appliedStr = _dateFmt.format(v.appliedAt);
        String nextStr = 'Sin próxima dosis programada';
        if (v.nextDate != null) {
          final isPendingOrOverdue = v.nextDate!.isBefore(startOfToday);
          final isUpcoming = !isPendingOrOverdue &&
              v.nextDate!.difference(startOfToday).inDays <= 7;
          final badge = isPendingOrOverdue
              ? '⚠️ (Dosis vencida/pendiente)'
              : (isUpcoming ? '🔔 (Próxima en menos de 7 días)' : '📅 (Programada)');
          nextStr = '${_dateFmt.format(v.nextDate!)} $badge';
        }
        buffer.writeln('• **${v.name}**\n'
            '  Aplicada: $appliedStr · Próxima fecha: $nextStr');
        if (v.notes.isNotEmpty) {
          buffer.writeln('  Notas: *${v.notes}*');
        }
      }
      return buffer.toString().trim();
    }

    // Consulta general de vacunación de todos los caninos
    final buffer = StringBuffer();
    int totalVaccines = 0;
    final List<String> upcomingOrPending = [];
    final List<String> dogsWithoutVaccines = [];

    for (final d in dogs) {
      final vacSnap = await _db
          .collection(
              '${DataService.dogCollection}/${d.id}/${DataService.vaccineCollection}')
          .orderBy('appliedAt', descending: true)
          .get();
      if (vacSnap.docs.isEmpty) {
        dogsWithoutVaccines.add(d.name);
        continue;
      }

      final vacs = vacSnap.docs.map(Vaccine.fromDoc).toList();
      totalVaccines += vacs.length;

      final resumenVacunas = vacs.map((v) {
        final nextInfo = v.nextDate != null
            ? ' (próxima: ${_dateFmt.format(v.nextDate!)})'
            : '';
        return '${v.name} [${_dateFmt.format(v.appliedAt)}$nextInfo]';
      }).join(', ');

      buffer.writeln('• **${d.name}:** $resumenVacunas');

      for (final v in vacs) {
        if (v.nextDate != null) {
          final days = v.nextDate!.difference(startOfToday).inDays;
          if (days < 0) {
            upcomingOrPending.add(
                '⚠️ **${d.name}** — ${v.name}: dosis pendiente desde el ${_dateFmt.format(v.nextDate!)}');
          } else if (days <= 30) {
            upcomingOrPending.add(
                '📅 **${d.name}** — ${v.name}: próxima dosis el ${_dateFmt.format(v.nextDate!)}');
          }
        }
      }
    }

    final result = StringBuffer();
    result.writeln(
        '📋 **Resumen de Vacunación en Cloud Firestore ($totalVaccines vacuna(s) registradas):**\n');
    if (totalVaccines > 0) {
      result.writeln(buffer.toString().trim());
    } else {
      result.writeln('No hay vacunas registradas todavía en la base de datos.');
    }

    if (upcomingOrPending.isNotEmpty) {
      result.writeln('\n🔔 **Próximas fechas o refuerzos pendientes:**');
      for (final item in upcomingOrPending) {
        result.writeln('• $item');
      }
    }

    if (dogsWithoutVaccines.isNotEmpty) {
      result.writeln(
          '\n📌 **Caninos sin vacunas registradas aún:** ${dogsWithoutVaccines.join(", ")}.');
    }

    return result.toString().trim();
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN C: CONSULTA DEL HISTORIAL MÉDICO ('canes/{dogId}/registros_medicos')
  // --------------------------------------------------------------------------
  static Future<String> _consultarHistorialMedicoFirestore(String qLower) async {
    final dogsSnap =
        await _db.collection(DataService.dogCollection).orderBy('name').get();
    if (dogsSnap.docs.isEmpty) {
      return '📋 **Datos de Cloud Firestore:**\n\n'
          'No existen caninos registrados en la base de datos para consultar su historial médico.';
    }

    final dogs = dogsSnap.docs.map(Dog.fromDoc).toList();
    Dog? targetDog;
    for (final d in dogs) {
      if (_matchesDogName(qLower, d.name)) {
        targetDog = d;
        break;
      }
    }

    if (targetDog != null) {
      final medSnap = await _db
          .collection(
              '${DataService.dogCollection}/${targetDog.id}/${DataService.medicalCollection}')
          .orderBy('date', descending: true)
          .get();

      if (medSnap.docs.isEmpty) {
        return '📋 **Datos de Cloud Firestore:**\n\n'
            'El canino **${targetDog.name}** no posee registros médicos almacenados hasta el momento.';
      }

      final entries = medSnap.docs.map(MedicalEntry.fromDoc).toList();
      final buffer = StringBuffer();
      buffer.writeln(
          '📋 **Historial médico de ${targetDog.name} (${entries.length} atención(es)):**\n');

      for (final e in entries) {
        buffer.writeln('• **${e.title}** (${_dateFmt.format(e.date)})');
        if (e.vetOrClinic != null && e.vetOrClinic!.isNotEmpty) {
          buffer.writeln('  Veterinario/Clínica: ${e.vetOrClinic}');
        }
        if (e.diagnosis != null && e.diagnosis!.isNotEmpty) {
          buffer.writeln('  Diagnóstico: ${e.diagnosis}');
        }
        if (e.treatment != null && e.treatment!.isNotEmpty) {
          buffer.writeln('  Tratamiento: ${e.treatment}');
        }
        if (e.description.isNotEmpty) {
          buffer.writeln('  Observaciones: *${e.description}*');
        }
        if (e.nextVisit != null) {
          buffer.writeln(
              '  📅 Próxima revisión: ${_dateTimeFmt.format(e.nextVisit!)}');
        }
      }
      return buffer.toString().trim();
    }

    // Resumen médico de todos los caninos
    final buffer = StringBuffer();
    int totalEntries = 0;

    for (final d in dogs) {
      final medSnap = await _db
          .collection(
              '${DataService.dogCollection}/${d.id}/${DataService.medicalCollection}')
          .orderBy('date', descending: true)
          .get();
      if (medSnap.docs.isEmpty) continue;

      final entries = medSnap.docs.map(MedicalEntry.fromDoc).toList();
      totalEntries += entries.length;
      final latest = entries.first;
      final diag = (latest.diagnosis != null && latest.diagnosis!.isNotEmpty)
          ? ' · Diagnóstico: ${latest.diagnosis}'
          : '';
      final treat = (latest.treatment != null && latest.treatment!.isNotEmpty)
          ? ' · Tratamiento: ${latest.treatment}'
          : '';
      buffer.writeln(
          '• **${d.name}** (${entries.length} registro(s)) — Última atención: *${latest.title}* el ${_dateFmt.format(latest.date)}$diag$treat');
    }

    if (totalEntries == 0) {
      return '📋 **Datos de Cloud Firestore:**\n\n'
          'Actualmente no existen registros médicos almacenados en ninguno de los caninos registrados.';
    }

    return '📋 **Historial Médico en Cloud Firestore ($totalEntries registro(s) en total):**\n\n'
        '${buffer.toString().trim()}\n\n'
        'Puedes consultar el detalle de un canino específico escribiendo por ejemplo: *"Historial médico de ${dogs.first.name}"*.';
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN D: CONSULTA DE INCIDENCIAS ('reportes') CON CONTROL DE PERMISOS
  // - Personal ('personal'): consulta todos los reportes del campus.
  // - Estudiante ('estudiante'): consulta únicamente los reportes que le
  //   corresponden según firestore.rules (reporterId == user.uid).
  // --------------------------------------------------------------------------
  static Future<String> _consultarIncidenciasFirestore(
    String qLower, {
    required AppUser user,
  }) async {
    Query query = _db.collection(DataService.reportCollection);
    if (!user.isStaff) {
      // Cumple la regla de seguridad de Firestore: los estudiantes solo acceden
      // a sus propios reportes registrados.
      query = query.where('reporterId', isEqualTo: user.uid);
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) {
      return user.isStaff
          ? '📋 **Datos de Cloud Firestore:**\n\nNo existen incidencias registradas en el campus actualmente.'
          : '📋 **Datos de Cloud Firestore:**\n\nNo tienes reportes de incidencias registrados con tu cuenta actualmente. Puedes crear uno desde el botón **"Crear reporte"** en la pantalla de Inicio.';
    }

    final reports = snap.docs.map(Report.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filtrar si pregunta específicamente por pendientes, en revisión o resueltos
    final bool onlyPending =
        qLower.contains('pendiente') || qLower.contains('sin atender');
    final bool onlyInReview =
        qLower.contains('en revision') || qLower.contains('en atencion');
    final bool onlyResolved =
        qLower.contains('resuelto') || qLower.contains('atendido');

    List<Report> filtered = reports;
    String filterTitle = user.isStaff
        ? 'Incidencias registradas en el campus'
        : 'Tus reportes de incidencias registrados';

    if (onlyPending) {
      filtered = reports.where((r) => r.status == 'pendiente').toList();
      filterTitle = 'Incidencias pendientes de atención';
    } else if (onlyInReview) {
      filtered = reports
          .where((r) => r.status == 'en_revision' || r.status == 'en_atencion')
          .toList();
      filterTitle = 'Incidencias en revisión';
    } else if (onlyResolved) {
      filtered = reports.where((r) => r.status == 'resuelto').toList();
      filterTitle = 'Incidencias resueltas';
    }

    // Filtro por fecha si pregunta "hoy"
    if (qLower.contains('hoy')) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      filtered =
          filtered.where((r) => !r.createdAt.isBefore(startOfToday)).toList();
      filterTitle = '$filterTitle (Hoy)';
    }

    final pendingCount = reports.where((r) => r.status == 'pendiente').length;
    final reviewCount = reports
        .where((r) => r.status == 'en_revision' || r.status == 'en_atencion')
        .length;
    final resolvedCount = reports.where((r) => r.status == 'resuelto').length;

    if (filtered.isEmpty) {
      return '📋 **Datos de Cloud Firestore ($filterTitle):**\n\n'
          'No se encontraron reportes con ese filtro.\n'
          'Resumen total disponible: **${reports.length}** reporte(s) '
          '($pendingCount pendiente(s), $reviewCount en revisión, $resolvedCount resuelto(s)).';
    }

    final buffer = StringBuffer();
    buffer.writeln(
        '📋 **$filterTitle (${filtered.length} registro(s)):**\n'
        'Resumen general: 🔴 $pendingCount pendiente(s) · 🟠 $reviewCount en revisión · 🟢 $resolvedCount resuelto(s)\n');

    for (final r in filtered.take(8)) {
      final dogLabel = r.unidentified
          ? 'Canino sin identificar'
          : (r.dogName ?? 'Canino');
      final statusReadable = switch (r.status) {
        'en_revision' || 'en_atencion' => '🟠 En revisión',
        'resuelto' => '🟢 Resuelto',
        _ => '🔴 Pendiente',
      };
      buffer.writeln(
          '• **$dogLabel** — $statusReadable (${_dateTimeFmt.format(r.createdAt)})\n'
          '  Tipo: ${r.incidentType} · Estado del can: ${r.dogStatus.replaceAll('_', ' ')}\n'
          '  Descripción: *"${r.description}"*');
      if (r.staffNote.isNotEmpty) {
        buffer.writeln('  Observación del personal: *${r.staffNote}*');
      }
    }

    if (filtered.length > 8) {
      buffer.writeln(
          '\n*(Mostrando los 8 reportes más recientes de ${filtered.length} en total).*');
    }

    return buffer.toString().trim();
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN E: CONSULTA DE CONTACTOS DE EMERGENCIA ('contactos')
  // --------------------------------------------------------------------------
  static Future<String> _consultarContactosFirestore() async {
    final contacts = await DataService.contacts().first;
    final buffer = StringBuffer();
    buffer.writeln(
        '📋 **Contactos de Emergencia y Bienestar Animal ESPOCH:**\n');
    for (final c in contacts) {
      buffer.writeln('• **${c.name}** (${c.role})\n'
          '  📞 Teléfono: `${c.phone}`'
          '${c.email.isNotEmpty ? ' · ✉️ ${c.email}' : ''}\n'
          '  *${c.description}*');
    }
    return buffer.toString().trim();
  }

  // --------------------------------------------------------------------------
  // BÚSQUEDA DE UN CANINO ESPECÍFICO MENCIONADO EN LA PREGUNTA (TEXTO O VOZ)
  // Soporta coincidencias exactas y fonéticas cuando el micrófono transcribe
  // nombres propios (ej. "teilor" -> "Taylor", "roqui" -> "Rocky").
  // --------------------------------------------------------------------------
  static Future<Dog?> _findDogMentionedInQuestion(String qLower) async {
    final snap = await _db.collection(DataService.dogCollection).get();
    for (final doc in snap.docs) {
      final d = Dog.fromDoc(doc);
      if (_matchesDogName(qLower, d.name)) {
        return d;
      }
    }
    return null;
  }

  static bool _matchesDogName(String qLower, String rawDogName) {
    final nameNorm = _normalize(rawDogName.trim());
    if (nameNorm.isEmpty) return false;
    if (qLower.contains(nameNorm)) return true;
    final dogPhonetic = _phoneticKey(nameNorm);
    final qPhonetic = _phoneticKey(qLower);
    return dogPhonetic.length >= 3 && qPhonetic.contains(dogPhonetic);
  }

  static String _phoneticKey(String s) {
    return s
        .replaceAll('taylor', 'teilor')
        .replaceAll('rocky', 'roki')
        .replaceAll('roqui', 'roki')
        .replaceAll('kurt', 'curt')
        .replaceAll('max', 'mas')
        .replaceAll('y', 'i')
        .replaceAll('k', 'c')
        .replaceAll('qu', 'c')
        .replaceAll('ll', 'y')
        .replaceAll('v', 'b')
        .replaceAll('z', 's');
  }

  static Future<String> _buildCompleteDogFicha(Dog d,
      {required AppUser user}) async {
    final buffer = StringBuffer();
    buffer.writeln(_formatSingleDogInfo(d));

    // Agregar vacunas del canino
    final vacSnap = await _db
        .collection(
            '${DataService.dogCollection}/${d.id}/${DataService.vaccineCollection}')
        .orderBy('appliedAt', descending: true)
        .get();
    if (vacSnap.docs.isEmpty) {
      buffer.writeln('\n💉 **Vacunas:** No registra vacunas todavía.');
    } else {
      final vacs = vacSnap.docs.map(Vaccine.fromDoc).toList();
      buffer.writeln('\n💉 **Vacunas registradas (${vacs.length}):**');
      for (final v in vacs) {
        final next = v.nextDate != null
            ? ' · Próxima: ${_dateFmt.format(v.nextDate!)}'
            : '';
        buffer.writeln(
            '• ${v.name} (Aplicada: ${_dateFmt.format(v.appliedAt)}$next)');
      }
    }

    // Agregar último registro médico
    final medSnap = await _db
        .collection(
            '${DataService.dogCollection}/${d.id}/${DataService.medicalCollection}')
        .orderBy('date', descending: true)
        .get();
    if (medSnap.docs.isEmpty) {
      buffer.writeln('\n🩺 **Historial médico:** Sin atenciones registradas.');
    } else {
      final entries = medSnap.docs.map(MedicalEntry.fromDoc).toList();
      buffer.writeln('\n🩺 **Historial médico (${entries.length} registro(s)):**');
      for (final m in entries.take(3)) {
        buffer.writeln('• ${m.title} (${_dateFmt.format(m.date)}): ${m.description}');
      }
    }

    return buffer.toString().trim();
  }

  // --------------------------------------------------------------------------
  // RESPUESTAS DE ORIENTACIÓN GENERAL (CUIDADO CANINO) Y AYUDA DE PAW TRACK
  // Prioriza Gemini Developer API (si se configuró por entorno) o la API REST
  // gratuita de IA con contexto controlado, y cuenta con respaldo local
  // completo para funcionar sin límites ni fallos de conexión.
  // --------------------------------------------------------------------------
  static Future<String> _answerGeneralOrAppQuestion({
    required String cleanQuestion,
    required String qLower,
    required AppUser user,
    required List<PawBotMessage> history,
  }) async {
    // 1. Verificar si es una pregunta sobre el uso de Paw Track (respuesta exacta)
    final appHelp = _getAppHelpAnswer(qLower, user: user);
    if (appHelp != null) return appHelp;

    // 2. Preparar contexto resumido y seguro (sin datos privados) de Firestore
    String campusContext = '';
    try {
      final dogsSnap = await _db.collection(DataService.dogCollection).get();
      final dogNames =
          dogsSnap.docs.map((d) => d.data()['name'] ?? '').where((n) => n.toString().isNotEmpty).toList();
      campusContext =
          'Caninos registrados actualmente en la ESPOCH (${dogNames.length}): ${dogNames.join(", ")}.';
    } catch (_) {}

    final systemInstruction =
        'Eres PawBot, el asistente virtual de la aplicación móvil Paw Track de la ESPOCH (Escuela Superior Politécnica de Chimborazo). '
        'Reglas obligatorias: '
        '1. Responde únicamente sobre Paw Track, sus registros y el cuidado, higiene, alimentación, vacunación y bienestar de los caninos. '
        '2. No inventes nombres, fechas, vacunas, diagnósticos ni incidencias. $campusContext '
        '3. Responde siempre en español, con lenguaje amigable, claro y breve (máximo 120 palabras). '
        '4. No emitas diagnósticos médicos definitivos; recomienda acudir a un profesional o a la Clínica Veterinaria Docente de la ESPOCH ante síntomas o emergencias.';

    // 3. Intentar con Gemini Developer API si existe clave en variables de entorno
    if (_geminiEnvKey.isNotEmpty) {
      final geminiReply = await _callGeminiRestApi(
        systemInstruction: systemInstruction,
        question: cleanQuestion,
      );
      if (geminiReply != null) return geminiReply;
    }

    // 4. Intentar con el endpoint REST gratuito de IA generativa
    final freeAiReply = await _callFreeAiRestApi(
      systemInstruction: systemInstruction,
      question: cleanQuestion,
    );
    if (freeAiReply != null) return freeAiReply;

    // 5. Respaldo local especializado (Funciona sin conexión o ante límites de cuota)
    return _getVeterinaryKnowledgeFallback(qLower);
  }

  static Future<String?> _callGeminiRestApi({
    required String systemInstruction,
    required String question,
  }) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiEnvKey',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': systemInstruction}
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': question}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.3,
                'maxOutputTokens': 350,
              },
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _callFreeAiRestApi({
    required String systemInstruction,
    required String question,
  }) async {
    try {
      final uri = Uri.parse(_freeAiEndpoint);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'openai',
              'messages': [
                {'role': 'system', 'content': systemInstruction},
                {'role': 'user', 'content': question},
              ],
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices']?[0]?['message']?['content']?.toString();
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  // --------------------------------------------------------------------------
  // GUÍA DE FUNCIONAMIENTO DE PAW TRACK (SECCIÓN F)
  // --------------------------------------------------------------------------
  static String? _getAppHelpAnswer(String q, {required AppUser user}) {
    if (_containsAny(q, [
      'como puedo reportar',
      'como reportar',
      'como hago un reporte',
      'como crear un reporte',
      'reportar una incidencia',
    ])) {
      return '📱 **Cómo reportar una incidencia en Paw Track:**\n\n'
          '1. En la pantalla de **Inicio**, toca el botón **"Crear reporte"** (o ve a la pestaña **Reportes**).\n'
          '2. Toma o selecciona una **fotografía clara del canino** (Google ML Kit verificará automáticamente que aparezca un perro).\n'
          '3. Selecciona el **canino** (si lo reconoces del catálogo) o déjalo como *Sin identificar*.\n'
          '4. Elige el **estado del perro** (*Herido, Con vida, Sin vida*) y el **tipo de incidencia** (*Perdido, Agresivo, Otro*).\n'
          '5. Verifica la ubicación GPS en el **mapa del campus** y escribe una breve descripción.\n'
          '6. Presiona **"Enviar reporte"**. El personal recibirá una notificación Push al instante.';
    }

    if (_containsAny(q, [
      'registrar un canino',
      'registrar un perro',
      'agregar un perro',
      'como registro un perro',
    ])) {
      return '🐕 **Cómo registrar un canino en Paw Track:**\n\n'
          '1. Abre el menú lateral y entra a la sección **Perros**.\n'
          '2. Si tu cuenta tiene rol de **Personal**, verás el botón **"Agregar perro"**.\n'
          '3. Completa sus datos: nombre, sexo, edad, color, alergias, si porta **collar rojo** y si está **esterilizado**.\n'
          '4. Sube su fotografía y opcionalmente añade su primera entrada médica o vacuna.\n'
          '5. Toca **"Guardar"** para incorporarlo al catálogo de la ESPOCH.';
    }

    if (_containsAny(q, [
      'como registro una vacuna',
      'como registrar vacuna',
      'donde registro vacuna',
    ])) {
      return '💉 **Cómo registrar una vacuna en Paw Track:**\n\n'
          '1. Ve a la sección **Perros** y selecciona el canino del catálogo.\n'
          '2. En su ficha de detalle, toca el botón **"Registrar vacuna"** (disponible para el rol **Personal**).\n'
          '3. Elige la vacuna (*Rabia, Parvovirus, Moquillo, Polivalente Séxtuple o Desparasitación*).\n'
          '4. Indica la fecha de aplicación y la **próxima dosis** (se sincronizará con Google Calendar y enviará recordatorios FCM).';
    }

    if (_containsAny(q, ['que es pawtrack', 'que es paw track', 'como funciona paw'])) {
      return '🐾 **¿Qué es Paw Track ESPOCH?**\n\n'
          'Es la aplicación móvil institucional para el registro, seguimiento sanitario y reporte de incidencias de los caninos comunitarios de la **ESPOCH**:\n'
          '• **Inicio:** Panel de acceso rápido a reportes, mapa, contactos y datos educativos.\n'
          '• **Perros:** Catálogo de caninos con su carnet de vacunas e historial clínico.\n'
          '• **Reportes:** Envío y seguimiento de incidencias geolocalizadas.\n'
          '• **Mapa:** Visualización en OpenStreetMap de las incidencias por color de estado.\n'
          '• **Notificaciones:** Alertas Push FCM sobre nuevos reportes, cambios de estado y vacunas.';
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // BASE DE CONOCIMIENTO EDUCATIVO CANINO (SECCIÓN E - RESPALDO LOCAL)
  // --------------------------------------------------------------------------
  static String _getVeterinaryKnowledgeFallback(String q) {
    if (_containsAny(q, ['cachorro', 'cachorros', 'bebe'])) {
      return '🐶 **Cuidados esenciales para un cachorro:**\n\n'
          '• **Alimentación:** Alimento balanceado especial para cachorros, 3 a 4 veces al día según su edad, y agua fresca permanente.\n'
          '• **Vacunación y desparasitación:** Iniciar su esquema entre las 6 y 8 semanas (*Parvovirus, Moquillo, Polivalente y Rabia*) y evitar el contacto con perros desconocidos hasta completarlo.\n'
          '• **Higiene y descanso:** Un lugar cálido, limpio y seguro donde dormir tranquilo.\n\n'
          '🩺 *Recomendación:* Acude siempre a un médico veterinario para establecer su calendario de vacunas y desparasitación.';
    }

    if (_containsAny(q, ['alimentacion', 'comida', 'comer', 'toxico', 'chocolate', 'hueso'])) {
      return '🥣 **Orientación sobre alimentación canina:**\n\n'
          '• **Recomendado:** Croquetas balanceadas acordes a su edad y tamaño, y agua limpia disponible todo el día.\n'
          '• **Alimentos prohibidos / tóxicos:** Nunca les des chocolate, cebolla, ajo, uvas, aguacate, alcohol, café ni **huesos cocidos** (se astillan y perforan el aparato digestivo).\n\n'
          '🩺 *Importante:* Si un canino del campus ingirió algo tóxico o presenta vómitos, repórtalo en Paw Track y acude de inmediato a la Clínica Veterinaria Docente ESPOCH.';
    }

    if (_containsAny(q, ['collar rojo'])) {
      return '🔴 **¿Qué significa el collar rojo?**\n\n'
          'El **collar rojo** es un **identificativo** de los caninos del campus que tiene:\n'
          '• **El nombre del perro**\n'
          '• **El nombre de la universidad (ESPOCH)**\n'
          '• **Un número de emergencia**';
    }

    if (_containsAny(q, ['higiene', 'bano', 'banar', 'limpieza', 'pulgas', 'garrapatas'])) {
      return '🧼 **Higiene y prevención de parásitos en caninos:**\n\n'
          '• **Baño y cepillado:** Bañar cada 3 a 4 semanas con champú de pH neutro para perros y cepillar su pelaje regularmente.\n'
          '• **Oídos y dientes:** Revisar que las orejas no tengan mal olor ni exceso de cerumen.\n'
          '• **Control externo:** Aplicar pipetas o collares antipulgas/garrapatas bajo indicación profesional.\n\n'
          '🩺 *Nota:* Ante picazón intensa o heridas en la piel, consulta siempre a un veterinario.';
    }

    if (_containsAny(q, ['herido', 'emergencia', 'atropellado', 'sangre', 'sintoma', 'vomito'])) {
      return '🚑 **¿Qué hacer ante un canino herido o con síntomas en el campus?**\n\n'
          '1. **Mantén la calma y tu seguridad:** Un perro con dolor puede morder por miedo; acércate despacio sin movimientos bruscos.\n'
          '2. **No le des medicamentos humanos:** El paracetamol o ibuprofeno son altamente tóxicos para los perros.\n'
          '3. **Repórtalo en Paw Track:** Usa el botón **"Crear reporte"** adjuntando foto y ubicación GPS.\n'
          '4. **Contacta a un veterinario:** Comunícate con la **Clínica Veterinaria Docente ESPOCH** (`0991234567`) o **Seguridad Universitaria** (`032998200`).';
    }

    return '🐾 **Orientación general de PawBot ESPOCH:**\n\n'
        'Para garantizar el bienestar de los caninos comunitarios en el campus:\n'
        '• Respeta sus espacios de descanso y alimentación.\n'
        '• No les ofrezcas restos de comida condimentada ni huesos cocidos.\n'
        '• Si observas a un canino herido, enfermo o en riesgo, crea un **reporte con ubicación GPS** desde la app.\n\n'
        '💡 *Puedes preguntarme también:* *"¿Cuántos caninos están registrados?"*, *"¿Qué vacunas están registradas?"*, *"¿Qué incidencias están pendientes?"* o *"Contactos de emergencia"*.';
  }

  // --------------------------------------------------------------------------
  // UTILIDADES DE NORMALIZACIÓN Y VALIDACIÓN DE ALCANCE (REGLA 1)
  // --------------------------------------------------------------------------
  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _isOutOfScope(String q) {
    return _containsAny(q, [
      'capital de',
      'presidente de',
      'futbol',
      'partido de',
      'receta de cocina',
      'pelicula',
      'horoscopo',
      'criptomoneda',
      'bitcoin',
      'ecuacion matematica',
      'programa en java',
      'programa en python',
      'quien gano el mundial',
    ]);
  }
}

enum _PawBotIntent {
  firestoreDogs,
  firestoreVaccines,
  firestoreMedical,
  firestoreReports,
  firestoreContacts,
  firestoreFullSummary,
  appHelp,
  generalCare,
}
