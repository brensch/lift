fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(
            &[
                "proto/workout/v1/workout.proto",
                "proto/workout/v1/group.proto"
            ],
            &["proto"]
        )?;
    Ok(())
}