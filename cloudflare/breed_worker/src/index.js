const MAX_IMAGE_BASE64_LENGTH = 7_000_000;
const DOG_LABELS = new Set([
  'chihuahua', 'japanese spaniel', 'maltese dog', 'pekinese', 'shih-tzu',
  'blenheim spaniel', 'papillon', 'toy terrier', 'rhodesian ridgeback',
  'afghan hound', 'basset', 'beagle', 'bloodhound', 'bluetick',
  'black-and-tan coonhound', 'walker hound', 'english foxhound', 'redbone',
  'borzoi', 'irish wolfhound', 'italian greyhound', 'whippet', 'ibizan hound',
  'norwegian elkhound', 'otterhound', 'saluki', 'scottish deerhound',
  'weimaraner', 'staffordshire bullterrier', 'american staffordshire terrier',
  'bedlington terrier', 'border terrier', 'kerry blue terrier', 'irish terrier',
  'norfolk terrier', 'norwich terrier', 'yorkshire terrier',
  'wire-haired fox terrier', 'lakeland terrier', 'sealyham terrier', 'airedale',
  'cairn terrier', 'australian terrier', 'dandie dinmont', 'boston bull',
  'miniature schnauzer', 'giant schnauzer', 'standard schnauzer',
  'scottish terrier', 'tibetan terrier', 'silky terrier',
  'soft-coated wheaten terrier', 'west highland white terrier', 'lhasa',
  'flat-coated retriever', 'curly-coated retriever', 'golden retriever',
  'labrador retriever', 'chesapeake bay retriever', 'german short-haired pointer',
  'vizsla', 'english setter', 'irish setter', 'gordon setter',
  'brittany spaniel', 'clumber', 'english springer', 'welsh springer spaniel',
  'cocker spaniel', 'sussex spaniel', 'irish water spaniel', 'kuvasz',
  'schipperke', 'groenendael', 'malinois', 'briard', 'kelpie', 'komondor',
  'old english sheepdog', 'shetland sheepdog', 'collie', 'border collie',
  'bouvier des flandres', 'rottweiler', 'german shepherd', 'doberman',
  'miniature pinscher', 'greater swiss mountain dog', 'bernese mountain dog',
  'appenzeller', 'entlebucher', 'boxer', 'bull mastiff', 'tibetan mastiff',
  'french bulldog', 'great dane', 'saint bernard', 'eskimo dog', 'malamute',
  'siberian husky', 'dalmatian', 'affenpinscher', 'basenji', 'pug', 'leonberg',
  'newfoundland', 'great pyrenees', 'samoyed', 'pomeranian', 'chow', 'keeshond',
  'brabancon griffon', 'pembroke', 'cardigan', 'toy poodle', 'miniature poodle',
  'standard poodle', 'mexican hairless',
]);

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
    if (!env.AI || !env.FIREBASE_API_KEY || !env.FIREBASE_PROJECT_ID) {
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
      const imageBytes = Uint8Array.from(atob(imageBase64), (character) =>
        character.charCodeAt(0),
      );
      const result = await env.AI.run('@cf/microsoft/resnet-50', {
        image: [...imageBytes],
      });
      const predictions = Array.isArray(result)
        ? result
        : Array.isArray(result?.result)
          ? result.result
          : [];
      const breeds = predictions
        .map((prediction) => ({
          name: String(prediction.label ?? '').trim(),
          score: Number(prediction.score),
        }))
        .filter((prediction) =>
          DOG_LABELS.has(prediction.name.toLowerCase()) &&
          Number.isFinite(prediction.score) && prediction.score >= 0,
        )
        .slice(0, 3)
        .map((prediction) => ({
          id: prediction.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          ...prediction,
        }));
      return json({ breeds });
    } catch (_) {
      console.error('Cloudflare Workers AI breed classification failed');
      return json({ error: 'No se pudo analizar la foto con Cloudflare Workers AI.' }, 502);
    }
  },
};
