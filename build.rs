use sha2::{Digest, Sha256};
use std::path::Path;

/// What decides how an account folds: the core's sources and what they
/// read in, the protos its messages come from, and every dependency's
/// version. Their hash is `SCHLIFT_FOLD`, stamped on each snapshot of an
/// account (`src/db/snapshots.rs`): one folded by other rules is thrown
/// away, never caught up.
const FOLD_INPUTS: &[&str] = &[
    "core/src",
    "core/programs",
    "core/build.rs",
    "core/Cargo.toml",
    "templates",
    "proto",
    "Cargo.lock",
];

fn hash_into(hasher: &mut Sha256, path: &Path) -> std::io::Result<()> {
    if path.is_dir() {
        let mut entries: Vec<_> = std::fs::read_dir(path)?
            .map(|e| e.map(|e| e.path()))
            .collect::<Result<_, _>>()?;
        entries.sort();
        for entry in entries {
            hash_into(hasher, &entry)?;
        }
    } else {
        hasher.update(path.to_string_lossy().as_bytes());
        hasher.update(std::fs::read(path)?);
    }
    Ok(())
}

fn fold_stamp() -> std::io::Result<String> {
    let mut hasher = Sha256::new();
    for input in FOLD_INPUTS {
        println!("cargo:rerun-if-changed={input}");
        hash_into(&mut hasher, Path::new(input))?;
    }
    Ok(hasher.finalize()[..12]
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rustc-env=SCHLIFT_FOLD={}", fold_stamp()?);
    // Without this, the line above would stop cargo watching the protos and
    // this script for themselves.
    println!("cargo:rerun-if-changed=build.rs");
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        // The messages come from schlift-core; only the services are
        // generated here, typed against them.
        .extern_path(".workout.v1", "::schlift_core::pb")
        .compile_protos(
            &[
                "proto/workout/v1/workout.proto",
                "proto/workout/v1/group.proto",
                "proto/workout/v1/auth.proto",
                "proto/workout/v1/settings.proto",
                "proto/workout/v1/analytics.proto",
                "proto/workout/v1/account.proto",
                "proto/workout/v1/assistant.proto",
            ],
            &["proto"],
        )?;
    Ok(())
}
