const { google } = require('googleapis');
const path = require('path');

// Autenticación con la cuenta de servicio
const auth = new google.auth.GoogleAuth({
    keyFile: path.join(__dirname, 'calendario_credenciales.json'),
    scopes: ['https://www.googleapis.com/auth/calendar'],
});

const calendar = google.calendar({ version: 'v3', auth });
const CALENDAR_ID = '7a39663b040006879c70fcabb3f22f75600734a17f1c85424677b1db04fb0d07@group.calendar.google.com';

/**
 * Agrega un evento al Google Calendar de PawTrack
 * @param {Object} datosEvento 
 * @param {string} datosEvento.titulo - Título del evento (ej: Cita o Vacuna)
 * @param {string} datosEvento.descripcion - Detalles médicos o notas
 * @param {string} datosEvento.fechaInicioISO - Fecha y hora de inicio en formato ISO (ej: '2026-11-15T10:00:00-05:00')
 * @param {string} datosEvento.fechaFinISO - Fecha y hora de fin en formato ISO (ej: '2026-11-15T11:00:00-05:00')
 */
async function agregarEventoAlCalendario({ titulo, descripcion, fechaInicioISO, fechaFinISO }) {
    const evento = {
        summary: titulo,
        description: descripcion,
        start: {
            dateTime: fechaInicioISO,
            timeZone: 'America/Guayaquil',
        },
        end: {
            dateTime: fechaFinISO,
            timeZone: 'America/Guayaquil',
        },
    };

    try {
        const respuesta = await calendar.events.insert({
            calendarId: CALENDAR_ID,
            resource: evento,
        });
        console.log('¡Evento sincronizado con Google Calendar con éxito!');
        console.log('Enlace web:', respuesta.data.htmlLink);
        return respuesta.data.htmlLink;
    } catch (error) {
        console.error('Error al sincronizar con Google Calendar:', error.message);
        throw error;
    }
}

module.exports = { agregarEventoAlCalendario };