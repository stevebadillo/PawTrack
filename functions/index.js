// Cloud Functions de PawTrack.
// Firebase Admin permite acceder al backend de Firebase sin exponer credenciales
// en Flutter. Estas funciones envían notificaciones FCM cuando cambian los datos.
// Nota: En el plan gratuito (Spark), puedes usar `node syncListener.js` que cumple
// exactamente esta misma función en tiempo real sin requerir el plan Blaze.
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
admin.initializeApp();

const nakordoniApiKey = defineSecret('NAKORDONI_API_KEY');

// La clave del proveedor vive en Secret Manager, nunca en el código Flutter.
exports.analyzeDogPhoto = onCall({ secrets: [nakordoniApiKey], timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión para analizar la foto.');
  const imageBase64 = request.data?.imageBase64;
  if (typeof imageBase64 !== 'string' || imageBase64.length < 100 || imageBase64.length > 7_000_000) {
    throw new HttpsError('invalid-argument', 'La imagen no es válida o supera el tamaño permitido.');
  }
  try {
    const response = await fetch('https://nakordoni.eu/api/v2/data/pet-recognition', {
      method: 'POST',
      headers: { Authorization: `Bearer ${nakordoniApiKey.value()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ image_base64: `data:image/jpeg;base64,${imageBase64}` }),
    });
    const result = await response.json();
    if (!response.ok) {
      console.error('Pet recognition error', response.status, result);
      throw new HttpsError(response.status === 429 ? 'resource-exhausted' : 'unavailable', 'El servicio de razas no está disponible ahora.');
    }
    const payload = result.data || result;
    const breeds = Array.isArray(payload.breeds) ? payload.breeds.slice(0, 3) : [];
    return { breeds: breeds.map(({ id, name, score }) => ({ id: String(id ?? ''), name: String(name ?? ''), score: Number(score) })).filter((b) => b.name && Number.isFinite(b.score) && b.score >= 0) };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('Pet recognition request failed', error);
    throw new HttpsError('unavailable', 'No se pudo conectar con el servicio de razas.');
  }
});

// Las predicciones de reportes estudiantiles también se reflejan en la ficha.
exports.syncReportBreedAnalysis = onDocumentCreated('reportes/{id}', async (event) => {
  const report = event.data.data() || {};
  if (!report.dogId || !Array.isArray(report.breedAnalysis) || !report.breedAnalysis.length) return;
  await admin.firestore().collection('canes').doc(report.dogId).set({
    breedAnalysis: report.breedAnalysis,
    breedAnalyzedAt: report.breedAnalyzedAt || admin.firestore.FieldValue.serverTimestamp(),
    breedSourceReportId: event.params.id,
  }, { merge: true });
});

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
