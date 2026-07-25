fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(
            &[
                "proto/workout/v1/workout.proto",
                "proto/workout/v1/group.proto",
                "proto/workout/v1/auth.proto",
                "proto/workout/v1/settings.proto",
                "proto/workout/v1/training.proto",
            ],
            &["proto"],
        )?;
    Ok(())
}
