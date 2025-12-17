# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 hyperpolymath
#
# Nix flake for Voyage Enterprise Decision System
# Fallback package management per RSR guidelines (prefer Guix when available)
{
  description = "VEDS - Voyage Enterprise Decision System: Multimodal transport optimization with formal verification";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust (routing optimizer)
            rustToolchain
            cargo-audit
            cargo-watch

            # Elixir (API gateway)
            elixir_1_16
            erlang_26

            # Clojure (constraints engine)
            clojure
            clojure-lsp
            babashka

            # Julia (visualization)
            julia-bin

            # Ada/SPARK (formal verification)
            gnat
            gprbuild

            # Databases
            postgresql_16
            surrealdb

            # Container tools (RSR compliant)
            nerdctl
            podman

            # Development utilities
            just
            gnumake
            git
            curl
            jq
            yq-go

            # Security scanning
            trivy
            trufflehog
          ];

          shellHook = ''
            echo "VEDS Development Environment"
            echo "=============================="
            echo "Rust:    $(rustc --version 2>/dev/null || echo 'not found')"
            echo "Elixir:  $(elixir --version 2>/dev/null | head -1 || echo 'not found')"
            echo "Clojure: $(clojure --version 2>/dev/null || echo 'not found')"
            echo "Julia:   $(julia --version 2>/dev/null || echo 'not found')"
            echo ""
            echo "Run 'just --list' for available tasks"
          '';

          # Environment variables
          RUST_BACKTRACE = "1";
          RUST_LOG = "info";
        };

        # Package outputs for CI/CD
        packages = {
          rust-routing = pkgs.rustPlatform.buildRustPackage {
            pname = "veds-rust-routing";
            version = "0.1.0";
            src = ./src/rust-routing;
            cargoLock.lockFile = ./src/rust-routing/Cargo.lock;
          };
        };

        # Checks for CI
        checks = {
          format = pkgs.runCommand "check-format" {
            buildInputs = [ rustToolchain ];
          } ''
            cd ${./src/rust-routing}
            cargo fmt -- --check
            touch $out
          '';

          clippy = pkgs.runCommand "check-clippy" {
            buildInputs = [ rustToolchain ];
          } ''
            cd ${./src/rust-routing}
            cargo clippy -- -D warnings
            touch $out
          '';

          audit = pkgs.runCommand "check-audit" {
            buildInputs = [ pkgs.cargo-audit ];
          } ''
            cd ${./src/rust-routing}
            cargo audit
            touch $out
          '';
        };
      });
}
