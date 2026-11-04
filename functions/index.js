// Cloud Functions que ENVÍAN las notificaciones FCM (RF15). Requiere plan Blaze.
// Despliegue: cd functions && npm install && firebase deploy --only functions
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onNewReport = onDocumentCreated('reports/{id}', async (event) => {
  const r = event.data.data();
  await admin.messaging().send({
    topic: 'personal',
    notification: {
      title: 'Nuevo reporte de incidencia',
      body: `${r.dogName || 'Perro sin identificar'}: ${r.description}`.slice(0, 120),
    },
  });
});

exports.onReportStatus = onDocumentUpdated('reports/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;
  const user = await admin.firestore().doc(`usuarios/${after.reporterId}`).get();
  const token = user.get('fcmToken');
  if (!token) return;
  await admin.messaging().send({
    token,
    notification: { title: 'Tu reporte fue actualizado', body: `Nuevo estado: ${after.status}` },
  });
});

exports.vaccineReminders = onSchedule({ schedule: '0 8 * * *', timeZone: 'America/Guayaquil' }, async () => {
  const now = new Date();
  const in7 = new Date(now.getTime() + 7 * 86400000);
  const snap = await admin.firestore().collectionGroup('vaccines')
    .where('nextDate', '>=', now).where('nextDate', '<=', in7).get();
  for (const doc of snap.docs) {
    const dog = await doc.ref.parent.parent.get();
    await admin.messaging().send({
      topic: 'personal',
      notification: {
        title: 'Próxima vacunación',
        body: `${dog.get('name')} necesita ${doc.get('name')} el ${doc.get('nextDate').toDate().toLocaleDateString('es-EC')}`,
      },
    });
  }
});
