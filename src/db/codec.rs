use super::*;

// ── ExerciseTypeConfig blob encoding ──
// We store repeated ExerciseTypeConfig as a length-delimited sequence of protos.

pub(super) fn encode_exercise_configs(configs: &[ExerciseTypeConfig]) -> Vec<u8> {
    let mut buf = Vec::new();
    for config in configs {
        let encoded = config.encode_to_vec();
        buf.extend_from_slice(&(encoded.len() as u32).to_le_bytes());
        buf.extend_from_slice(&encoded);
    }
    buf
}

pub(super) fn decode_exercise_configs(data: &[u8]) -> Vec<ExerciseTypeConfig> {
    let mut configs = Vec::new();
    let mut offset = 0;
    while offset + 4 <= data.len() {
        let len = u32::from_le_bytes([
            data[offset],
            data[offset + 1],
            data[offset + 2],
            data[offset + 3],
        ]) as usize;
        offset += 4;
        if offset + len > data.len() {
            break;
        }
        if let Ok(config) = ExerciseTypeConfig::decode(&data[offset..offset + len]) {
            configs.push(config);
        }
        offset += len;
    }
    configs
}
