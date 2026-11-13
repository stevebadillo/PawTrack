const { google } = require('googleapis');
const path = require('path');

// Carga las credenciales usando el objeto de autenticación directo
const auth = new google.auth.GoogleAuth({
    keyFile: path.join(__dirname, 'calendario_credenciales.json'),
    scopes: ['https://www.googleapis.com/auth/calendar'],
});

const calendar = google.calendar({ version: 'v3', auth });

// Tu ID de calendario
const CALENDAR_ID = '7a39663b040006879c70fcabb3f22f75600734a17f1c85424677b1db04fb0d07@group.calendar.google.com';

async function probarConexionCalendar() {
    const eventoPrueba = {
        summary: 'Cita Veterinaria - PawTrack (Prueba)',
        description: 'Prueba de sincronización automática desde el backend con Google Calendar.',
        start: {
            dateTime: '2026-11-15T10:00:00-05:00',
            timeZone: 'America/Guayaquil',
        },
        end: {
            dateTime: '2026-11-15T11:00:00-05:00',
            timeZone: 'America/Guayaquil',
        },
    };

    try {
        const respuesta = await calendar.events.insert({
            calendarId: CALENDAR_ID,
            resource: eventoPrueba,
        });
        console.log('¡Evento creado exitosamente en Google Calendar!');
        console.log('Enlace web:', respuesta.data.htmlLink);
    } catch (error) {
        console.error('Error al conectar con Google Calendar:', error.message);
    }
}

probarConexionCalendar();