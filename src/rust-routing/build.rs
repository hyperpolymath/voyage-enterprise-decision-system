// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Compile protobuf definitions for gRPC
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile(&["proto/optimizer.proto"], &["proto/"])?;
    Ok(())
}
