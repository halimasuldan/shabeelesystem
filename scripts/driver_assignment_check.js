// Read-only audit of one driver's account -> profile -> bus -> students/route links.
// Uses the existing local Firebase CLI login and never writes Firestore data.
const fs = require('fs');

const STORE = 'C:/Users/pc/.config/configstore/firebase-tools.json';
const PROJECT = process.env.FB_PROJECT || 'shabelleapp-e8ffd';
const EMAIL = (process.argv[2] || 'driver@shabelle.com').trim().toLowerCase();
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function token() {
  const config = JSON.parse(fs.readFileSync(STORE, 'utf8'));
  const firebaseApi = require('C:/Users/pc/AppData/Roaming/npm/node_modules/firebase-tools/lib/api.js');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: firebaseApi.clientId(),
      client_secret: firebaseApi.clientSecret(),
      refresh_token: config.tokens.refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  if (!response.ok) throw new Error(`Firebase token exchange failed (${response.status})`);
  return (await response.json()).access_token;
}

function decode(value) {
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  if ('mapValue' in value) return Object.fromEntries(
    Object.entries(value.mapValue.fields || {}).map(([key, item]) => [key, decode(item)]),
  );
  return undefined;
}

function unpack(document) {
  if (!document) return null;
  return {
    id: document.name.split('/').pop(),
    ...Object.fromEntries(Object.entries(document.fields || {}).map(([key, value]) => [key, decode(value)])),
  };
}

async function collection(accessToken, name) {
  const results = [];
  let pageToken;
  do {
    const query = new URLSearchParams({ pageSize: '1000' });
    if (pageToken) query.set('pageToken', pageToken);
    const response = await fetch(`${BASE}/${name}?${query}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`Could not read ${name} (${response.status})`);
    const body = await response.json();
    results.push(...(body.documents || []).map(unpack));
    pageToken = body.nextPageToken;
  } while (pageToken);
  return results;
}

async function main() {
  const accessToken = await token();
  const [users, drivers, buses, routes, students] = await Promise.all([
    collection(accessToken, 'users'),
    collection(accessToken, 'drivers'),
    collection(accessToken, 'buses'),
    collection(accessToken, 'routes'),
    collection(accessToken, 'students'),
  ]);

  const user = users.find((entry) => (entry.email || '').trim().toLowerCase() === EMAIL);
  if (!user) {
    console.log(JSON.stringify({ email: EMAIL, foundUser: false }, null, 2));
    return;
  }
  const driverProfiles = drivers.filter((entry) => entry.id === user.id || entry.userId === user.id);
  const driverIds = new Set([user.id, ...driverProfiles.map((entry) => entry.id)]);
  const assignedBuses = buses.filter((bus) =>
    driverIds.has(bus.driverId) ||
    bus.driverUserId === user.id ||
    driverIds.has(bus.currentDriverId) ||
    driverProfiles.some((driver) => driver.busId === bus.id),
  );
  const assignedBusIds = new Set(assignedBuses.map((bus) => bus.id));
  const assignedRoutes = routes.filter((route) =>
    assignedBusIds.has(route.busId) ||
    driverIds.has(route.driverId) ||
    assignedBuses.some((bus) => bus.routeId === route.id),
  );
  const rosterIds = new Set(assignedBuses.flatMap((bus) => bus.studentIds || []));
  const assignedStudents = students.filter((student) =>
    assignedBusIds.has(student.busId) || rosterIds.has(student.id),
  );

  console.log(JSON.stringify({
    user: { id: user.id, role: user.role, isActive: user.isActive },
    driverProfiles: driverProfiles.map((driver) => ({
      id: driver.id,
      userId: driver.userId || null,
      busId: driver.busId || null,
      status: driver.status,
      isActive: driver.isActive,
    })),
    buses: assignedBuses.map((bus) => ({
      id: bus.id,
      busNumber: bus.busNumber,
      driverId: bus.driverId || null,
      driverUserId: bus.driverUserId || null,
      currentDriverId: bus.currentDriverId || null,
      routeId: bus.routeId || null,
      studentIds: bus.studentIds || [],
    })),
    routes: assignedRoutes.map((route) => ({
      id: route.id,
      name: route.name,
      busId: route.busId || null,
      driverId: route.driverId || null,
      stopCount: (route.stops || []).length,
    })),
    students: assignedStudents.map((student) => ({
      id: student.id,
      fullName: student.fullName,
      busId: student.busId || null,
      status: student.status,
      listedOnBus: rosterIds.has(student.id),
    })),
  }, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
