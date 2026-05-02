/**
 * Camada de dados — Supabase.
 *
 * Usa a service_role key (backend only): bypass de RLS, acesso total.
 * NUNCA exponha SUPABASE_SERVICE_ROLE_KEY no frontend/Flutter.
 */

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
);

// ── Users ─────────────────────────────────────────────────────────────────────

/**
 * Busca ou cria o registro do usuário.
 * Retorna { subscription_status, subscription_renews_at, preapproval_id }.
 */
async function getOrCreateUser(firebaseUid, email = null) {
  // Upsert: cria na primeira vez, não sobrescreve em visitas subsequentes.
  const { error: upsertError } = await supabase.from('users').upsert(
    { firebase_uid: firebaseUid, email },
    { onConflict: 'firebase_uid', ignoreDuplicates: true }
  );
  if (upsertError) throw new Error(`getOrCreateUser upsert: ${upsertError.message}`);

  const { data, error } = await supabase
    .from('users')
    .select('subscription_status, subscription_renews_at, preapproval_id')
    .eq('firebase_uid', firebaseUid)
    .single();

  if (error) throw new Error(`getOrCreateUser select: ${error.message}`);
  return data;
}

/**
 * Busca o firebase_uid pelo email — usado pelo webhook do MP quando não há
 * external_reference (fluxo de assinatura via init_point do plano).
 */
async function getUserByEmail(email) {
  const { data, error } = await supabase
    .from('users')
    .select('firebase_uid')
    .eq('email', email)
    .maybeSingle();

  if (error) throw new Error(`getUserByEmail: ${error.message}`);
  return data?.firebase_uid ?? null;
}

/**
 * Atualiza o status de assinatura após webhook do Mercado Pago.
 * status: 'trial' | 'active' | 'past_due' | 'canceled' | 'expired'
 */
async function updateUserSubscription(firebaseUid, { status, preapprovalId, nextBillingDate }) {
  const { error } = await supabase
    .from('users')
    .update({
      subscription_status: status,
      preapproval_id: preapprovalId ?? null,
      subscription_renews_at: nextBillingDate ?? null,
    })
    .eq('firebase_uid', firebaseUid);

  if (error) throw new Error(`updateUserSubscription: ${error.message}`);
}

/**
 * Exclui o usuário e todos os seus dados em cascata (LGPD Art. 18).
 * trips e speed_records têm ON DELETE CASCADE no schema.
 */
async function deleteUser(firebaseUid) {
  const { error } = await supabase
    .from('users')
    .delete()
    .eq('firebase_uid', firebaseUid);

  if (error) throw new Error(`deleteUser: ${error.message}`);
}

// ── Trips ─────────────────────────────────────────────────────────────────────

async function createTrip(firebaseUid, { id, startedAt, startAddress }) {
  const { data, error } = await supabase
    .from('trips')
    .insert({
      id,
      user_id: firebaseUid,
      started_at: startedAt,
      start_address: startAddress ?? null,
    })
    .select()
    .single();

  if (error) throw new Error(`createTrip: ${error.message}`);
  return data;
}

async function endTrip(tripId, { endedAt, avgSpeedKmh, maxSpeedKmh, distanceKm, endAddress }) {
  const { data, error } = await supabase
    .from('trips')
    .update({
      ended_at: endedAt,
      avg_speed_kmh: avgSpeedKmh,
      max_speed_kmh: maxSpeedKmh,
      distance_km: distanceKm,
      end_address: endAddress ?? null,
    })
    .eq('id', tripId)
    .select()
    .single();

  if (error) throw new Error(`endTrip: ${error.message}`);
  return data;
}

async function listTrips(firebaseUid, { limit = 20, offset = 0 } = {}) {
  const { data, error } = await supabase
    .from('trips')
    .select('*')
    .eq('user_id', firebaseUid)
    .order('started_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw new Error(`listTrips: ${error.message}`);
  return data;
}

async function getTripWithRecords(tripId, firebaseUid) {
  const [tripResult, recordsResult] = await Promise.all([
    supabase.from('trips').select('*').eq('id', tripId).eq('user_id', firebaseUid).single(),
    supabase
      .from('speed_records')
      .select('recorded_at, speed_kmh, max_speed_kmh, accuracy_m, location')
      .eq('trip_id', tripId)
      .order('recorded_at', { ascending: true }),
  ]);

  if (tripResult.error) throw new Error(`getTripWithRecords trip: ${tripResult.error.message}`);
  if (recordsResult.error) throw new Error(`getTripWithRecords records: ${recordsResult.error.message}`);

  return { trip: tripResult.data, records: recordsResult.data };
}

async function deleteTrip(tripId, firebaseUid) {
  // Exclui speed_records primeiro (sem CASCADE na FK lógica do schema).
  await supabase.from('speed_records').delete().eq('trip_id', tripId);

  const { error } = await supabase
    .from('trips')
    .delete()
    .eq('id', tripId)
    .eq('user_id', firebaseUid);

  if (error) throw new Error(`deleteTrip: ${error.message}`);
}

// ── Speed records ─────────────────────────────────────────────────────────────

/**
 * Insere um lote de registros de velocidade.
 * records: Array<{ tripId, userId, recordedAt, speedKmh, maxSpeedKmh, lat, lon, accuracyM }>
 */
async function insertSpeedRecords(records) {
  const rows = records.map((r) => ({
    trip_id: r.tripId,
    user_id: r.userId,
    recorded_at: r.recordedAt,
    speed_kmh: r.speedKmh,
    max_speed_kmh: r.maxSpeedKmh,
    // PostGIS GEOGRAPHY point: ST_MakePoint(longitude, latitude)
    location: r.lat != null && r.lon != null
      ? `SRID=4326;POINT(${r.lon} ${r.lat})`
      : null,
    accuracy_m: r.accuracyM ?? null,
  }));

  const { error } = await supabase.from('speed_records').insert(rows);
  if (error) throw new Error(`insertSpeedRecords: ${error.message}`);
}

// ── Report signatures (Fase 1) ────────────────────────────────────────────────

/**
 * Salva os metadados e a assinatura digital de um relatório exportado.
 */
async function storeReportSignature({
  reportId,
  userId,
  tripIds,
  recordCount,
  recordHashes,
  canonical,
  signature,
  generatedAt,
}) {
  const { error } = await supabase.from('report_signatures').insert({
    id: reportId,
    user_id: userId,
    trip_ids: tripIds,
    record_count: recordCount,
    record_hashes: recordHashes,
    canonical,
    signature,
    generated_at: generatedAt,
  });

  if (error) throw new Error(`storeReportSignature: ${error.message}`);
}

/**
 * Busca os dados de verificação de um relatório pelo ID.
 * Retorna null se não encontrado.
 */
async function getReportSignature(reportId) {
  const { data, error } = await supabase
    .from('report_signatures')
    .select('id, user_id, trip_ids, record_count, canonical, signature, generated_at')
    .eq('id', reportId)
    .maybeSingle();

  if (error) throw new Error(`getReportSignature: ${error.message}`);
  return data;
}

module.exports = {
  getOrCreateUser,
  getUserByEmail,
  updateUserSubscription,
  deleteUser,
  createTrip,
  endTrip,
  listTrips,
  getTripWithRecords,
  deleteTrip,
  insertSpeedRecords,
  storeReportSignature,
  getReportSignature,
};
