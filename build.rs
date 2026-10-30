fn main() -> Result<(), Box<dyn std::error::Error>> {
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
            ],
            &["proto"],
        )?;
    Ok(())
}
