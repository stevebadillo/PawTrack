const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const path = require('path');
const { agregarEventoAlCalendario } = require('./calendarService');

// Cargar credenciales
const serviceAccount = require('./calendario_credenciales.json');

// Inicialización limpia y moderna
initializeApp({
    credential: cert(serviceAccount),
});

const db = getFirestore();

console.log('🔄 Escuchando nuevos registros médicos y vacunas en Firestore para sincronizar con Google Calendar...');

// 1. Escuchar la colección de Entradas Médicas en todos los perros (Collection Group Query)
db.collectionGroup('registros_medicos').onSnapshot(async (snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added') {
            const data = change.doc.data();
            
            if (data.nextVisit) {
                const fechaInicio = data.nextVisit.toDate ? data.nextVisit.toDate() : new Date(data.nextVisit);
                
                if (!isNaN(fechaInicio.getTime())) {
                    const fechaFin = new Date(fechaInicio.getTime() + 60 * 60 * 1000); // +1 hora por defecto

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

// 2. Escuchar la colección de Vacunas en todos los perros
db.collectionGroup('vacunas').onSnapshot(async (snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added') {
            const data = change.doc.data();
            
            if (data.nextDate) {
                const fechaInicio = data.nextDate.toDate ? data.nextDate.toDate() : new Date(data.nextDate);
                
                if (!isNaN(fechaInicio.getTime())) {
                    const fechaFin = new Date(fechaInicio.getTime() + 60 * 60 * 1000);

                    console.log(`💉 Nueva vacuna próxima detectada: ${data.name}`);
                    try {
                        await agregarEventoAlCalendario({
                            titulo: `Dosis Vacuna: ${data.name}`,
                            descripcion: data.notes || 'Recordatorio de refuerzo de vacuna.',
                            fechaInicioISO: fechaInicio.toISOString(),
                            fechaFinISO: fechaFin.toISOString(),
                        });
                    } catch (e) {
                        console.error('Error al sincronizar vacuna:', e.message);
                    }
                }
            }
        }
    });
});