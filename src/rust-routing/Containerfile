# SPDX-License-Identifier: MIT OR AGPL-3.0
# VEDS Route Optimizer - Distroless Container
# Multi-stage build for minimal production image

# =============================================================================
# Build stage
# =============================================================================
FROM rust:1.75-bookworm AS builder

WORKDIR /app

# Install protobuf compiler
RUN apt-get update && \
    apt-get install -y --no-install-recommends protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

# Copy manifests first for dependency caching
COPY Cargo.toml Cargo.lock ./

# Create dummy src to cache dependencies
RUN mkdir -p src proto && \
    echo "fn main() {}" > src/main.rs && \
    echo 'syntax = "proto3"; package dummy;' > proto/optimizer.proto

# Build dependencies (cached layer)
RUN cargo build --release && rm -rf src proto

# Copy actual source
COPY . .

# Touch main.rs to force rebuild with actual source
RUN touch src/main.rs

# Build release binary
RUN cargo build --release

# =============================================================================
# Runtime stage - Distroless
# =============================================================================
FROM gcr.io/distroless/cc-debian12:nonroot

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/veds-optimizer /app/veds-optimizer

# Expose ports
EXPOSE 50051 8090

# Run as nonroot user (uid 65532)
USER nonroot

# Distroless has no shell, so no HEALTHCHECK possible here
# Health checks are defined in docker-compose.yml

# Run
ENTRYPOINT ["/app/veds-optimizer"]
