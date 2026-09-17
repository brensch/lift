pub mod workout {
    // tonic's generated client/server methods return `Result<_, Status>`;
    // newer clippy flags the large `Err` variant. It is generated code.
    #[allow(clippy::result_large_err)]
    pub mod v1 {
        tonic::include_proto!("workout.v1");
    }
}
