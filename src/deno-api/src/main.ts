// SPDX-License-Identifier: MIT OR AGPL-3.0
// VEDS API - Deno HTTP Server Entry Point

const VERSION = '0.1.0';

// =============================================================================
// CONFIGURATION (Explicit env vars required)
// =============================================================================

interface Config {
  port: number;
  host: string;
  surrealdbUrl: string;
  surrealdbUser: string;
  surrealdbPass: string;
  xtdbUrl: string;
  dragonflyUrl: string;
  dragonflyPass: string;
  optimizerUrl: string;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    console.error(`FATAL: Required environment variable ${name} is not set`);
    Deno.exit(1);
  }
  return value;
}

function loadConfig(): Config {
  return {
    port: parseInt(Deno.env.get('PORT') || '4000', 10),
    host: Deno.env.get('HOST') || '0.0.0.0',
    surrealdbUrl: requireEnv('SURREALDB_URL'),
    surrealdbUser: requireEnv('SURREALDB_USER'),
    surrealdbPass: requireEnv('SURREALDB_PASS'),
    xtdbUrl: requireEnv('XTDB_URL'),
    dragonflyUrl: requireEnv('DRAGONFLY_URL'),
    dragonflyPass: requireEnv('DRAGONFLY_PASS'),
    optimizerUrl: requireEnv('OPTIMIZER_URL'),
  };
}

// =============================================================================
// DATABASE CLIENTS
// =============================================================================

class SurrealDBClient {
  private url: string;
  private user: string;
  private pass: string;
  private connected = false;

  constructor(url: string, user: string, pass: string) {
    this.url = url.replace('ws://', 'http://').replace('wss://', 'https://');
    this.user = user;
    this.pass = pass;
  }

  async connect(): Promise<void> {
    // Test connection
    const response = await fetch(`${this.url}/health`);
    if (!response.ok) {
      throw new Error(`SurrealDB health check failed: ${response.status}`);
    }
    this.connected = true;
    console.log('Connected to SurrealDB');
  }

  async query<T>(sql: string, vars?: Record<string, unknown>): Promise<T[]> {
    const response = await fetch(`${this.url}/sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'NS': 'veds',
        'DB': 'production',
        'Authorization': `Basic ${btoa(`${this.user}:${this.pass}`)}`,
      },
      body: vars ? JSON.stringify({ sql, vars }) : sql,
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`SurrealDB query failed: ${response.status} - ${text}`);
    }

    const results = await response.json();
    // SurrealDB returns array of results, one per statement
    if (Array.isArray(results) && results.length > 0) {
      const first = results[0];
      if (first.status === 'ERR') {
        throw new Error(`SurrealDB error: ${first.detail}`);
      }
      return first.result || [];
    }
    return [];
  }

  isConnected(): boolean {
    return this.connected;
  }
}

class XTDBClient {
  private url: string;
  private connected = false;

  constructor(url: string) {
    this.url = url;
  }

  async connect(): Promise<void> {
    const response = await fetch(`${this.url}/status`);
    if (!response.ok) {
      throw new Error(`XTDB health check failed: ${response.status}`);
    }
    this.connected = true;
    console.log('Connected to XTDB');
  }

  async query(query: string): Promise<unknown[]> {
    const response = await fetch(`${this.url}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/edn',
        'Accept': 'application/json',
      },
      body: query,
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`XTDB query failed: ${response.status} - ${text}`);
    }

    return await response.json();
  }

  async put(doc: Record<string, unknown>): Promise<void> {
    const response = await fetch(`${this.url}/tx`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ txOps: [['put', doc]] }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`XTDB put failed: ${response.status} - ${text}`);
    }
  }

  isConnected(): boolean {
    return this.connected;
  }
}

class DragonflyClient {
  private url: string;
  private pass: string;
  private connected = false;

  constructor(url: string, pass: string) {
    // Parse redis:// URL
    this.url = url.replace('redis://', '');
    this.pass = pass;
  }

  async connect(): Promise<void> {
    // For now, we'll assume connection works - Deno doesn't have native Redis
    // In production, use a Redis library
    this.connected = true;
    console.log('Dragonfly client initialized (HTTP mode)');
  }

  isConnected(): boolean {
    return this.connected;
  }
}

// =============================================================================
// gRPC CLIENT FOR OPTIMIZER
// =============================================================================

interface OptimizeRequest {
  shipmentId: string;
  originPort: string;
  destinationPort: string;
  weightKg: number;
  volumeM3: number;
  pickupAfter: string;
  deliverBy: string;
  maxCostUsd?: number;
  maxCarbonKg?: number;
  minLaborScore?: number;
  allowedModes: string[];
  excludedCarriers: string[];
  maxRoutes: number;
  maxSegments: number;
  costWeight: number;
  timeWeight: number;
  carbonWeight: number;
  laborWeight: number;
}

interface Route {
  routeId: string;
  segments: Segment[];
  totalCostUsd: number;
  totalTimeHours: number;
  totalCarbonKg: number;
  totalDistanceKm: number;
  laborScore: number;
  paretoRank: number;
  paretoOptimal: boolean;
  weightedScore: number;
  constraintResults: ConstraintResult[];
}

interface Segment {
  segmentId: string;
  sequence: number;
  fromNode: string;
  toNode: string;
  mode: string;
  carrierCode: string;
  distanceKm: number;
  costUsd: number;
  transitHours: number;
  carbonKg: number;
  carrierWageCents: number;
  departureTime: string;
  arrivalTime: string;
}

interface ConstraintResult {
  constraintId: string;
  constraintType: string;
  passed: boolean;
  isHard: boolean;
  score: number;
  message: string;
}

interface OptimizeResponse {
  success: boolean;
  errorMessage: string;
  routes: Route[];
  optimizationTimeMs: number;
  candidatesEvaluated: number;
}

interface GraphStatus {
  nodeCount: number;
  edgeCount: number;
  lastLoaded: string;
  loadTimeMs: number;
  modeCounts: Record<string, number>;
}

class OptimizerClient {
  private url: string;
  private connected = false;

  constructor(url: string) {
    // Convert gRPC URL to HTTP for JSON-over-HTTP fallback
    // The Rust optimizer exposes both gRPC (50051) and HTTP metrics (8090)
    // For MVP, we use HTTP/JSON; gRPC requires protobuf compilation
    this.url = url.replace(':50051', ':8090');
  }

  async connect(): Promise<void> {
    try {
      const response = await fetch(`${this.url}/health`);
      if (response.ok) {
        this.connected = true;
        console.log('Connected to Optimizer (HTTP mode)');
      }
    } catch {
      console.warn('Optimizer not available, will retry on requests');
    }
  }

  async optimize(request: OptimizeRequest): Promise<OptimizeResponse> {
    // For MVP: Call optimizer's HTTP endpoint
    // Full gRPC would require @grpc/grpc-js + proto compilation
    const response = await fetch(`${this.url}/optimize`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      return {
        success: false,
        errorMessage: `Optimizer error: ${response.status}`,
        routes: [],
        optimizationTimeMs: 0,
        candidatesEvaluated: 0,
      };
    }

    return await response.json();
  }

  async getGraphStatus(): Promise<GraphStatus> {
    const response = await fetch(`${this.url}/graph/status`);
    if (!response.ok) {
      throw new Error(`Graph status failed: ${response.status}`);
    }
    return await response.json();
  }

  async reloadGraph(): Promise<{ success: boolean; message: string; loadTimeMs: number }> {
    const response = await fetch(`${this.url}/graph/reload`, { method: 'POST' });
    if (!response.ok) {
      return { success: false, message: `Reload failed: ${response.status}`, loadTimeMs: 0 };
    }
    return await response.json();
  }

  isConnected(): boolean {
    return this.connected;
  }
}

// =============================================================================
// APPLICATION STATE
// =============================================================================

interface AppState {
  config: Config;
  surreal: SurrealDBClient;
  xtdb: XTDBClient;
  dragonfly: DragonflyClient;
  optimizer: OptimizerClient;
}

// =============================================================================
// CORS & RESPONSE HELPERS
// =============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Request-ID',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function errorResponse(error: string, message: string, status: number): Response {
  return jsonResponse({ error, message, statusCode: status }, status);
}

// =============================================================================
// ROUTE HANDLERS
// =============================================================================

async function handleHealth(state: AppState): Promise<Response> {
  const services: Record<string, string> = {
    surrealdb: state.surreal.isConnected() ? 'connected' : 'disconnected',
    xtdb: state.xtdb.isConnected() ? 'connected' : 'disconnected',
    dragonfly: state.dragonfly.isConnected() ? 'connected' : 'disconnected',
    optimizer: state.optimizer.isConnected() ? 'connected' : 'disconnected',
  };

  return jsonResponse({
    status: 'healthy',
    version: VERSION,
    timestamp: new Date().toISOString(),
    services,
  });
}

async function handleListShipments(
  state: AppState,
  query: URLSearchParams
): Promise<Response> {
  const limit = parseInt(query.get('limit') || '20', 10);
  const offset = parseInt(query.get('offset') || '0', 10);

  try {
    const shipments = await state.surreal.query(
      `SELECT * FROM shipment ORDER BY created_at DESC LIMIT ${limit} START ${offset}`
    );
    const countResult = await state.surreal.query<{ count: number }>(
      'SELECT count() FROM shipment GROUP ALL'
    );
    const total = countResult[0]?.count || 0;

    return jsonResponse({ data: shipments, total, limit, offset });
  } catch (err) {
    console.error('List shipments error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleGetShipment(
  state: AppState,
  params: Record<string, string>
): Promise<Response> {
  const { id } = params;

  try {
    const results = await state.surreal.query(
      `SELECT * FROM shipment WHERE id = shipment:${id} OR external_id = '${id}'`
    );

    if (results.length === 0) {
      return errorResponse('not_found', `Shipment ${id} not found`, 404);
    }

    return jsonResponse(results[0]);
  } catch (err) {
    console.error('Get shipment error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleCreateShipment(
  state: AppState,
  req: Request
): Promise<Response> {
  try {
    const body = await req.json();

    // Validate required fields
    const required = ['customerId', 'origin', 'destination', 'weightKg'];
    for (const field of required) {
      if (!(field in body)) {
        return errorResponse('validation_error', `Missing required field: ${field}`, 400);
      }
    }

    const id = crypto.randomUUID();
    const results = await state.surreal.query(`
      CREATE shipment:${id} SET
        external_id = '${body.externalId || ''}',
        customer_id = '${body.customerId}',
        origin = transport_node:${body.origin},
        destination = transport_node:${body.destination},
        weight_kg = ${body.weightKg},
        volume_cbm = ${body.volumeCbm || 'NULL'},
        commodity_code = '${body.commodityCode || ''}',
        commodity_desc = '${body.commodityDesc || ''}',
        hazmat_class = ${body.hazmatClass ? `'${body.hazmatClass}'` : 'NULL'},
        temperature_controlled = ${body.temperatureControlled || false},
        earliest_pickup = '${body.earliestPickup || new Date().toISOString()}',
        latest_delivery = '${body.latestDelivery || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()}',
        priority = '${body.priority || 'normal'}',
        status = 'pending',
        max_cost_usd = ${body.maxCostUsd || 'NULL'},
        max_carbon_kg = ${body.maxCarbonKg || 'NULL'}
    `);

    return jsonResponse(results[0], 201);
  } catch (err) {
    console.error('Create shipment error:', err);
    if (err instanceof SyntaxError) {
      return errorResponse('bad_request', 'Invalid JSON body', 400);
    }
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleOptimizeRoutes(
  state: AppState,
  params: Record<string, string>,
  req: Request
): Promise<Response> {
  const { shipmentId } = params;

  try {
    const body = await req.json();

    // Get shipment details if not provided
    let shipment: Record<string, unknown> | null = null;
    if (!body.originPort || !body.destinationPort) {
      const results = await state.surreal.query(
        `SELECT * FROM shipment:${shipmentId} FETCH origin, destination`
      );
      if (results.length > 0) {
        shipment = results[0] as Record<string, unknown>;
      }
    }

    const optimizeRequest: OptimizeRequest = {
      shipmentId,
      originPort: body.originPort || (shipment?.origin as Record<string, string>)?.code || '',
      destinationPort: body.destinationPort || (shipment?.destination as Record<string, string>)?.code || '',
      weightKg: body.weightKg || (shipment?.weight_kg as number) || 1000,
      volumeM3: body.volumeM3 || (shipment?.volume_cbm as number) || 1,
      pickupAfter: body.pickupAfter || (shipment?.earliest_pickup as string) || new Date().toISOString(),
      deliverBy: body.deliverBy || (shipment?.latest_delivery as string) || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      maxCostUsd: body.maxCostUsd || (shipment?.max_cost_usd as number),
      maxCarbonKg: body.maxCarbonKg || (shipment?.max_carbon_kg as number),
      minLaborScore: body.minLaborScore,
      allowedModes: body.allowedModes || [],
      excludedCarriers: body.excludedCarriers || [],
      maxRoutes: body.maxRoutes || 10,
      maxSegments: body.maxSegments || 8,
      costWeight: body.costWeight || 0.4,
      timeWeight: body.timeWeight || 0.3,
      carbonWeight: body.carbonWeight || 0.2,
      laborWeight: body.laborWeight || 0.1,
    };

    const result = await state.optimizer.optimize(optimizeRequest);

    // Store routes in SurrealDB
    if (result.success && result.routes.length > 0) {
      for (const route of result.routes) {
        await state.surreal.query(`
          CREATE route:${route.routeId} SET
            shipment = shipment:${shipmentId},
            status = 'proposed',
            total_cost_usd = ${route.totalCostUsd},
            total_carbon_kg = ${route.totalCarbonKg},
            total_transit_hours = ${route.totalTimeHours},
            total_distance_km = ${route.totalDistanceKm},
            labor_score = ${route.laborScore},
            pareto_optimal = ${route.paretoOptimal},
            pareto_rank = ${route.paretoRank},
            weighted_score = ${route.weightedScore}
        `);
      }

      // Update shipment status
      await state.surreal.query(
        `UPDATE shipment:${shipmentId} SET status = 'planned'`
      );
    }

    return jsonResponse({
      success: result.success,
      shipmentId,
      routes: result.routes,
      optimizationTimeMs: result.optimizationTimeMs,
      candidatesEvaluated: result.candidatesEvaluated,
    });
  } catch (err) {
    console.error('Optimize routes error:', err);
    if (err instanceof SyntaxError) {
      return errorResponse('bad_request', 'Invalid JSON body', 400);
    }
    return errorResponse('optimizer_error', String(err), 500);
  }
}

async function handleListRoutes(
  state: AppState,
  params: Record<string, string>
): Promise<Response> {
  const { shipmentId } = params;

  try {
    const routes = await state.surreal.query(
      `SELECT * FROM route WHERE shipment = shipment:${shipmentId} ORDER BY weighted_score ASC`
    );

    return jsonResponse({ shipmentId, data: routes, total: routes.length });
  } catch (err) {
    console.error('List routes error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleSelectRoute(
  state: AppState,
  params: Record<string, string>
): Promise<Response> {
  const { shipmentId, routeId } = params;

  try {
    // Deselect all routes for this shipment
    await state.surreal.query(
      `UPDATE route SET selected = false, status = 'proposed' WHERE shipment = shipment:${shipmentId}`
    );

    // Select the chosen route
    await state.surreal.query(
      `UPDATE route:${routeId} SET selected = true, status = 'accepted'`
    );

    // Update shipment status
    await state.surreal.query(
      `UPDATE shipment:${shipmentId} SET status = 'planned'`
    );

    return jsonResponse({ success: true, shipmentId, routeId, message: 'Route selected' });
  } catch (err) {
    console.error('Select route error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleGraphStatus(state: AppState): Promise<Response> {
  try {
    const status = await state.optimizer.getGraphStatus();
    return jsonResponse(status);
  } catch (err) {
    console.error('Graph status error:', err);
    return errorResponse('optimizer_error', String(err), 500);
  }
}

async function handleReloadGraph(state: AppState): Promise<Response> {
  try {
    const result = await state.optimizer.reloadGraph();
    return jsonResponse(result);
  } catch (err) {
    console.error('Reload graph error:', err);
    return errorResponse('optimizer_error', String(err), 500);
  }
}

async function handleListNodes(
  state: AppState,
  query: URLSearchParams
): Promise<Response> {
  const limit = parseInt(query.get('limit') || '100', 10);
  const offset = parseInt(query.get('offset') || '0', 10);

  try {
    const nodes = await state.surreal.query(
      `SELECT * FROM transport_node WHERE active = true FETCH port, port.country LIMIT ${limit} START ${offset}`
    );
    const countResult = await state.surreal.query<{ count: number }>(
      'SELECT count() FROM transport_node WHERE active = true GROUP ALL'
    );
    const total = countResult[0]?.count || 0;

    return jsonResponse({ data: nodes, total, limit, offset });
  } catch (err) {
    console.error('List nodes error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleListEdges(
  state: AppState,
  query: URLSearchParams
): Promise<Response> {
  const limit = parseInt(query.get('limit') || '100', 10);
  const offset = parseInt(query.get('offset') || '0', 10);
  const mode = query.get('mode');

  try {
    const modeFilter = mode ? `AND mode = '${mode.toUpperCase()}'` : '';
    const edges = await state.surreal.query(
      `SELECT * FROM transport_edge WHERE active = true ${modeFilter} FETCH from_node, to_node, carrier LIMIT ${limit} START ${offset}`
    );
    const countResult = await state.surreal.query<{ count: number }>(
      `SELECT count() FROM transport_edge WHERE active = true ${modeFilter} GROUP ALL`
    );
    const total = countResult[0]?.count || 0;

    return jsonResponse({ data: edges, total, limit, offset, mode });
  } catch (err) {
    console.error('List edges error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleListConstraints(state: AppState): Promise<Response> {
  try {
    const results = await state.xtdb.query(`
      {:find [(pull ?c [*])]
       :where [[?c :constraint/id _]
               [?c :constraint/active? true]]}
    `);

    return jsonResponse({ data: results, total: results.length });
  } catch (err) {
    console.error('List constraints error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleCreateConstraint(
  state: AppState,
  req: Request
): Promise<Response> {
  try {
    const body = await req.json();

    if (!body.name || !body.constraintType) {
      return errorResponse('validation_error', 'name and constraintType are required', 400);
    }

    const id = crypto.randomUUID();
    const doc = {
      'xt/id': `:constraint/${id}`,
      'constraint/id': id,
      'constraint/name': body.name,
      'constraint/type': `:${body.constraintType}`,
      'constraint/description': body.description || '',
      'constraint/hard?': body.isHard ?? true,
      'constraint/active?': true,
      'constraint/priority': body.priority || 100,
      'constraint/params': body.params || {},
      'constraint/datalog-rule': body.datalogRule || null,
      'constraint/created-at': new Date().toISOString(),
    };

    await state.xtdb.put(doc);

    return jsonResponse({ id, ...body }, 201);
  } catch (err) {
    console.error('Create constraint error:', err);
    if (err instanceof SyntaxError) {
      return errorResponse('bad_request', 'Invalid JSON body', 400);
    }
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleGetTracking(
  state: AppState,
  params: Record<string, string>
): Promise<Response> {
  const { shipmentId } = params;

  try {
    const positions = await state.surreal.query(
      `SELECT * FROM position_update WHERE shipment = shipment:${shipmentId} ORDER BY timestamp DESC LIMIT 100`
    );

    return jsonResponse({
      shipmentId,
      positions,
      lastUpdated: positions.length > 0 ? (positions[0] as Record<string, unknown>).timestamp : null,
    });
  } catch (err) {
    console.error('Get tracking error:', err);
    return errorResponse('database_error', String(err), 500);
  }
}

async function handleAddPosition(
  state: AppState,
  params: Record<string, string>,
  req: Request
): Promise<Response> {
  const { shipmentId } = params;

  try {
    const body = await req.json();

    if (body.lat === undefined || body.lon === undefined) {
      return errorResponse('validation_error', 'lat and lon are required', 400);
    }

    const id = crypto.randomUUID();
    const timestamp = new Date().toISOString();

    await state.surreal.query(`
      CREATE position_update:${id} SET
        shipment = shipment:${shipmentId},
        location = { type: 'Point', coordinates: [${body.lon}, ${body.lat}] },
        speed_knots = ${body.speedKnots || 'NULL'},
        heading = ${body.heading || 'NULL'},
        source = '${body.source || 'manual'}',
        timestamp = '${timestamp}'
    `);

    return jsonResponse({
      success: true,
      shipmentId,
      position: { lat: body.lat, lon: body.lon },
      timestamp,
    });
  } catch (err) {
    console.error('Add position error:', err);
    if (err instanceof SyntaxError) {
      return errorResponse('bad_request', 'Invalid JSON body', 400);
    }
    return errorResponse('database_error', String(err), 500);
  }
}

// =============================================================================
// ROUTER
// =============================================================================

interface RouteMatch {
  params: Record<string, string>;
  handler: (state: AppState, req: Request, params: Record<string, string>, query: URLSearchParams) => Promise<Response>;
}

interface Route {
  method: string;
  pattern: RegExp;
  paramNames: string[];
  handler: (state: AppState, req: Request, params: Record<string, string>, query: URLSearchParams) => Promise<Response>;
}

function createRoutes(): Route[] {
  return [
    // Health
    { method: 'GET', pattern: /^\/health$/, paramNames: [], handler: (s) => handleHealth(s) },
    { method: 'GET', pattern: /^\/api\/v1\/health$/, paramNames: [], handler: (s) => handleHealth(s) },

    // Shipments
    { method: 'GET', pattern: /^\/api\/v1\/shipments$/, paramNames: [], handler: (s, _r, _p, q) => handleListShipments(s, q) },
    { method: 'POST', pattern: /^\/api\/v1\/shipments$/, paramNames: [], handler: (s, r) => handleCreateShipment(s, r) },
    { method: 'GET', pattern: /^\/api\/v1\/shipments\/([^/]+)$/, paramNames: ['id'], handler: (s, _r, p) => handleGetShipment(s, p) },

    // Routes
    { method: 'POST', pattern: /^\/api\/v1\/shipments\/([^/]+)\/optimize$/, paramNames: ['shipmentId'], handler: (s, r, p) => handleOptimizeRoutes(s, p, r) },
    { method: 'GET', pattern: /^\/api\/v1\/shipments\/([^/]+)\/routes$/, paramNames: ['shipmentId'], handler: (s, _r, p) => handleListRoutes(s, p) },
    { method: 'POST', pattern: /^\/api\/v1\/shipments\/([^/]+)\/routes\/([^/]+)\/select$/, paramNames: ['shipmentId', 'routeId'], handler: (s, _r, p) => handleSelectRoute(s, p) },

    // Graph
    { method: 'GET', pattern: /^\/api\/v1\/graph\/status$/, paramNames: [], handler: (s) => handleGraphStatus(s) },
    { method: 'POST', pattern: /^\/api\/v1\/graph\/reload$/, paramNames: [], handler: (s) => handleReloadGraph(s) },
    { method: 'GET', pattern: /^\/api\/v1\/nodes$/, paramNames: [], handler: (s, _r, _p, q) => handleListNodes(s, q) },
    { method: 'GET', pattern: /^\/api\/v1\/edges$/, paramNames: [], handler: (s, _r, _p, q) => handleListEdges(s, q) },

    // Constraints
    { method: 'GET', pattern: /^\/api\/v1\/constraints$/, paramNames: [], handler: (s) => handleListConstraints(s) },
    { method: 'POST', pattern: /^\/api\/v1\/constraints$/, paramNames: [], handler: (s, r) => handleCreateConstraint(s, r) },

    // Tracking
    { method: 'GET', pattern: /^\/api\/v1\/tracking\/([^/]+)$/, paramNames: ['shipmentId'], handler: (s, _r, p) => handleGetTracking(s, p) },
    { method: 'POST', pattern: /^\/api\/v1\/tracking\/([^/]+)\/positions$/, paramNames: ['shipmentId'], handler: (s, r, p) => handleAddPosition(s, p, r) },
  ];
}

function matchRoute(routes: Route[], method: string, pathname: string): RouteMatch | null {
  for (const route of routes) {
    if (route.method !== method) continue;
    const match = pathname.match(route.pattern);
    if (match) {
      const params: Record<string, string> = {};
      route.paramNames.forEach((name, i) => {
        params[name] = match[i + 1];
      });
      return { params, handler: route.handler };
    }
  }
  return null;
}

// =============================================================================
// MAIN
// =============================================================================

async function main() {
  console.log(`VEDS API v${VERSION}`);
  console.log('Loading configuration...');

  const config = loadConfig();
  console.log(`Config loaded: port=${config.port}, host=${config.host}`);

  // Initialize clients
  const surreal = new SurrealDBClient(config.surrealdbUrl, config.surrealdbUser, config.surrealdbPass);
  const xtdb = new XTDBClient(config.xtdbUrl);
  const dragonfly = new DragonflyClient(config.dragonflyUrl, config.dragonflyPass);
  const optimizer = new OptimizerClient(config.optimizerUrl);

  // Connect to databases
  console.log('Connecting to databases...');
  try {
    await surreal.connect();
    await xtdb.connect();
    await dragonfly.connect();
    await optimizer.connect();
  } catch (err) {
    console.error('Failed to connect to databases:', err);
    console.log('Continuing anyway - some services may be unavailable');
  }

  const state: AppState = { config, surreal, xtdb, dragonfly, optimizer };
  const routes = createRoutes();

  console.log(`Starting server on ${config.host}:${config.port}`);

  Deno.serve({ port: config.port, hostname: config.host }, async (req) => {
    const url = new URL(req.url);
    const method = req.method;
    const pathname = url.pathname;

    // CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Request logging
    const requestId = crypto.randomUUID().slice(0, 8);
    const start = performance.now();
    console.log(`[${requestId}] ${method} ${pathname}`);

    // Route matching
    const match = matchRoute(routes, method, pathname);

    let response: Response;
    if (match) {
      try {
        response = await match.handler(state, req, match.params, url.searchParams);
      } catch (err) {
        console.error(`[${requestId}] Error:`, err);
        response = errorResponse('internal_error', 'Internal server error', 500);
      }
    } else {
      response = errorResponse('not_found', `Route ${method} ${pathname} not found`, 404);
    }

    // Response logging
    const duration = (performance.now() - start).toFixed(2);
    console.log(`[${requestId}] ${response.status} (${duration}ms)`);

    return response;
  });
}

main();
