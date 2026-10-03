// Temporary audit helper: reads the Firebase CLI login from the local
// configstore and queries Firestore (read-only) over the REST API.
const fs = require('fs');

const STORE = 'C:/Users/pc/.config/configstore/firebase-tools.json';
const PROJECT = process.env.FB_PROJECT || 'shabelleapp-e8ffd';
const DB = '(default)';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DB}/documents`;

async function accessToken() {
  const cfg = JSON.parse(fs.readFileSync(STORE, 'utf8'));
  const api = require('C:/Users/pc/AppData/Roaming/npm/node_modules/firebase-tools/lib/api.js');
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: api.clientId(),
      client_secret: api.clientSecret(),
      refresh_token: cfg.tokens.refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  if (!resp.ok) {
    throw new Error(`token exchange failed: ${resp.status} ${await resp.text()}`);
  }
  return (await resp.json()).access_token;
}

async function runQuery(token, collection, filter) {
  const structuredQuery = { from: [{ collectionId: collection }] };
  if (filter) {
    structuredQuery.where = {
      fieldFilter: {
        field: { fieldPath: filter.field },
        op: filter.op || 'EQUAL',
        value: filter.value,
      },
    };
  }
  const resp = await fetch(`${BASE}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!resp.ok) throw new Error(`${collection}: ${resp.status} ${await resp.text()}`);
  const rows = await resp.json();
  return rows.filter((r) => r.document).map((r) => ({ id: r.document.name.split('/').pop(), ...r.document.fields }));
}

function unwrap(v) {
  if (v === undefined || v === null) return v;
  if (Object.prototype.hasOwnProperty.call(v, 'stringValue')) return v.stringValue;
  if (Object.prototype.hasOwnProperty.call(v, 'booleanValue')) return v.booleanValue;
  if (Object.prototype.hasOwnProperty.call(v, 'integerValue')) return Number(v.integerValue);
  if (Object.prototype.hasOwnProperty.call(v, 'nullValue')) return null;
  if (Object.prototype.hasOwnProperty.call(v, 'arrayValue')) return (v.arrayValue.values || []).map(unwrap);
  if (Object.prototype.hasOwnProperty.call(v, 'mapValue')) {
    const out = {};
    for (const [k, mv] of Object.entries(v.mapValue.fields || {})) out[k] = unwrap(mv);
    return out;
  }
  return v;
}

function plain(doc) {
  const out = { _id: doc.id };
  for (const [k, v] of Object.entries(doc)) {
    if (k === 'id') continue;
    out[k] = unwrap(v);
  }
  return out;
}

async function main() {
  const token = await accessToken();

  const users = (await runQuery(token, 'users')).map(plain);
  const drivers = (await runQuery(token, 'drivers')).map(plain);
  const buses = (await runQuery(token, 'buses')).map(plain);
  const students = (await runQuery(token, 'students')).map(plain);

  console.log('=== USERS matching driver/admin emails ===');
  for (const u of users.filter((u) => (u.email || '').includes('driver@') || (u.email || '').includes('admin@'))) {
    console.log(JSON.stringify(u));
  }

  console.log('\n=== DRIVERS (all) ===');
  for (const d of drivers) console.log(JSON.stringify(d));

  console.log('\n=== BUSES (all) ===');
  for (const b of buses) console.log(JSON.stringify(b));

  console.log('\n=== STUDENTS compact (id | name | busId) ===');
  for (const s of students) console.log(`${s._id} | ${s.fullName} | ${s.busId ?? '(none)'} | status=${s.status}`);

  console.log('\n=== BUS MIRRORS compact ===');
  for (const b of buses) console.log(`${b.busNumber} (${b._id}): ${JSON.stringify(b.studentIds || [])}`);


  // ---- Chain consistency report ----
  console.log('\n=== CHAIN REPORT ===');
  const driverUser = users.find((u) => (u.email || '').toLowerCase() === 'driver@shabelle.com');
  if (!driverUser) {
    console.log('!! No users/{...} doc for driver@shabelle.com');
  } else {
    console.log(`driver user: uid=${driverUser._id} role=${driverUser.role} isActive=${driverUser.isActive}`);
  }
  const uid = driverUser && driverUser._id;
  for (const d of drivers) {
    const linked = d._id === uid || d.userId === uid;
    if (linked) {
      console.log(`driver doc ${d._id}: userId=${d.userId} busId=${d.busId} isActive=${d.isActive} status=${d.status}`);
    }
  }
  const myBuses = buses.filter((b) => (uid && (b.driverUserId === uid || b.driverId === uid)) );
  if (myBuses.length === 0) console.log('!! No bus has driverId/driverUserId == driver uid');
  for (const b of myBuses) {
    console.log(`bus ${b._id}: number=${b.busNumber} plate=${b.plateNumber} driverId=${b.driverId} driverUserId=${b.driverUserId} driverName=${b.driverName} studentIds=${JSON.stringify(b.studentIds)}`);
    const onBus = students.filter((s) => s.busId === b._id);
    console.log(`  students with busId==${b._id}: ${onBus.map((s) => `${s.fullName}(${s._id})`).join(', ') || '(none)'}`);
    const mirror = b.studentIds || [];
    for (const s of onBus) if (!mirror.includes(s._id)) console.log(`  !! ${s.fullName} has busId but missing from bus.studentIds`);
    for (const id of mirror) if (!onBus.some((s) => s._id === id)) console.log(`  !! bus.studentIds has ${id} but no student points here (stale mirror)`);
  }
  const unassigned = students.filter((s) => !s.busId);
  console.log(`\nstudents without busId (unassigned): ${unassigned.map((s) => s.fullName).join(', ') || '(none)'}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
