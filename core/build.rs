// The proto messages (no services: the server generates those with tonic,
// pointing them at these types), and the stamp of the rules accounts fold by.

use sha2::{Digest, Sha256};
use std::path::Path;

/// What decides how an account folds and how a snapshot is written: the
/// core's sources and what they read in (programs, the template library),
/// and the protos a snapshot is made of. Their hash is `SCHLIFT_FOLD`
/// (`schlift_core::FOLD`), stamped on every snapshot: the phone and the
/// server use one only if they fold by the same rules, so a phone and
/// server built from one commit agree, and a change to any of these makes
/// every snapshot fold again (each when its account is next read).
///
/// Not the other protos (the sync stream's messages, the services) or the
/// lockfile: changing those leaves every snapshot good, so a release that
/// only touches them doesn't refold every account.
const FOLD_INPUTS: &[&str] = &[
    "src",
    "programs",
    "build.rs",
    "Cargo.toml",
    "../templates",
    "../proto/workout/v1/workout.proto",
    "../proto/workout/v1/settings.proto",
    "../proto/workout/v1/snapshot.proto",
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
    println!("cargo:rerun-if-changed=../proto");
    prost_build::Config::new()
        // The shared domain types (a decision, a template, a set) are carried
        // inside stored events, which are JSON (src/events.rs). Missing
        // fields take their defaults, so an older event still reads.
        .message_attribute(
            ".",
            "#[derive(serde::Serialize, serde::Deserialize)] #[serde(default)]",
        )
        .enum_attribute(".", "#[derive(serde::Serialize, serde::Deserialize)]")
        .compile_protos(
            &[
                "../proto/workout/v1/workout.proto",
                "../proto/workout/v1/group.proto",
                "../proto/workout/v1/auth.proto",
                "../proto/workout/v1/settings.proto",
                "../proto/workout/v1/analytics.proto",
                "../proto/workout/v1/account.proto",
                "../proto/workout/v1/assistant.proto",
                "../proto/workout/v1/snapshot.proto",
            ],
            &["../proto"],
        )?;
    Ok(())
}
