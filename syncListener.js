const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { agregarEventoAlCalendario } = require('./calendarService');

// Cargar credenciales de Firebase Admin / Google Cloud
const serviceAccount = require('./calendario_credenciales.json');

initializeApp({
    credential: cert(serviceAccount),
});

const db = getFirestore();
const messaging = getMessaging();

const ETIQUETAS_ESTADO = {
    pendiente: 'Pendiente',
    en_revision: 'En revisión',
    en_atencion: 'En revisión',
    resuelto: 'Resuelto',
};

console.log('🚀 Servidor PawTrack activo (Plan Gratuito Spark):');
console.log('   • Sincronización con Google Calendar');
console.log('   • Envío de notificaciones Push (FCM) para nuevos reportes, cambios de estado y vacunas próximas\n');

// ============================================================================
// 1. CITAS MÉDICAS -> GOOGLE CALENDAR
// ============================================================================
let initialMedicalLoad = true;
db.collectionGroup('registros_medicos').onSnapshot((snapshot) => {
    if (initialMedicalLoad) {
        initialMedicalLoad = false;
        return;
    }
    snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added') {
            const data = change.doc.data();
            if (data.nextVisit) {
                const fechaInicio = data.nextVisit.toDate ? data.nextVisit.toDate() : new Date(data.nextVisit);
                if (!isNaN(fechaInicio.getTime())) {
                    const fechaFin = new Date(fechaInicio.getTime() + 60 * 60 * 1000);
                    console.log(`📅 Nueva cita médica detectada: ${data.title}`);
                    try {
                        await agregarEventoAlCalendario({
                            titulo: `Cita Médica: ${data.title}`,
                            descripcion: data.description || 'Sin descripción adicional.',
                            fechaInicioISO: fechaInicio.toISOString(),
                            fechaFinISO: fechaFin.toISOString(),
                        });
                    } catch (e) {
                        console.error('Error al sincronizar cita médica:', e.message);
                    }
                }
            }
        }
    });
});

// ============================================================================
// 2. VACUNAS -> GOOGLE CALENDAR + NOTIFICACIÓN FCM DE PRÓXIMA VACUNACIÓN
// ============================================================================
let initialVaccineLoad = true;
db.collectionGroup('vacunas').onSnapshot((snapshot) => {
    if (initialVaccineLoad) {
        initialVaccineLoad = false;
        return;
    }
    snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added' || change.type === 'modified') {
            const data = change.doc.data();
            if (!data.nextDate) return;

            const fechaInicio = data.nextDate.toDate ? data.nextDate.toDate() : new Date(data.nextDate);
            if (isNaN(fechaInicio.getTime())) return;

            // Obtener nombre del perro padre (canes/{dogId}/vacunas/{vacId})
            let dogName = 'Perro del campus';
            try {
                const dogDoc = await change.doc.ref.parent.parent.get();
                if (dogDoc && dogDoc.exists) {
                    dogName = dogDoc.get('name') || dogDoc.get('nombre') || dogName;
                }
            } catch (_) {}

            if (change.type === 'added') {
                const fechaFin = new Date(fechaInicio.getTime() + 60 * 60 * 1000);
                console.log(`💉 Nueva vacuna con próxima fecha detectada: ${data.name} (${dogName})`);
                try {
                    await agregarEventoAlCalendario({
                        titulo: `Dosis Vacuna (${dogName}): ${data.name}`,
                        descripcion: data.notes || 'Recordatorio de refuerzo de vacuna.',
                        fechaInicioISO: fechaInicio.toISOString(),
                        fechaFinISO: fechaFin.toISOString(),
                    });
                } catch (e) {
                    console.error('Error al sincronizar vacuna en Calendar:', e.message);
                }
            }

            // Si la próxima fecha de vacunación es dentro de los próximos 7 días, enviar Push FCM al personal
            const ahora = new Date();
            const en7Dias = new Date(ahora.getTime() + 7 * 86400000);
            if (fechaInicio >= new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate()) && fechaInicio <= en7Dias) {
                const fechaTexto = fechaInicio.toLocaleDateString('es-EC', {
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric',
                });
                try {
                    await messaging.send({
                        topic: 'personal',
                        notification: {
                            title: `Próxima vacunación: ${dogName}`,
                            body: `${dogName} necesita refuerzo de ${data.name} el ${fechaTexto}.`,
                        },
                        data: {
                            type: 'proxima_vacuna',
                            vaccineId: change.doc.id,
                        },
                    });
                    console.log(`📲 Push FCM enviado al personal por vacuna próxima de ${dogName}`);
                } catch (e) {
                    console.error('Error al enviar FCM de vacuna:', e.message);
                }
            }
        }
    });
});

// ============================================================================
// 3. REPORTES -> FCM NUEVO REPORTE (PERSONAL) Y CAMBIO DE ESTADO (ESTUDIANTE)
// ============================================================================
const estadosPrevios = new Map();
let initialReportsLoad = true;

db.collection('reportes').onSnapshot((snapshot) => {
    if (initialReportsLoad) {
        snapshot.docs.forEach((doc) => {
            estadosPrevios.set(doc.id, doc.get('status') || 'pendiente');
        });
        initialReportsLoad = false;
        return;
    }

    snapshot.docChanges().forEach(async (change) => {
        const doc = change.doc;
        const r = doc.data() || {};
        const dogLabel = r.dogName || r.perroNombre || 'Perro sin identificar';

        // Caso A: Nuevo reporte creado -> Enviar Push FCM al topic 'personal'
        if (change.type === 'added') {
            estadosPrevios.set(doc.id, r.status || 'pendiente');
            const desc = (r.description || r.descripcion || 'Nueva incidencia reportada en el campus').slice(0, 120);
            console.log(`🚨 Nuevo reporte detectado (${dogLabel}): enviando Push FCM al personal...`);
            try {
                await messaging.send({
                    topic: 'personal',
                    notification: {
                        title: 'Nuevo reporte de incidencia',
                        body: `${dogLabel}: ${desc}`,
                    },
                    data: {
                        type: 'nuevo_reporte',
                        reportId: doc.id,
                    },
                });
                console.log('✅ Push FCM de nuevo reporte enviado al topic "personal".');
            } catch (e) {
                console.error('Error al enviar FCM de nuevo reporte:', e.message);
            }
        }

        // Caso B: Cambio de estado en reporte -> Enviar Push FCM al estudiante que reportó
        if (change.type === 'modified') {
            const prevStatus = estadosPrevios.get(doc.id);
            const newStatus = r.status || r.estado || 'pendiente';
            estadosPrevios.set(doc.id, newStatus);

            if (prevStatus && prevStatus !== newStatus) {
                const statusLegible = ETIQUETAS_ESTADO[newStatus] || newStatus;
                const reporterId = r.reporterId || r.usuarioId;
                console.log(`🔄 Cambio de estado en reporte ${doc.id}: ${prevStatus} -> ${newStatus}`);

                if (reporterId) {
                    try {
                        const userDoc = await db.collection('usuarios').doc(reporterId).get();
                        const token = userDoc.exists ? userDoc.get('fcmToken') : null;
                        if (token) {
                            await messaging.send({
                                token,
                                notification: {
                                    title: 'Tu reporte fue actualizado',
                                    body: `El reporte sobre ${dogLabel} cambió a estado: ${statusLegible}.`,
                                },
                                data: {
                                    type: 'cambio_estado',
                                    reportId: doc.id,
                                    status: newStatus,
                                },
                            });
                            console.log(`✅ Push FCM enviado al estudiante (${reporterId}).`);
                        } else {
                            console.log(`ℹ️ El usuario ${reporterId} no tiene fcmToken registrado aún.`);
                        }
                    } catch (e) {
                        console.error('Error al enviar FCM de cambio de estado:', e.message);
                    }
                }
            }
        }
    });
});

// ============================================================================
// 4. VERIFICACIÓN PERIÓDICA DE VACUNAS PRÓXIMAS (DENTRO DE LOS PRÓXIMOS 7 DÍAS)
// ============================================================================
const vacunasNotificadasHoy = new Set();

async function verificarVacunasProximas() {
    try {
        const ahora = new Date();
        const inicioHoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
        const en7Dias = new Date(ahora.getTime() + 7 * 86400000);
        const hoyClave = inicioHoy.toISOString().slice(0, 10);

        const canesSnap = await db.collection('canes').get();
        for (const dogDoc of canesSnap.docs) {
            const dogName = dogDoc.get('name') || dogDoc.get('nombre') || 'Perro';
            const vacSnap = await dogDoc.ref.collection('vacunas').get();

            for (const vacDoc of vacSnap.docs) {
                const v = vacDoc.data();
                if (!v.nextDate) continue;
                const nextDate = v.nextDate.toDate ? v.nextDate.toDate() : new Date(v.nextDate);
                if (nextDate >= inicioHoy && nextDate <= en7Dias) {
                    const notifKey = `${hoyClave}_${dogDoc.id}_${vacDoc.id}`;
                    if (vacunasNotificadasHoy.has(notifKey)) continue;
                    vacunasNotificadasHoy.add(notifKey);

                    const fechaTexto = nextDate.toLocaleDateString('es-EC', {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                    });

                    await messaging.send({
                        topic: 'personal',
                        notification: {
                            title: 'Próxima vacunación',
                            body: `${dogName} necesita ${v.name} el ${fechaTexto}.`,
                        },
                        data: {
                            type: 'proxima_vacuna',
                            dogId: dogDoc.id,
                            vaccineId: vacDoc.id,
                        },
                    });
                    console.log(`⏰ Recordatorio FCM enviado: ${dogName} necesita ${v.name} el ${fechaTexto}`);
                }
            }
        }
    } catch (e) {
        console.error('Error al verificar vacunas próximas:', e.message);
    }
}

// Ejecutar revisión al iniciar y luego cada 12 horas
verificarVacunasProximas();
setInterval(verificarVacunasProximas, 12 * 60 * 60 * 1000);
