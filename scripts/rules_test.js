// Prove firestore.rules behave correctly, against the real rules engine.
// LOCAL EMULATOR ONLY - production data is never touched.
//
// The emulator loads `--rules` only at startup, so restart it before re-running
// this script after a rules change:
//
//   java -jar "%USERPROFILE%\.cache\firebase\emulators\cloud-firestore-emulator-v1.22.0.jar" ^
//        --rules="firestore.rules" --port=8909 --host=127.0.0.1
//   node scripts/rules_test.js
//
// Set RULES_TEST_PORT to point at an emulator on another port (default 8909).
// Exits non-zero when any assertion fails.
const fs = require('fs');
const http = require('http');

const PROJ = 'shabelleapp-e8ffd';
const HOST = '127.0.0.1';
const PORT = Number(process.env.RULES_TEST_PORT || 8909);
const RULES_PATH = process.argv.includes('--rules')
  ? process.argv[process.argv.indexOf('--rules') + 1]
  : 'firestore.rules';

function req(method, urlPath, body, token) {
  return new Promise((resolve) => {
    const data = body ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    if (token) headers['Authorization'] = 'Bearer ' + token;
    const r = http.request({ host: HOST, port: PORT, path: urlPath, method, headers }, (res) => {
      let buf = '';
      res.on('data', (c) => (buf += c));
      res.on('end', () => {
        let j = null;
        try { j = JSON.parse(buf); } catch (e) { j = { raw: buf.slice(0, 300) }; }
        resolve({ status: res.statusCode, body: j });
      });
    });
    r.on('error', (e) => resolve({ status: 0, body: { error: e.message } }));
    if (data) r.write(data);
    r.end();
  });
}

// The Firestore emulator does NOT verify the JWT signature, so we can mint a
// fake signed-in user to drive the rules engine.
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
function fakeToken(uid) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: 'https://securetoken.google.com/' + PROJ,
    aud: PROJ,
    auth_time: now, iat: now, exp: now + 3600,
    sub: uid, user_id: uid,
    firebase: { identities: {}, sign_in_provider: 'password' },
  };
  return b64({ alg: 'RS256', typ: 'JWT' }) + '.' + b64(payload) + '.' +
    Buffer.from('x'.repeat(128)).toString('base64url');
}

const DOC = (c, id) => `/v1/projects/${PROJ}/databases/(default)/documents/${c}/${id}`;
const COLL = (c) => `/v1/projects/${PROJ}/databases/(default)/documents/${c}`;

const results = [];
function check(name, got, want) {
  const ok = got === want;
  results.push({ ok, name });
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${name.padEnd(56)} got=${got} want=${want}`);
}

(async () => {
  const ADMIN = 'admin-uid-1';
  const DRIVER = 'driver-uid-1';        // role=driver AND has /drivers/{uid}
  const DRIVER_NODOC = 'driver-uid-2';  // role=driver but NO /drivers/{uid}
  const DRIVER_NOUSER = 'driver-uid-3'; // auth only: NO /users doc at all
  const PARENT = 'parent-uid-1';
  const TEACHER = 'teacher-uid-1';
  const OTHER = 'driver-uid-9';

  console.log('rules file under test: ' + RULES_PATH +
    ' (' + fs.readFileSync(RULES_PATH, 'utf8').length + ' bytes)\n');

  // 1. Seed (owner credential bypasses rules). Values must be typed Firestore
  //    Value objects - plain strings are rejected as an invalid payload.
  const S = (v) => ({ stringValue: v });
  const A = (...v) => ({ arrayValue: { values: v.map(S) } });
  const T = (iso) => ({ timestampValue: iso });
  const seed = [
    ['users', ADMIN, { role: S('admin'), email: S('a@x.com') }],
    ['users', DRIVER, { role: S('driver'), email: S('d1@x.com') }],
    ['users', DRIVER_NODOC, { role: S('driver'), email: S('d2@x.com') }],
    ['users', PARENT, { role: S('parent'), email: S('p@x.com') }],
    ['users', TEACHER, { role: S('teacher'), email: S('t@x.com') }],
    ['drivers', DRIVER, { userId: S(DRIVER), name: S('D1'), busId: S('bus-1') }],
    ['teachers', 'teacher-profile-1', { userId: S(TEACHER), name: S('Teacher One') }],
    ['drivers', OTHER, { userId: S(OTHER), name: S('D9') }],
    ['drivers', 'legacy-1', { userId: S(DRIVER), name: S('Legacy D1') }],
    ['bus_trips', 'trip-other', { driverId: S(OTHER), status: S('active') }],
    // Students for the pickup/drop-off mirror write (recordEvent updates
    // `students/{id}.pickupStatus` after appending the event).
    ['parents', 'par-1', { userId: S(PARENT), studentIds: A('stu-own') }],
    ['classes', 'class-grade-1', { name: S('Grade 1'), teacherId: S('teacher-profile-1') }],
    ['buses', 'bus-1', { busNumber: S('BUS-01'), driverId: S(DRIVER), routeId: S('route-1'), studentIds: A('stu-own') }],
    ['buses', 'bus-2', { busNumber: S('BUS-02'), driverId: S(OTHER) }],
    ['routes', 'route-1', { name: S('Route One'), busId: S('bus-1'), driverId: S(DRIVER) }],
    ['students', 'stu-own', { busId: S('bus-1'), parentIds: A('par-1'), classId: S('class-grade-1'), className: S('Grade 1'), status: S('active'), pickupStatus: S('waiting') }],
    ['students', 'stu-other', { busId: S('bus-2'), parentIds: A('par-9'), pickupStatus: S('waiting') }],
    // Pickup/drop-off events. `parentUserIds` is what grants a parent read;
    // `timestamp` is required by the app's orderBy query.
    ['pickup_dropoff', 'pd-child', { studentId: S('stu-own'), status: S('picked_up'), timestamp: T('2026-10-01T07:12:00Z'), parentUserIds: A(PARENT) }],
    ['pickup_dropoff', 'pd-older', { studentId: S('stu-own'), status: S('dropped_off'), timestamp: T('2026-09-30T16:05:00Z'), parentUserIds: A(PARENT) }],
    ['pickup_dropoff', 'pd-other', { studentId: S('stu-other'), status: S('picked_up'), timestamp: T('2026-10-01T07:20:00Z'), parentUserIds: A('other-parent-uid') }],
    // Legacy/partial record written before `parentUserIds` existed.
    ['pickup_dropoff', 'pd-legacy', { studentId: S('stu-own'), status: S('picked_up'), timestamp: T('2026-09-01T07:00:00Z') }],
  ];
  for (const [c, id, fields] of seed) {
    // Rules are loaded at startup, so seed through the emulator's owner
    // credential (bypasses rules). REST create = POST to the collection.
    let r = await req('POST', `${COLL(c)}?documentId=${id}`, { fields }, 'owner');
    if (r.status !== 200) r = await req('POST', `${COLL(c)}?documentId=${id}`, { fields }, null);
    if (r.status !== 200) console.log(`  seed FAILED ${c}/${id} -> ${r.status} ${JSON.stringify(r.body).slice(0, 140)}`);
  }
  const seeded = await req('GET', DOC('users', DRIVER), null, 'owner');
  console.log('seed check users/' + DRIVER + ' -> ' + seeded.status + '\n');

  // 2. Rules were supplied to the emulator at startup via --rules.
  console.log('RULES RESULT MATRIX (real rules engine)\n');

  const tok = {
    admin: fakeToken(ADMIN), driver: fakeToken(DRIVER), d2: fakeToken(DRIVER_NODOC),
    d3: fakeToken(DRIVER_NOUSER), parent: fakeToken(PARENT), teacher: fakeToken(TEACHER),
  };


  // Baseline - proves fake tokens are honoured by the engine at all.
  check('BASELINE admin reads own /users doc', (await req('GET', DOC('users', ADMIN), null, tok.admin)).status, 200);
  check('unknown uid cannot read a driver doc', (await req('GET', DOC('drivers', DRIVER), null, fakeToken('nobody'))).status, 403);

  // The core driver fixes.
  check('driver reads own /drivers/{uid}   <-- the fix', (await req('GET', DOC('drivers', DRIVER), null, tok.driver)).status, 200);
  check('driver w/o profile doc -> 404 not 403   <-- fix', (await req('GET', DOC('drivers', DRIVER_NODOC), null, tok.d2)).status, 404);
  check('auth user w/o /users doc: own id -> 404, no crash', (await req('GET', DOC('drivers', DRIVER_NOUSER), null, tok.d3)).status, 404);
  check('auth user w/o /users doc cannot read others', (await req('GET', DOC('drivers', DRIVER), null, tok.d3)).status, 403);
  check('driver cannot read another driver doc', (await req('GET', DOC('drivers', OTHER), null, tok.driver)).status, 403);
  check('parent cannot read a driver doc', (await req('GET', DOC('drivers', DRIVER), null, tok.parent)).status, 403);
  check('legacy userId-keyed doc readable by owner', (await req('GET', DOC('drivers', 'legacy-1'), null, tok.driver)).status, 200);

  // Queries stay admin-only - why the app moved to .doc(uid).
  check('driver CANNOT list /drivers (query)', (await req('GET', COLL('drivers'), null, tok.driver)).status, 403);
  check('admin CAN list /drivers', (await req('GET', COLL('drivers'), null, tok.admin)).status, 200);
  check('admin CAN read any driver doc', (await req('GET', DOC('drivers', OTHER), null, tok.admin)).status, 200);
  check('admin CAN write a driver doc', (await req('PATCH', `${DOC('drivers', 'new-drv')}?updateMask.fieldPaths=name`, { fields: { name: { stringValue: 'New' } } }, tok.admin)).status, 200);
  check('driver CANNOT write own driver doc', (await req('PATCH', `${DOC('drivers', DRIVER)}?updateMask.fieldPaths=name`, { fields: { name: { stringValue: 'X' } } }, tok.driver)).status, 403);
  check('driver cannot escalate own role', (await req('PATCH', `${DOC('users', DRIVER)}?updateMask.fieldPaths=role`, { fields: { role: { stringValue: 'admin' } } }, tok.driver)).status, 403);

  // Driver trip flow: start_trip uses .add() (signed-in driver) and end_trip
  // updates the doc it created (driverId == uid).
  const tripMask = (id) => `${DOC('bus_trips', id)}?updateMask.fieldPaths=status`;
  check('driver CREATES a trip (.add path)', (await req('POST', `${COLL('bus_trips')}?documentId=trip-d1`, { fields: { driverId: { stringValue: DRIVER }, status: { stringValue: 'active' } } }, tok.driver)).status, 200);
  check('driver COMPLETES own trip', (await req('PATCH', tripMask('trip-d1'), { fields: { status: { stringValue: 'completed' } } }, tok.driver)).status, 200);
  check("driver CANNOT edit another driver's trip", (await req('PATCH', tripMask('trip-other'), { fields: { status: { stringValue: 'completed' } } }, tok.driver)).status, 403);


  // ---- Pickup / drop-off ------------------------------------------------
  // What lets a parent see when the child was picked in and dropped out.
  // The driver's recordEvent(): append the event, then mirror the status.
  check('driver CREATES a pickup_dropoff event (.add)', (await req('POST', `${COLL('pickup_dropoff')}?documentId=pd-new`, { fields: { studentId: S('stu-own'), status: S('on_bus'), timestamp: T('2026-10-01T07:30:00Z'), parentUserIds: A(PARENT) } }, tok.driver)).status, 200);
  check('driver CAN read a pickup_dropoff event', (await req('GET', DOC('pickup_dropoff', 'pd-child'), null, tok.driver)).status, 200);
  check('admin CAN read a pickup_dropoff event', (await req('GET', DOC('pickup_dropoff', 'pd-child'), null, tok.admin)).status, 200);
  check("parent CAN read own child's event   <-- the fix", (await req('GET', DOC('pickup_dropoff', 'pd-child'), null, tok.parent)).status, 200);
  check("parent CANNOT read another child's event", (await req('GET', DOC('pickup_dropoff', 'pd-other'), null, tok.parent)).status, 403);
  check('event without parentUserIds stays hidden', (await req('GET', DOC('pickup_dropoff', 'pd-legacy'), null, tok.parent)).status, 403);
  // A denied read and a rule-evaluation error are both reported as 403, so the
  // "rules do not crash" property is proved by contrast: the driver (allowed
  // branch) reading a missing event gets a clean 404, not a blanket denial.
  check('missing doc, parent -> denied (403)', (await req('GET', DOC('pickup_dropoff', 'pd-nope'), null, tok.parent)).status, 403);
  check('missing doc, driver -> clean 404, no crash', (await req('GET', DOC('pickup_dropoff', 'pd-nope'), null, tok.driver)).status, 404);
  check('parent CANNOT create a pickup_dropoff event', (await req('POST', `${COLL('pickup_dropoff')}?documentId=pd-parent`, { fields: { studentId: S('stu-own'), status: S('picked_up'), parentUserIds: A(PARENT) } }, tok.parent)).status, 403);
  check('auth user w/o /users doc CANNOT read events', (await req('GET', DOC('pickup_dropoff', 'pd-child'), null, tok.d3)).status, 403);
  check('driver CANNOT delete a pickup_dropoff event', (await req('DELETE', DOC('pickup_dropoff', 'pd-child'), null, tok.driver)).status, 403);

  // The status mirror written by recordEvent, scoped to the driver's own bus.
  check('driver CAN stamp pickupStatus on own bus student', (await req('PATCH', `${DOC('students', 'stu-own')}?updateMask.fieldPaths=pickupStatus`, { fields: { pickupStatus: { stringValue: 'picked_up' } } }, tok.driver)).status, 200);
  check("driver CANNOT stamp another bus's student", (await req('PATCH', `${DOC('students', 'stu-other')}?updateMask.fieldPaths=pickupStatus`, { fields: { pickupStatus: { stringValue: 'picked_up' } } }, tok.driver)).status, 403);

  // ---- The app's real query path -----------------------------------------
  // The parent timeline runs `where(studentId == ..).orderBy(timestamp desc)`,
  // i.e. a `list`, not a `get`. Rules are evaluated per candidate document, so
  // this is the assertion that proves parents can actually load the timeline.
  // `parentUid` adds the filter the app itself applies; omitting it reproduces
  // an unconstrained client query.
  const childQuery = (studentId, parentUid) => {
    const filters = [{
      field: { fieldPath: 'studentId' },
      op: 'EQUAL',
      value: { stringValue: studentId },
    }];
    if (parentUid) {
      filters.push({
        field: { fieldPath: 'parentUserIds' },
        op: 'ARRAY_CONTAINS',
        value: { stringValue: parentUid },
      });
    }
    return {
      structuredQuery: {
        from: [{ collectionId: 'pickup_dropoff' }],
        where: filters.length === 1
          ? { fieldFilter: filters[0] }
          : {
            compositeFilter: {
              op: 'AND',
              filters: filters.map((f) => ({ fieldFilter: f })),
            },
          },
        orderBy: [
          { field: { fieldPath: 'timestamp' }, direction: 'DESCENDING' },
        ],
      },
    };
  };
  const runQuery = async (studentId, token, parentUid) => {
    const r = await req('POST', `/v1/projects/${PROJ}/databases/(default)/documents:runQuery`, childQuery(studentId, parentUid), token);
    const body = Array.isArray(r.body) ? r.body : [];
    return {
      status: body.some((e) => e.error) ? 403 : r.status,
      docs: body.filter((e) => e.document).length,
    };
  };

  const ownConstrained = await runQuery('stu-own', tok.parent, PARENT);
  check('parent QUERY (constrained) own events allowed', ownConstrained.status, 200);
  check('parent QUERY (constrained) returns own events', ownConstrained.docs, 3);
  check("parent QUERY (constrained) other child -> empty", (await runQuery('stu-other', tok.parent, PARENT)).docs, 0);
  // Why the app must constrain the query: rules are evaluated per candidate
  // document, not as a filter, so one event lacking `parentUserIds` would reject
  // an unconstrained query for the whole child.
  check('parent QUERY unconstrained is denied', (await runQuery('stu-own', tok.parent)).status, 403);
  check('driver QUERY (unconstrained) is allowed', (await runQuery('stu-own', tok.driver)).status, 200);

  // ---- Cross-role class, bus, student, attendance and parent workflow ----
  // The fixtures above represent the documents created by the admin forms.
  // Verify the same links each portal uses, then perform teacher/driver writes
  // through their actual role credentials and read those records as the parent.
  const simpleQuery = async (collection, field, op, value, token) => {
    const response = await req(
      'POST',
      `/v1/projects/${PROJ}/databases/(default)/documents:runQuery`,
      {
        structuredQuery: {
          from: [{ collectionId: collection }],
          where: {
            fieldFilter: {
              field: { fieldPath: field },
              op,
              value: { stringValue: value },
            },
          },
        },
      },
      token,
    );
    const rows = Array.isArray(response.body) ? response.body : [];
    return {
      status: rows.some((row) => row.error) ? 403 : response.status,
      docs: rows.filter((row) => row.document).length,
    };
  };

  check('driver reads admin-assigned bus', (await req('GET', DOC('buses', 'bus-1'), null, tok.driver)).status, 200);
  const busLocationUpdate = await req(
    'PATCH',
    `${DOC('buses', 'bus-1')}?updateMask.fieldPaths=currentLatitude&updateMask.fieldPaths=currentLongitude&updateMask.fieldPaths=lastLocationUpdate&updateMask.fieldPaths=status&updateMask.fieldPaths=tripId`,
    { fields: {
      currentLatitude: { doubleValue: 9.03 },
      currentLongitude: { doubleValue: 38.74 },
      lastLocationUpdate: T('2026-10-02T08:00:00Z'),
      status: S('on_route'),
      tripId: S('trip-d1'),
    } },
    tok.driver,
  );
  check('driver updates GPS and trip state on assigned bus', busLocationUpdate.status, 200);
  const locationWrite = await req(
    'POST',
    `${COLL('bus_locations')}?documentId=bus-1`,
    { fields: {
      busId: S('bus-1'),
      driverId: S(DRIVER),
      latitude: { doubleValue: 9.03 },
      longitude: { doubleValue: 38.74 },
      timestamp: T('2026-10-02T08:00:00Z'),
      tripId: S('trip-d1'),
      tripStatus: S('active'),
    } },
    tok.driver,
  );
  check('driver publishes location for assigned bus', locationWrite.status, 200);
  check('driver cannot publish location for another bus', (await req(
    'PATCH',
    `${DOC('bus_locations', 'bus-1')}?updateMask.fieldPaths=latitude`,
    { fields: { latitude: { doubleValue: 9.1 } } },
    tok.d2,
  )).status, 403);
  check('driver sees students assigned to bus', (await simpleQuery('students', 'busId', 'EQUAL', 'bus-1', tok.driver)).docs, 1);
  check('teacher sees assigned class', (await simpleQuery('classes', 'teacherId', 'EQUAL', 'teacher-profile-1', tok.teacher)).docs, 1);
  check('teacher sees students in that class', (await simpleQuery('students', 'classId', 'EQUAL', 'class-grade-1', tok.teacher)).docs, 1);

  const attendanceWrite = await req(
    'POST',
    `${COLL('attendance')}?documentId=stu-own_20261001_workflow`,
    {
      fields: {
        studentId: S('stu-own'),
        studentName: S('Amina'),
        classId: S('class-grade-1'),
        className: S('Grade 1'),
        status: S('present'),
        teacherId: S(TEACHER),
        date: T('2026-10-01T00:00:00Z'),
        time: S('08:00 AM'),
        createdAt: T('2026-10-01T08:00:00Z'),
      },
    },
    tok.teacher,
  );
  check('teacher records student attendance', attendanceWrite.status, 200);
  check('parent reads child attendance', (await simpleQuery('attendance', 'studentId', 'EQUAL', 'stu-own', tok.parent)).docs, 1);
  check('parent profile lists assigned child', (await simpleQuery('parents', 'userId', 'EQUAL', PARENT, tok.parent)).docs, 1);
  check('parent-linked child query finds assigned student', (await simpleQuery('students', 'parentIds', 'ARRAY_CONTAINS', 'par-1', tok.parent)).docs, 1);

  const pickupWrite = await req(
    'POST',
    `${COLL('pickup_dropoff')}?documentId=pd-workflow`,
    {
      fields: {
        studentId: S('stu-own'),
        studentName: S('Amina'),
        busId: S('bus-1'),
        status: S('picked_up'),
        eventType: S('pickup'),
        tripType: S('morning'),
        timestamp: T('2026-10-01T07:12:00Z'),
        parentUserIds: A(PARENT),
      },
    },
    tok.driver,
  );
  check('driver records pickup event for assigned student', pickupWrite.status, 200);
  const parentWorkflowEvents = await runQuery('stu-own', tok.parent, PARENT);
  check('parent reads the child pickup timeline', parentWorkflowEvents.status, 200);
  check('parent timeline includes the new pickup event', parentWorkflowEvents.docs, 4);

  const bad = results.filter((r) => !r.ok);
  console.log(`\n${results.length - bad.length}/${results.length} passed` + (bad.length ? ` - ${bad.length} FAILED` : ''));
  process.exit(bad.length ? 1 : 0);
})();

