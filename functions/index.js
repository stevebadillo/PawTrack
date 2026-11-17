// Cloud Functions de PawTrack.
// Firebase Admin permite acceder al backend de Firebase sin exponer credenciales
// en Flutter. Estas funciones envían notificaciones FCM cuando cambian los datos.
// Nota: En el plan gratuito (Spark), puedes usar `node syncListener.js` que cumple
// exactamente esta misma función en tiempo real sin requerir el plan Blaze.
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
admin.initializeApp();

const ETIQUETAS_ESTADO = {
  pendiente: 'Pendiente',
  en_revision: 'En revisión',
  en_atencion: 'En revisión',
  resuelto: 'Resuelto',
};

function buildAndroidPushConfig(tag) {
  return {
    priority: 'high',
    notification: {
      channelId: 'pawtrack_notifications',
      sound: 'default',
      defaultSound: true,
      defaultVibrateTimings: true,
      ...(tag ? { tag } : {}),
    },
  };
}

exports.onNewReport = onDocumentCreated('reportes/{id}', async (event) => {
  const r = event.data.data() || {};
  const dogLabel = r.dogName || r.perroNombre || 'Perro sin identificar';
  const desc = r.description || r.descripcion || '';
  await admin.messaging().send({
    topic: 'personal',
    notification: {
      title: 'Nuevo reporte de incidencia',
      body: `${dogLabel}: ${desc}`.slice(0, 120),
    },
    android: buildAndroidPushConfig(`nuevo_reporte_${event.params.id}`),
    data: {
      type: 'nuevo_reporte',
      reportId: event.params.id,
    },
  });
});

exports.onReportStatus = onDocumentUpdated('reportes/{id}', async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  if (before.status === after.status) return;
  const reporterId = after.reporterId || after.usuarioId;
  if (!reporterId) return;

  const dogLabel = after.dogName || after.perroNombre || 'Perro sin identificar';
  const statusLegible = ETIQUETAS_ESTADO[after.status] || after.status;
  const notifTag = `estado_reporte_${event.params.id}`;

  await admin.messaging().send({
    topic: `usuario_${reporterId}`,
    notification: {
      title: `Estado actualizado: ${statusLegible}`,
      body: `El reporte sobre ${dogLabel} cambió de estado a "${statusLegible}".`,
    },
    android: buildAndroidPushConfig(notifTag),
    data: {
      type: 'cambio_estado',
      reportId: event.params.id,
      status: after.status || 'pendiente',
    },
  });
});

exports.vaccineReminders = onSchedule({ schedule: '0 8 * * *', timeZone: 'America/Guayaquil' }, async () => {
  const now = new Date();
  const in7 = new Date(now.getTime() + 7 * 86400000);
  const snap = await admin.firestore().collectionGroup('vacunas')
    .where('nextDate', '>=', now).where('nextDate', '<=', in7).get();
  for (const doc of snap.docs) {
    const dog = await doc.ref.parent.parent.get();
    const dogName = dog.get('name') || dog.get('nombre') || 'Perro';
    await admin.messaging().send({
      topic: 'personal',
      notification: {
        title: `Próxima vacunación: ${dogName}`,
        body: `${dogName} necesita ${doc.get('name')} el ${doc.get('nextDate').toDate().toLocaleDateString('es-EC')}`,
      },
      android: buildAndroidPushConfig(`vacuna_${dog.id}_${doc.id}`),
      data: {
        type: 'proxima_vacuna',
        dogId: dog.id,
        vaccineId: doc.id,
      },
    });
  }
});
