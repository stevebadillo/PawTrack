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

  const user = await admin.firestore().doc(`usuarios/${reporterId}`).get();
  const token = user.get('fcmToken');
  if (!token) return;

  const dogLabel = after.dogName || after.perroNombre || 'Perro sin identificar';
  const statusLegible = ETIQUETAS_ESTADO[after.status] || after.status;

  await admin.messaging().send({
    token,
    notification: {
      title: 'Tu reporte fue actualizado',
      body: `El reporte sobre ${dogLabel} cambió a estado: ${statusLegible}.`,
    },
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
        title: 'Próxima vacunación',
        body: `${dogName} necesita ${doc.get('name')} el ${doc.get('nextDate').toDate().toLocaleDateString('es-EC')}`,
      },
      data: {
        type: 'proxima_vacuna',
        dogId: dog.id,
        vaccineId: doc.id,
      },
    });
  }
});
