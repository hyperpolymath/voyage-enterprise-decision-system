//! VEDS Route Optimizer
//!
//! High-performance multimodal transport route optimization engine.
//! Finds optimal paths across maritime, rail, road, and air networks.

mod graph;
mod optimizer;
mod constraints;
mod grpc;
mod db;

use anyhow::{Result, bail};
use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, error, Level};
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

use crate::graph::TransportGraph;
use crate::optimizer::{Optimizer, OptimizeRequest as OptimizerRequest, CandidateRoute};
use crate::constraints::ConstraintEngine;

/// Get required environment variable or exit
fn require_env(name: &str) -> String {
    match std::env::var(name) {
        Ok(val) if !val.is_empty() => val,
        _ => {
            eprintln!("FATAL: Required environment variable {} is not set", name);
            std::process::exit(1);
        }
    }
}

/// Application configuration
#[derive(Debug, Clone)]
pub struct Config {
    pub grpc_port: u16,
    pub http_port: u16,
    pub surrealdb_url: String,
    pub surrealdb_user: String,
    pub surrealdb_pass: String,
    pub dragonfly_url: String,
    pub dragonfly_pass: String,
    pub graph_reload_interval_secs: u64,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        dotenvy::dotenv().ok();

        // Require credentials - no defaults for sensitive values
        let surrealdb_pass = require_env("SURREALDB_PASS");
        let dragonfly_pass = require_env("DRAGONFLY_PASS");

        Ok(Config {
            grpc_port: std::env::var("GRPC_PORT")
                .unwrap_or_else(|_| "50051".to_string())
                .parse()?,
            http_port: std::env::var("HTTP_PORT")
                .unwrap_or_else(|_| "8090".to_string())
                .parse()?,
            surrealdb_url: std::env::var("SURREALDB_URL")
                .unwrap_or_else(|_| "ws://localhost:8000".to_string()),
            surrealdb_user: std::env::var("SURREALDB_USER")
                .unwrap_or_else(|_| "root".to_string()),
            surrealdb_pass,
            dragonfly_url: std::env::var("DRAGONFLY_URL")
                .unwrap_or_else(|_| "redis://localhost:6379".to_string()),
            dragonfly_pass,
            graph_reload_interval_secs: std::env::var("GRAPH_RELOAD_INTERVAL")
                .unwrap_or_else(|_| "300".to_string())
                .parse()?,
        })
    }
}

/// Shared application state
pub struct AppState {
    pub config: Config,
    pub graph: RwLock<TransportGraph>,
    pub redis: redis::aio::ConnectionManager,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(fmt::layer().with_target(true))
        .with(
            EnvFilter::builder()
                .with_default_directive(Level::INFO.into())
                .from_env_lossy(),
        )
        .init();

    info!("Starting VEDS Route Optimizer");

    // Load configuration
    let config = Config::from_env()?;
    info!(?config, "Configuration loaded");

    // Connect to Dragonfly/Redis
    let redis_url = format!(
        "redis://:{}@{}",
        config.dragonfly_pass,
        config.dragonfly_url.trim_start_matches("redis://")
    );
    let redis_client = redis::Client::open(redis_url)?;
    let redis_conn = redis::aio::ConnectionManager::new(redis_client).await?;
    info!("Connected to Dragonfly/Redis");

    // Initialize transport graph
    let graph = TransportGraph::new();
    info!("Transport graph initialized (empty)");

    // Create shared state
    let state = Arc::new(AppState {
        config: config.clone(),
        graph: RwLock::new(graph),
        redis: redis_conn,
    });

    // Load initial graph from database
    {
        let mut graph = state.graph.write().await;
        match db::load_graph_from_surrealdb(&config).await {
            Ok(loaded_graph) => {
                *graph = loaded_graph;
                info!(
                    nodes = graph.node_count(),
                    edges = graph.edge_count(),
                    "Transport graph loaded from SurrealDB"
                );
            }
            Err(e) => {
                tracing::warn!("Failed to load graph from SurrealDB: {}. Starting with empty graph.", e);
            }
        }
    }

    // Spawn background graph reload task
    let state_clone = Arc::clone(&state);
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(
            std::time::Duration::from_secs(state_clone.config.graph_reload_interval_secs)
        );
        loop {
            interval.tick().await;
            if let Ok(new_graph) = db::load_graph_from_surrealdb(&state_clone.config).await {
                let mut graph = state_clone.graph.write().await;
                *graph = new_graph;
                info!("Transport graph reloaded");
            }
        }
    });

    // Spawn HTTP server (metrics + API endpoints)
    let http_port = config.http_port;
    let http_state = Arc::clone(&state);
    tokio::spawn(async move {
        let app = Router::new()
            .route("/health", get(health_handler))
            .route("/metrics", get(metrics_handler))
            .route("/optimize", post(optimize_handler))
            .route("/graph/status", get(graph_status_handler))
            .route("/graph/reload", post(graph_reload_handler))
            .with_state(http_state);

        let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", http_port))
            .await
            .unwrap();
        info!("HTTP server listening on port {}", http_port);
        axum::serve(listener, app).await.unwrap();
    });

    // Start gRPC server
    let addr = format!("0.0.0.0:{}", config.grpc_port).parse()?;
    info!("gRPC server listening on {}", addr);

    tonic::transport::Server::builder()
        .add_service(grpc::optimizer_service_server(state))
        .serve(addr)
        .await?;

    Ok(())
}

// =============================================================================
// HTTP Request/Response Types
// =============================================================================

#[derive(Debug, Deserialize)]
struct HttpOptimizeRequest {
    shipment_id: String,
    origin_code: String,
    destination_code: String,
    weight_kg: f64,
    volume_m3: f64,
    pickup_after: Option<String>,
    deliver_by: Option<String>,
    max_cost_usd: Option<f64>,
    max_carbon_kg: Option<f64>,
    min_labor_score: Option<f64>,
    allowed_modes: Option<Vec<String>>,
    excluded_carriers: Option<Vec<String>>,
    max_routes: Option<usize>,
    max_segments: Option<usize>,
    cost_weight: Option<f64>,
    time_weight: Option<f64>,
    carbon_weight: Option<f64>,
    labor_weight: Option<f64>,
}

#[derive(Debug, Serialize)]
struct HttpOptimizeResponse {
    success: bool,
    error: Option<String>,
    routes: Vec<HttpRoute>,
    optimization_time_ms: u64,
    candidates_evaluated: usize,
}

#[derive(Debug, Serialize)]
struct HttpRoute {
    route_id: String,
    segments: Vec<HttpRouteSegment>,
    total_cost_usd: String,
    total_time_hours: f64,
    total_carbon_kg: f64,
    total_distance_km: f64,
    labor_score: f64,
    pareto_rank: u32,
    pareto_optimal: bool,
    weighted_score: f64,
}

#[derive(Debug, Serialize)]
struct HttpRouteSegment {
    segment_id: String,
    sequence: u32,
    from_node: String,
    to_node: String,
    mode: String,
    carrier_code: String,
    distance_km: f64,
    cost_usd: String,
    transit_hours: f64,
    carbon_kg: f64,
    departure_time: String,
    arrival_time: String,
}

#[derive(Debug, Serialize)]
struct HttpGraphStatus {
    node_count: usize,
    edge_count: usize,
    last_loaded: String,
    load_time_ms: u64,
    mode_counts: std::collections::HashMap<String, usize>,
}

#[derive(Debug, Serialize)]
struct HttpReloadResponse {
    success: bool,
    message: String,
    load_time_ms: u64,
}

// =============================================================================
// HTTP Handlers
// =============================================================================

async fn health_handler() -> &'static str {
    "OK"
}

async fn metrics_handler() -> String {
    use prometheus::Encoder;
    let encoder = prometheus::TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = Vec::new();
    encoder.encode(&metric_families, &mut buffer).unwrap();
    String::from_utf8(buffer).unwrap()
}

async fn optimize_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<HttpOptimizeRequest>,
) -> Result<Json<HttpOptimizeResponse>, (StatusCode, String)> {
    use chrono::{DateTime, Utc, Duration};
    use rust_decimal::Decimal;
    use crate::graph::TransportMode;
    use std::collections::HashSet;

    // Parse datetime strings
    let pickup_after = req.pickup_after
        .and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
        .map(|dt| dt.with_timezone(&Utc))
        .unwrap_or_else(Utc::now);

    let deliver_by = req.deliver_by
        .and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
        .map(|dt| dt.with_timezone(&Utc))
        .unwrap_or_else(|| Utc::now() + Duration::days(30));

    // Parse allowed modes
    let allowed_modes: HashSet<TransportMode> = req.allowed_modes
        .unwrap_or_default()
        .iter()
        .filter_map(|m| match m.to_uppercase().as_str() {
            "MARITIME" => Some(TransportMode::Maritime),
            "RAIL" => Some(TransportMode::Rail),
            "ROAD" => Some(TransportMode::Road),
            "AIR" => Some(TransportMode::Air),
            _ => None,
        })
        .collect();

    // Build internal request
    let internal_request = OptimizerRequest {
        shipment_id: req.shipment_id,
        origin_code: req.origin_code,
        destination_code: req.destination_code,
        weight_kg: req.weight_kg,
        volume_m3: req.volume_m3,
        pickup_after,
        deliver_by,
        max_cost_usd: req.max_cost_usd.and_then(|v| Decimal::from_f64_retain(v)),
        max_carbon_kg: req.max_carbon_kg,
        min_labor_score: req.min_labor_score,
        allowed_modes,
        excluded_carriers: req.excluded_carriers.unwrap_or_default().into_iter().collect(),
        max_routes: req.max_routes.unwrap_or(10),
        max_segments: req.max_segments.unwrap_or(8),
        cost_weight: req.cost_weight.unwrap_or(0.4),
        time_weight: req.time_weight.unwrap_or(0.3),
        carbon_weight: req.carbon_weight.unwrap_or(0.2),
        labor_weight: req.labor_weight.unwrap_or(0.1),
    };

    // Get graph and run optimization
    let graph = state.graph.read().await;
    let constraint_engine = ConstraintEngine::new();
    let optimizer = Optimizer::new(constraint_engine);
    let result = optimizer.optimize(&graph, &internal_request);

    // Convert to response
    let routes: Vec<HttpRoute> = result.routes
        .into_iter()
        .map(|r| HttpRoute {
            route_id: r.route_id,
            segments: r.segments.into_iter().map(|s| HttpRouteSegment {
                segment_id: s.segment_id,
                sequence: s.sequence,
                from_node: s.from_node,
                to_node: s.to_node,
                mode: s.mode.to_string(),
                carrier_code: s.carrier_code,
                distance_km: s.distance_km,
                cost_usd: s.cost_usd.to_string(),
                transit_hours: s.transit_hours,
                carbon_kg: s.carbon_kg,
                departure_time: s.departure_time.to_rfc3339(),
                arrival_time: s.arrival_time.to_rfc3339(),
            }).collect(),
            total_cost_usd: r.total_cost_usd.to_string(),
            total_time_hours: r.total_time_hours,
            total_carbon_kg: r.total_carbon_kg,
            total_distance_km: r.total_distance_km,
            labor_score: r.labor_score,
            pareto_rank: r.pareto_rank,
            pareto_optimal: r.pareto_optimal,
            weighted_score: r.weighted_score,
        })
        .collect();

    Ok(Json(HttpOptimizeResponse {
        success: true,
        error: None,
        routes,
        optimization_time_ms: result.optimization_time_ms,
        candidates_evaluated: result.candidates_evaluated,
    }))
}

async fn graph_status_handler(
    State(state): State<Arc<AppState>>,
) -> Json<HttpGraphStatus> {
    let graph = state.graph.read().await;

    let mode_counts: std::collections::HashMap<String, usize> = graph
        .edge_count_by_mode()
        .into_iter()
        .map(|(mode, count)| (mode.to_string(), count))
        .collect();

    Json(HttpGraphStatus {
        node_count: graph.node_count(),
        edge_count: graph.edge_count(),
        last_loaded: graph.loaded_at.to_rfc3339(),
        load_time_ms: graph.load_time_ms,
        mode_counts,
    })
}

async fn graph_reload_handler(
    State(state): State<Arc<AppState>>,
) -> Json<HttpReloadResponse> {
    let start = std::time::Instant::now();

    match db::load_graph_from_surrealdb(&state.config).await {
        Ok(new_graph) => {
            let mut graph = state.graph.write().await;
            let nodes = new_graph.node_count();
            let edges = new_graph.edge_count();
            *graph = new_graph;

            Json(HttpReloadResponse {
                success: true,
                message: format!("Loaded {} nodes, {} edges", nodes, edges),
                load_time_ms: start.elapsed().as_millis() as u64,
            })
        }
        Err(e) => {
            error!("Failed to reload graph: {}", e);
            Json(HttpReloadResponse {
                success: false,
                message: e.to_string(),
                load_time_ms: start.elapsed().as_millis() as u64,
            })
        }
    }
}
