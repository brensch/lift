// The proto messages (no services: the server generates those with tonic,
// pointing them at these types).
fn main() -> Result<(), Box<dyn std::error::Error>> {
    prost_build::compile_protos(
        &[
            "../proto/workout/v1/workout.proto",
            "../proto/workout/v1/group.proto",
            "../proto/workout/v1/auth.proto",
            "../proto/workout/v1/settings.proto",
            "../proto/workout/v1/analytics.proto",
            "../proto/workout/v1/wearable.proto",
        ],
        &["../proto"],
    )?;
    Ok(())
}
