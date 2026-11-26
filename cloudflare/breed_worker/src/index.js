const MAX_IMAGE_BASE64_LENGTH = 7_000_000;

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Cache-Control': 'no-store',
      ...extraHeaders,
    },
  });
}

async function verifyFirebaseUser(request, env) {
  const authorization = request.headers.get('Authorization') || '';
  const match = authorization.match(/^Bearer (.+)$/i);
  if (!match) return null;
  try {
    const response = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
        encodeURIComponent(env.FIREBASE_API_KEY),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: match[1] }),
      },
    );
    if (!response.ok) return null;
    const result = await response.json();
    const user = result.users?.[0];
    if (!user || user.disabled === true) return null;
    // El endpoint de Firebase valida la firma y audiencia del ID token.
    if (!user.localId || !env.FIREBASE_PROJECT_ID) return null;
    return user.localId;
  } catch (_) {
    return null;
  }
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return json({});
    if (request.method !== 'POST') return json({ error: 'Método no permitido.' }, 405);
    if (!env.NAKORDONI_API_KEY || !env.FIREBASE_API_KEY || !env.FIREBASE_PROJECT_ID) {
      return json({ error: 'El servicio aún no está configurado.' }, 503);
    }
    const userId = await verifyFirebaseUser(request, env);
    if (!userId) return json({ error: 'Inicia sesión para analizar la foto.' }, 401);

    let input;
    try {
      input = await request.json();
    } catch (_) {
      return json({ error: 'La solicitud no contiene JSON válido.' }, 400);
    }
    const imageBase64 = input?.imageBase64;
    if (typeof imageBase64 !== 'string' || imageBase64.length < 100 ||
        imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      return json({ error: 'La imagen no es válida o supera 5 MB.' }, 400);
    }

    try {
      const apiResponse = await fetch(
        'https://nakordoni.eu/api/v2/data/pet-recognition',
        {
          method: 'POST',
          headers: {
            Authorization: 'Bearer ' + env.NAKORDONI_API_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            image_base64: 'data:image/jpeg;base64,' + imageBase64,
          }),
        },
      );
      if (apiResponse.status === 404) return json({ breeds: [] });
      const result = await apiResponse.json();
      if (!apiResponse.ok) {
        return json(
          { error: 'El servicio de análisis de razas no está disponible ahora.' },
          apiResponse.status === 429 ? 429 : 502,
        );
      }
      const payload = result.data || result;
      const breeds = Array.isArray(payload.breeds) ? payload.breeds.slice(0, 3) : [];
      return json({
        breeds: breeds
          .map(({ id, name, score }) => ({
            id: String(id ?? ''),
            name: String(name ?? ''),
            score: Number(score),
          }))
          .filter((breed) => breed.name && Number.isFinite(breed.score) && breed.score >= 0),
      });
    } catch (_) {
      return json({ error: 'No se pudo conectar con el servicio de razas.' }, 502);
    }
  },
};
