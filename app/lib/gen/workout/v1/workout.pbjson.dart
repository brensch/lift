// This is a generated file - do not edit.
//
// Generated from workout/v1/workout.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use muscleGroupDescriptor instead')
const MuscleGroup$json = {
  '1': 'MuscleGroup',
  '2': [
    {'1': 'MUSCLE_GROUP_UNSPECIFIED', '2': 0},
    {'1': 'MUSCLE_GROUP_QUADS', '2': 1},
    {'1': 'MUSCLE_GROUP_HAMSTRINGS', '2': 2},
    {'1': 'MUSCLE_GROUP_GLUTES', '2': 3},
    {'1': 'MUSCLE_GROUP_CHEST', '2': 4},
    {'1': 'MUSCLE_GROUP_BACK', '2': 5},
    {'1': 'MUSCLE_GROUP_SHOULDERS', '2': 6},
    {'1': 'MUSCLE_GROUP_BICEPS', '2': 7},
    {'1': 'MUSCLE_GROUP_TRICEPS', '2': 8},
  ],
};

/// Descriptor for `MuscleGroup`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List muscleGroupDescriptor = $convert.base64Decode(
    'CgtNdXNjbGVHcm91cBIcChhNVVNDTEVfR1JPVVBfVU5TUEVDSUZJRUQQABIWChJNVVNDTEVfR1'
    'JPVVBfUVVBRFMQARIbChdNVVNDTEVfR1JPVVBfSEFNU1RSSU5HUxACEhcKE01VU0NMRV9HUk9V'
    'UF9HTFVURVMQAxIWChJNVVNDTEVfR1JPVVBfQ0hFU1QQBBIVChFNVVNDTEVfR1JPVVBfQkFDSx'
    'AFEhoKFk1VU0NMRV9HUk9VUF9TSE9VTERFUlMQBhIXChNNVVNDTEVfR1JPVVBfQklDRVBTEAcS'
    'GAoUTVVTQ0xFX0dST1VQX1RSSUNFUFMQCA==');

@$core.Deprecated('Use exerciseCategoryDescriptor instead')
const ExerciseCategory$json = {
  '1': 'ExerciseCategory',
  '2': [
    {'1': 'EXERCISE_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'EXERCISE_CATEGORY_COMPOUND', '2': 1},
    {'1': 'EXERCISE_CATEGORY_AUXILIARY', '2': 2},
  ],
};

/// Descriptor for `ExerciseCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exerciseCategoryDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZUNhdGVnb3J5EiEKHUVYRVJDSVNFX0NBVEVHT1JZX1VOU1BFQ0lGSUVEEAASHg'
    'oaRVhFUkNJU0VfQ0FURUdPUllfQ09NUE9VTkQQARIfChtFWEVSQ0lTRV9DQVRFR09SWV9BVVhJ'
    'TElBUlkQAg==');

@$core.Deprecated('Use exerciseDescriptor instead')
const Exercise$json = {
  '1': 'Exercise',
  '2': [
    {'1': 'EXERCISE_UNSPECIFIED', '2': 0},
    {'1': 'EXERCISE_SQUAT', '2': 1},
    {'1': 'EXERCISE_BENCH_PRESS', '2': 2},
    {'1': 'EXERCISE_DEADLIFT', '2': 3},
    {'1': 'EXERCISE_OVERHEAD_PRESS', '2': 4},
    {'1': 'EXERCISE_BARBELL_ROW', '2': 5},
    {'1': 'EXERCISE_HIP_THRUST', '2': 6},
    {'1': 'EXERCISE_BULGARIAN_SPLIT_SQUAT', '2': 7},
    {'1': 'EXERCISE_ROMANIAN_DEADLIFT', '2': 8},
    {'1': 'EXERCISE_GLUTE_BRIDGE', '2': 9},
    {'1': 'EXERCISE_LUNGE', '2': 10},
    {'1': 'EXERCISE_LEG_CURL', '2': 11},
    {'1': 'EXERCISE_INCLINE_BENCH_PRESS', '2': 12},
    {'1': 'EXERCISE_DUMBBELL_BENCH_PRESS', '2': 13},
    {'1': 'EXERCISE_INCLINE_DUMBBELL_PRESS', '2': 14},
    {'1': 'EXERCISE_DUMBBELL_FLY', '2': 15},
    {'1': 'EXERCISE_CABLE_FLY', '2': 16},
    {'1': 'EXERCISE_PUSH_UP', '2': 17},
    {'1': 'EXERCISE_CHEST_DIP', '2': 18},
    {'1': 'EXERCISE_MACHINE_CHEST_PRESS', '2': 19},
    {'1': 'EXERCISE_PEC_DECK', '2': 20},
    {'1': 'EXERCISE_PULL_UP', '2': 21},
    {'1': 'EXERCISE_CHIN_UP', '2': 22},
    {'1': 'EXERCISE_LAT_PULLDOWN', '2': 23},
    {'1': 'EXERCISE_SEATED_CABLE_ROW', '2': 24},
    {'1': 'EXERCISE_DUMBBELL_ROW', '2': 25},
    {'1': 'EXERCISE_T_BAR_ROW', '2': 26},
    {'1': 'EXERCISE_PENDLAY_ROW', '2': 27},
    {'1': 'EXERCISE_FACE_PULL', '2': 28},
    {'1': 'EXERCISE_SHRUG', '2': 29},
    {'1': 'EXERCISE_BACK_EXTENSION', '2': 30},
    {'1': 'EXERCISE_DUMBBELL_SHOULDER_PRESS', '2': 31},
    {'1': 'EXERCISE_ARNOLD_PRESS', '2': 32},
    {'1': 'EXERCISE_LATERAL_RAISE', '2': 33},
    {'1': 'EXERCISE_FRONT_RAISE', '2': 34},
    {'1': 'EXERCISE_REAR_DELT_FLY', '2': 35},
    {'1': 'EXERCISE_UPRIGHT_ROW', '2': 36},
    {'1': 'EXERCISE_BARBELL_CURL', '2': 37},
    {'1': 'EXERCISE_DUMBBELL_CURL', '2': 38},
    {'1': 'EXERCISE_HAMMER_CURL', '2': 39},
    {'1': 'EXERCISE_PREACHER_CURL', '2': 40},
    {'1': 'EXERCISE_CONCENTRATION_CURL', '2': 41},
    {'1': 'EXERCISE_CABLE_CURL', '2': 42},
    {'1': 'EXERCISE_TRICEP_PUSHDOWN', '2': 43},
    {'1': 'EXERCISE_OVERHEAD_TRICEP_EXTENSION', '2': 44},
    {'1': 'EXERCISE_SKULL_CRUSHER', '2': 45},
    {'1': 'EXERCISE_CLOSE_GRIP_BENCH_PRESS', '2': 46},
    {'1': 'EXERCISE_TRICEP_DIP', '2': 47},
    {'1': 'EXERCISE_TRICEP_KICKBACK', '2': 48},
    {'1': 'EXERCISE_FRONT_SQUAT', '2': 49},
    {'1': 'EXERCISE_LEG_PRESS', '2': 50},
    {'1': 'EXERCISE_LEG_EXTENSION', '2': 51},
    {'1': 'EXERCISE_HACK_SQUAT', '2': 52},
    {'1': 'EXERCISE_GOBLET_SQUAT', '2': 53},
    {'1': 'EXERCISE_WALKING_LUNGE', '2': 54},
    {'1': 'EXERCISE_STEP_UP', '2': 55},
    {'1': 'EXERCISE_CALF_RAISE', '2': 56},
    {'1': 'EXERCISE_SEATED_CALF_RAISE', '2': 57},
    {'1': 'EXERCISE_NORDIC_CURL', '2': 58},
    {'1': 'EXERCISE_GOOD_MORNING', '2': 59},
    {'1': 'EXERCISE_GLUTE_KICKBACK', '2': 60},
    {'1': 'EXERCISE_SUMO_DEADLIFT', '2': 61},
    {'1': 'EXERCISE_SUMO_SQUAT', '2': 62},
    {'1': 'EXERCISE_CURTSY_LUNGE', '2': 63},
    {'1': 'EXERCISE_FROG_PUMP', '2': 64},
    {'1': 'EXERCISE_SINGLE_LEG_HIP_THRUST', '2': 65},
    {'1': 'EXERCISE_CABLE_PULL_THROUGH', '2': 66},
    {'1': 'EXERCISE_HIP_ABDUCTION', '2': 67},
    {'1': 'EXERCISE_PLANK', '2': 68},
    {'1': 'EXERCISE_HANGING_LEG_RAISE', '2': 69},
    {'1': 'EXERCISE_CABLE_CRUNCH', '2': 70},
    {'1': 'EXERCISE_RUSSIAN_TWIST', '2': 71},
    {'1': 'EXERCISE_AB_WHEEL_ROLLOUT', '2': 72},
    {'1': 'EXERCISE_SIT_UP', '2': 73},
    {'1': 'EXERCISE_CRUNCH', '2': 74},
    {'1': 'EXERCISE_MOUNTAIN_CLIMBER', '2': 75},
    {'1': 'EXERCISE_HIP_ADDUCTION', '2': 76},
  ],
};

/// Descriptor for `Exercise`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exerciseDescriptor = $convert.base64Decode(
    'CghFeGVyY2lzZRIYChRFWEVSQ0lTRV9VTlNQRUNJRklFRBAAEhIKDkVYRVJDSVNFX1NRVUFUEA'
    'ESGAoURVhFUkNJU0VfQkVOQ0hfUFJFU1MQAhIVChFFWEVSQ0lTRV9ERUFETElGVBADEhsKF0VY'
    'RVJDSVNFX09WRVJIRUFEX1BSRVNTEAQSGAoURVhFUkNJU0VfQkFSQkVMTF9ST1cQBRIXChNFWE'
    'VSQ0lTRV9ISVBfVEhSVVNUEAYSIgoeRVhFUkNJU0VfQlVMR0FSSUFOX1NQTElUX1NRVUFUEAcS'
    'HgoaRVhFUkNJU0VfUk9NQU5JQU5fREVBRExJRlQQCBIZChVFWEVSQ0lTRV9HTFVURV9CUklER0'
    'UQCRISCg5FWEVSQ0lTRV9MVU5HRRAKEhUKEUVYRVJDSVNFX0xFR19DVVJMEAsSIAocRVhFUkNJ'
    'U0VfSU5DTElORV9CRU5DSF9QUkVTUxAMEiEKHUVYRVJDSVNFX0RVTUJCRUxMX0JFTkNIX1BSRV'
    'NTEA0SIwofRVhFUkNJU0VfSU5DTElORV9EVU1CQkVMTF9QUkVTUxAOEhkKFUVYRVJDSVNFX0RV'
    'TUJCRUxMX0ZMWRAPEhYKEkVYRVJDSVNFX0NBQkxFX0ZMWRAQEhQKEEVYRVJDSVNFX1BVU0hfVV'
    'AQERIWChJFWEVSQ0lTRV9DSEVTVF9ESVAQEhIgChxFWEVSQ0lTRV9NQUNISU5FX0NIRVNUX1BS'
    'RVNTEBMSFQoRRVhFUkNJU0VfUEVDX0RFQ0sQFBIUChBFWEVSQ0lTRV9QVUxMX1VQEBUSFAoQRV'
    'hFUkNJU0VfQ0hJTl9VUBAWEhkKFUVYRVJDSVNFX0xBVF9QVUxMRE9XThAXEh0KGUVYRVJDSVNF'
    'X1NFQVRFRF9DQUJMRV9ST1cQGBIZChVFWEVSQ0lTRV9EVU1CQkVMTF9ST1cQGRIWChJFWEVSQ0'
    'lTRV9UX0JBUl9ST1cQGhIYChRFWEVSQ0lTRV9QRU5ETEFZX1JPVxAbEhYKEkVYRVJDSVNFX0ZB'
    'Q0VfUFVMTBAcEhIKDkVYRVJDSVNFX1NIUlVHEB0SGwoXRVhFUkNJU0VfQkFDS19FWFRFTlNJT0'
    '4QHhIkCiBFWEVSQ0lTRV9EVU1CQkVMTF9TSE9VTERFUl9QUkVTUxAfEhkKFUVYRVJDSVNFX0FS'
    'Tk9MRF9QUkVTUxAgEhoKFkVYRVJDSVNFX0xBVEVSQUxfUkFJU0UQIRIYChRFWEVSQ0lTRV9GUk'
    '9OVF9SQUlTRRAiEhoKFkVYRVJDSVNFX1JFQVJfREVMVF9GTFkQIxIYChRFWEVSQ0lTRV9VUFJJ'
    'R0hUX1JPVxAkEhkKFUVYRVJDSVNFX0JBUkJFTExfQ1VSTBAlEhoKFkVYRVJDSVNFX0RVTUJCRU'
    'xMX0NVUkwQJhIYChRFWEVSQ0lTRV9IQU1NRVJfQ1VSTBAnEhoKFkVYRVJDSVNFX1BSRUFDSEVS'
    'X0NVUkwQKBIfChtFWEVSQ0lTRV9DT05DRU5UUkFUSU9OX0NVUkwQKRIXChNFWEVSQ0lTRV9DQU'
    'JMRV9DVVJMECoSHAoYRVhFUkNJU0VfVFJJQ0VQX1BVU0hET1dOECsSJgoiRVhFUkNJU0VfT1ZF'
    'UkhFQURfVFJJQ0VQX0VYVEVOU0lPThAsEhoKFkVYRVJDSVNFX1NLVUxMX0NSVVNIRVIQLRIjCh'
    '9FWEVSQ0lTRV9DTE9TRV9HUklQX0JFTkNIX1BSRVNTEC4SFwoTRVhFUkNJU0VfVFJJQ0VQX0RJ'
    'UBAvEhwKGEVYRVJDSVNFX1RSSUNFUF9LSUNLQkFDSxAwEhgKFEVYRVJDSVNFX0ZST05UX1NRVU'
    'FUEDESFgoSRVhFUkNJU0VfTEVHX1BSRVNTEDISGgoWRVhFUkNJU0VfTEVHX0VYVEVOU0lPThAz'
    'EhcKE0VYRVJDSVNFX0hBQ0tfU1FVQVQQNBIZChVFWEVSQ0lTRV9HT0JMRVRfU1FVQVQQNRIaCh'
    'ZFWEVSQ0lTRV9XQUxLSU5HX0xVTkdFEDYSFAoQRVhFUkNJU0VfU1RFUF9VUBA3EhcKE0VYRVJD'
    'SVNFX0NBTEZfUkFJU0UQOBIeChpFWEVSQ0lTRV9TRUFURURfQ0FMRl9SQUlTRRA5EhgKFEVYRV'
    'JDSVNFX05PUkRJQ19DVVJMEDoSGQoVRVhFUkNJU0VfR09PRF9NT1JOSU5HEDsSGwoXRVhFUkNJ'
    'U0VfR0xVVEVfS0lDS0JBQ0sQPBIaChZFWEVSQ0lTRV9TVU1PX0RFQURMSUZUED0SFwoTRVhFUk'
    'NJU0VfU1VNT19TUVVBVBA+EhkKFUVYRVJDSVNFX0NVUlRTWV9MVU5HRRA/EhYKEkVYRVJDSVNF'
    'X0ZST0dfUFVNUBBAEiIKHkVYRVJDSVNFX1NJTkdMRV9MRUdfSElQX1RIUlVTVBBBEh8KG0VYRV'
    'JDSVNFX0NBQkxFX1BVTExfVEhST1VHSBBCEhoKFkVYRVJDSVNFX0hJUF9BQkRVQ1RJT04QQxIS'
    'Cg5FWEVSQ0lTRV9QTEFOSxBEEh4KGkVYRVJDSVNFX0hBTkdJTkdfTEVHX1JBSVNFEEUSGQoVRV'
    'hFUkNJU0VfQ0FCTEVfQ1JVTkNIEEYSGgoWRVhFUkNJU0VfUlVTU0lBTl9UV0lTVBBHEh0KGUVY'
    'RVJDSVNFX0FCX1dIRUVMX1JPTExPVVQQSBITCg9FWEVSQ0lTRV9TSVRfVVAQSRITCg9FWEVSQ0'
    'lTRV9DUlVOQ0gQShIdChlFWEVSQ0lTRV9NT1VOVEFJTl9DTElNQkVSEEsSGgoWRVhFUkNJU0Vf'
    'SElQX0FERFVDVElPThBM');

@$core.Deprecated('Use userMessageKindDescriptor instead')
const UserMessageKind$json = {
  '1': 'UserMessageKind',
  '2': [
    {'1': 'USER_MESSAGE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'USER_MESSAGE_KIND_COACHING_NOTE', '2': 1},
    {'1': 'USER_MESSAGE_KIND_GROUP_RATIONALE', '2': 2},
    {'1': 'USER_MESSAGE_KIND_LOAD_INCREASE', '2': 3},
    {'1': 'USER_MESSAGE_KIND_LOAD_HOLD', '2': 4},
    {'1': 'USER_MESSAGE_KIND_STALL_DELOAD', '2': 5},
    {'1': 'USER_MESSAGE_KIND_TEMPORAL_DELOAD', '2': 6},
    {'1': 'USER_MESSAGE_KIND_SESSION_UPDATE', '2': 7},
    {'1': 'USER_MESSAGE_KIND_CYCLE_ADVANCE', '2': 8},
  ],
};

/// Descriptor for `UserMessageKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userMessageKindDescriptor = $convert.base64Decode(
    'Cg9Vc2VyTWVzc2FnZUtpbmQSIQodVVNFUl9NRVNTQUdFX0tJTkRfVU5TUEVDSUZJRUQQABIjCh'
    '9VU0VSX01FU1NBR0VfS0lORF9DT0FDSElOR19OT1RFEAESJQohVVNFUl9NRVNTQUdFX0tJTkRf'
    'R1JPVVBfUkFUSU9OQUxFEAISIwofVVNFUl9NRVNTQUdFX0tJTkRfTE9BRF9JTkNSRUFTRRADEh'
    '8KG1VTRVJfTUVTU0FHRV9LSU5EX0xPQURfSE9MRBAEEiIKHlVTRVJfTUVTU0FHRV9LSU5EX1NU'
    'QUxMX0RFTE9BRBAFEiUKIVVTRVJfTUVTU0FHRV9LSU5EX1RFTVBPUkFMX0RFTE9BRBAGEiQKIF'
    'VTRVJfTUVTU0FHRV9LSU5EX1NFU1NJT05fVVBEQVRFEAcSIwofVVNFUl9NRVNTQUdFX0tJTkRf'
    'Q1lDTEVfQURWQU5DRRAI');

@$core.Deprecated('Use userMessageSurfaceDescriptor instead')
const UserMessageSurface$json = {
  '1': 'UserMessageSurface',
  '2': [
    {'1': 'USER_MESSAGE_SURFACE_UNSPECIFIED', '2': 0},
    {'1': 'USER_MESSAGE_SURFACE_SCHEDULE', '2': 1},
    {'1': 'USER_MESSAGE_SURFACE_WORKOUT_BRIEFING', '2': 2},
    {'1': 'USER_MESSAGE_SURFACE_WORKOUT_FEED', '2': 3},
  ],
};

/// Descriptor for `UserMessageSurface`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userMessageSurfaceDescriptor = $convert.base64Decode(
    'ChJVc2VyTWVzc2FnZVN1cmZhY2USJAogVVNFUl9NRVNTQUdFX1NVUkZBQ0VfVU5TUEVDSUZJRU'
    'QQABIhCh1VU0VSX01FU1NBR0VfU1VSRkFDRV9TQ0hFRFVMRRABEikKJVVTRVJfTUVTU0FHRV9T'
    'VVJGQUNFX1dPUktPVVRfQlJJRUZJTkcQAhIlCiFVU0VSX01FU1NBR0VfU1VSRkFDRV9XT1JLT1'
    'VUX0ZFRUQQAw==');

@$core.Deprecated('Use progressionChangeKindDescriptor instead')
const ProgressionChangeKind$json = {
  '1': 'ProgressionChangeKind',
  '2': [
    {'1': 'PROGRESSION_CHANGE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'PROGRESSION_CHANGE_KIND_INCREASE', '2': 1},
    {'1': 'PROGRESSION_CHANGE_KIND_HOLD', '2': 2},
    {'1': 'PROGRESSION_CHANGE_KIND_DELOAD', '2': 3},
    {'1': 'PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE', '2': 4},
  ],
};

/// Descriptor for `ProgressionChangeKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List progressionChangeKindDescriptor = $convert.base64Decode(
    'ChVQcm9ncmVzc2lvbkNoYW5nZUtpbmQSJwojUFJPR1JFU1NJT05fQ0hBTkdFX0tJTkRfVU5TUE'
    'VDSUZJRUQQABIkCiBQUk9HUkVTU0lPTl9DSEFOR0VfS0lORF9JTkNSRUFTRRABEiAKHFBST0dS'
    'RVNTSU9OX0NIQU5HRV9LSU5EX0hPTEQQAhIiCh5QUk9HUkVTU0lPTl9DSEFOR0VfS0lORF9ERU'
    'xPQUQQAxIpCiVQUk9HUkVTU0lPTl9DSEFOR0VfS0lORF9DWUNMRV9BRFZBTkNFEAQ=');

@$core.Deprecated('Use progressionMetricKindDescriptor instead')
const ProgressionMetricKind$json = {
  '1': 'ProgressionMetricKind',
  '2': [
    {'1': 'PROGRESSION_METRIC_KIND_UNSPECIFIED', '2': 0},
    {'1': 'PROGRESSION_METRIC_KIND_WORKING_WEIGHT', '2': 1},
    {'1': 'PROGRESSION_METRIC_KIND_TRAINING_MAX', '2': 2},
  ],
};

/// Descriptor for `ProgressionMetricKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List progressionMetricKindDescriptor = $convert.base64Decode(
    'ChVQcm9ncmVzc2lvbk1ldHJpY0tpbmQSJwojUFJPR1JFU1NJT05fTUVUUklDX0tJTkRfVU5TUE'
    'VDSUZJRUQQABIqCiZQUk9HUkVTU0lPTl9NRVRSSUNfS0lORF9XT1JLSU5HX1dFSUdIVBABEigK'
    'JFBST0dSRVNTSU9OX01FVFJJQ19LSU5EX1RSQUlOSU5HX01BWBAC');

@$core.Deprecated('Use progressionReasonKindDescriptor instead')
const ProgressionReasonKind$json = {
  '1': 'ProgressionReasonKind',
  '2': [
    {'1': 'PROGRESSION_REASON_KIND_UNSPECIFIED', '2': 0},
    {'1': 'PROGRESSION_REASON_KIND_COMPLETED_ALL_WORKING_SETS', '2': 1},
    {'1': 'PROGRESSION_REASON_KIND_MISSED_TARGET_REPS', '2': 2},
    {'1': 'PROGRESSION_REASON_KIND_REPEATED_MISSES', '2': 3},
    {'1': 'PROGRESSION_REASON_KIND_STAGE_ADVANCE', '2': 4},
    {'1': 'PROGRESSION_REASON_KIND_CYCLE_COMPLETED', '2': 5},
    {'1': 'PROGRESSION_REASON_KIND_CLEARED_PROGRESSION_CHECK', '2': 6},
  ],
};

/// Descriptor for `ProgressionReasonKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List progressionReasonKindDescriptor = $convert.base64Decode(
    'ChVQcm9ncmVzc2lvblJlYXNvbktpbmQSJwojUFJPR1JFU1NJT05fUkVBU09OX0tJTkRfVU5TUE'
    'VDSUZJRUQQABI2CjJQUk9HUkVTU0lPTl9SRUFTT05fS0lORF9DT01QTEVURURfQUxMX1dPUktJ'
    'TkdfU0VUUxABEi4KKlBST0dSRVNTSU9OX1JFQVNPTl9LSU5EX01JU1NFRF9UQVJHRVRfUkVQUx'
    'ACEisKJ1BST0dSRVNTSU9OX1JFQVNPTl9LSU5EX1JFUEVBVEVEX01JU1NFUxADEikKJVBST0dS'
    'RVNTSU9OX1JFQVNPTl9LSU5EX1NUQUdFX0FEVkFOQ0UQBBIrCidQUk9HUkVTU0lPTl9SRUFTT0'
    '5fS0lORF9DWUNMRV9DT01QTEVURUQQBRI1CjFQUk9HUkVTU0lPTl9SRUFTT05fS0lORF9DTEVB'
    'UkVEX1BST0dSRVNTSU9OX0NIRUNLEAY=');

@$core.Deprecated('Use workoutStateDescriptor instead')
const WorkoutState$json = {
  '1': 'WorkoutState',
  '2': [
    {'1': 'WORKOUT_STATE_UNSPECIFIED', '2': 0},
    {'1': 'WORKOUT_STATE_ALL_DONE', '2': 1},
    {'1': 'WORKOUT_STATE_LIFTING', '2': 2},
    {'1': 'WORKOUT_STATE_RESTING', '2': 3},
    {'1': 'WORKOUT_STATE_READY', '2': 5},
  ],
};

/// Descriptor for `WorkoutState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List workoutStateDescriptor = $convert.base64Decode(
    'CgxXb3Jrb3V0U3RhdGUSHQoZV09SS09VVF9TVEFURV9VTlNQRUNJRklFRBAAEhoKFldPUktPVV'
    'RfU1RBVEVfQUxMX0RPTkUQARIZChVXT1JLT1VUX1NUQVRFX0xJRlRJTkcQAhIZChVXT1JLT1VU'
    'X1NUQVRFX1JFU1RJTkcQAxIXChNXT1JLT1VUX1NUQVRFX1JFQURZEAU=');

@$core.Deprecated('Use experienceLevelDescriptor instead')
const ExperienceLevel$json = {
  '1': 'ExperienceLevel',
  '2': [
    {'1': 'EXPERIENCE_LEVEL_UNSPECIFIED', '2': 0},
    {'1': 'EXPERIENCE_LEVEL_CUTE', '2': 1},
    {'1': 'EXPERIENCE_LEVEL_BEGINNER', '2': 2},
    {'1': 'EXPERIENCE_LEVEL_INTERMEDIATE', '2': 3},
    {'1': 'EXPERIENCE_LEVEL_EXPERT', '2': 4},
  ],
};

/// Descriptor for `ExperienceLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List experienceLevelDescriptor = $convert.base64Decode(
    'Cg9FeHBlcmllbmNlTGV2ZWwSIAocRVhQRVJJRU5DRV9MRVZFTF9VTlNQRUNJRklFRBAAEhkKFU'
    'VYUEVSSUVOQ0VfTEVWRUxfQ1VURRABEh0KGUVYUEVSSUVOQ0VfTEVWRUxfQkVHSU5ORVIQAhIh'
    'Ch1FWFBFUklFTkNFX0xFVkVMX0lOVEVSTUVESUFURRADEhsKF0VYUEVSSUVOQ0VfTEVWRUxfRV'
    'hQRVJUEAQ=');

@$core.Deprecated('Use progressionRuleDescriptor instead')
const ProgressionRule$json = {
  '1': 'ProgressionRule',
  '2': [
    {'1': 'PROGRESSION_RULE_UNSPECIFIED', '2': 0},
    {'1': 'PROGRESSION_RULE_NONE', '2': 1},
    {'1': 'PROGRESSION_RULE_ALL_SETS_MATCH_TARGET', '2': 2},
    {'1': 'PROGRESSION_RULE_TOP_SET_AMRAP', '2': 3},
  ],
};

/// Descriptor for `ProgressionRule`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List progressionRuleDescriptor = $convert.base64Decode(
    'Cg9Qcm9ncmVzc2lvblJ1bGUSIAocUFJPR1JFU1NJT05fUlVMRV9VTlNQRUNJRklFRBAAEhkKFV'
    'BST0dSRVNTSU9OX1JVTEVfTk9ORRABEioKJlBST0dSRVNTSU9OX1JVTEVfQUxMX1NFVFNfTUFU'
    'Q0hfVEFSR0VUEAISIgoeUFJPR1JFU1NJT05fUlVMRV9UT1BfU0VUX0FNUkFQEAM=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'profile_emoji', '3': 4, '4': 1, '5': 9, '10': 'profileEmoji'},
    {'1': 'profile_color_hex', '3': 5, '4': 1, '5': 9, '10': 'profileColorHex'},
    {'1': 'body_weight_kg', '3': 6, '4': 1, '5': 2, '10': 'bodyWeightKg'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCmNyZWF0ZWRfYX'
    'QYAyABKANSCWNyZWF0ZWRBdBIjCg1wcm9maWxlX2Vtb2ppGAQgASgJUgxwcm9maWxlRW1vamkS'
    'KgoRcHJvZmlsZV9jb2xvcl9oZXgYBSABKAlSD3Byb2ZpbGVDb2xvckhleBIkCg5ib2R5X3dlaW'
    'dodF9rZxgGIAEoAlIMYm9keVdlaWdodEtn');

@$core.Deprecated('Use workoutDescriptor instead')
const Workout$json = {
  '1': 'Workout',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 3, '10': 'endTime'},
    {'1': 'session_id', '3': 5, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `Workout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDescriptor = $convert.base64Decode(
    'CgdXb3Jrb3V0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YXJ0X3'
    'RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZRIdCgpzZXNz'
    'aW9uX2lkGAUgASgJUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use exerciseTypeConfigDescriptor instead')
const ExerciseTypeConfig$json = {
  '1': 'ExerciseTypeConfig',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'start_weight', '3': 2, '4': 1, '5': 2, '10': 'startWeight'},
    {'1': 'end_weight', '3': 3, '4': 1, '5': 2, '10': 'endWeight'},
    {'1': 'reps', '3': 4, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'include_warmup', '3': 5, '4': 1, '5': 8, '10': 'includeWarmup'},
    {
      '1': 'rest_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {'1': 'last_set_amrap', '3': 7, '4': 1, '5': 8, '10': 'lastSetAmrap'},
    {
      '1': 'working_sets',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkingSetSpec',
      '10': 'workingSets'
    },
  ],
};

/// Descriptor for `ExerciseTypeConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseTypeConfigDescriptor = $convert.base64Decode(
    'ChJFeGVyY2lzZVR5cGVDb25maWcSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZX'
    'JjaXNlUghleGVyY2lzZRIhCgxzdGFydF93ZWlnaHQYAiABKAJSC3N0YXJ0V2VpZ2h0Eh0KCmVu'
    'ZF93ZWlnaHQYAyABKAJSCWVuZFdlaWdodBISCgRyZXBzGAQgASgFUgRyZXBzEiUKDmluY2x1ZG'
    'Vfd2FybXVwGAUgASgIUg1pbmNsdWRlV2FybXVwEjcKC3Jlc3RfY29uZmlnGAYgASgLMhYud29y'
    'a291dC52MS5SZXN0Q29uZmlnUgpyZXN0Q29uZmlnEiQKDmxhc3Rfc2V0X2FtcmFwGAcgASgIUg'
    'xsYXN0U2V0QW1yYXASPQoMd29ya2luZ19zZXRzGAggAygLMhoud29ya291dC52MS5Xb3JraW5n'
    'U2V0U3BlY1ILd29ya2luZ1NldHM=');

@$core.Deprecated('Use workingSetSpecDescriptor instead')
const WorkingSetSpec$json = {
  '1': 'WorkingSetSpec',
  '2': [
    {'1': 'target_weight', '3': 1, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'target_reps', '3': 2, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'is_amrap', '3': 3, '4': 1, '5': 8, '10': 'isAmrap'},
    {'1': 'instruction', '3': 4, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'progression_hint',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgressionHint',
      '10': 'progressionHint'
    },
  ],
};

/// Descriptor for `WorkingSetSpec`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workingSetSpecDescriptor = $convert.base64Decode(
    'Cg5Xb3JraW5nU2V0U3BlYxIjCg10YXJnZXRfd2VpZ2h0GAEgASgCUgx0YXJnZXRXZWlnaHQSHw'
    'oLdGFyZ2V0X3JlcHMYAiABKAVSCnRhcmdldFJlcHMSGQoIaXNfYW1yYXAYAyABKAhSB2lzQW1y'
    'YXASIAoLaW5zdHJ1Y3Rpb24YBCABKAlSC2luc3RydWN0aW9uEkYKEHByb2dyZXNzaW9uX2hpbn'
    'QYBSABKAsyGy53b3Jrb3V0LnYxLlByb2dyZXNzaW9uSGludFIPcHJvZ3Jlc3Npb25IaW50');

@$core.Deprecated('Use restConfigDescriptor instead')
const RestConfig$json = {
  '1': 'RestConfig',
  '2': [
    {
      '1': 'rest_after_success',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'restAfterSuccess'
    },
    {
      '1': 'rest_after_failure',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'restAfterFailure'
    },
    {'1': 'rest_after_warmup', '3': 3, '4': 1, '5': 5, '10': 'restAfterWarmup'},
    {
      '1': 'rest_after_last_warmup',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'restAfterLastWarmup'
    },
  ],
};

/// Descriptor for `RestConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restConfigDescriptor = $convert.base64Decode(
    'CgpSZXN0Q29uZmlnEiwKEnJlc3RfYWZ0ZXJfc3VjY2VzcxgBIAEoBVIQcmVzdEFmdGVyU3VjY2'
    'VzcxIsChJyZXN0X2FmdGVyX2ZhaWx1cmUYAiABKAVSEHJlc3RBZnRlckZhaWx1cmUSKgoRcmVz'
    'dF9hZnRlcl93YXJtdXAYAyABKAVSD3Jlc3RBZnRlcldhcm11cBIzChZyZXN0X2FmdGVyX2xhc3'
    'Rfd2FybXVwGAQgASgFUhNyZXN0QWZ0ZXJMYXN0V2FybXVw');

@$core.Deprecated('Use exerciseGroupDescriptor instead')
const ExerciseGroup$json = {
  '1': 'ExerciseGroup',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {'1': 'workout_order', '3': 6, '4': 1, '5': 5, '10': 'workoutOrder'},
    {
      '1': 'exercise_configs',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {'1': 'instruction', '3': 9, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'prescribed_by_regime',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'prescribedByRegime'
    },
  ],
};

/// Descriptor for `ExerciseGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseGroupDescriptor = $convert.base64Decode(
    'Cg1FeGVyY2lzZUdyb3VwEg4KAmlkGAEgASgJUgJpZBIdCgp3b3Jrb3V0X2lkGAIgASgJUgl3b3'
    'Jrb3V0SWQSEgoEbmFtZRgDIAEoCVIEbmFtZRISCgRzZXRzGAQgASgFUgRzZXRzEi0KEmludGVy'
    'bGVhdmVfd2FybXVwcxgFIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMSIwoNd29ya291dF9vcmRlch'
    'gGIAEoBVIMd29ya291dE9yZGVyEkkKEGV4ZXJjaXNlX2NvbmZpZ3MYByADKAsyHi53b3Jrb3V0'
    'LnYxLkV4ZXJjaXNlVHlwZUNvbmZpZ1IPZXhlcmNpc2VDb25maWdzEjcKC3Jlc3RfY29uZmlnGA'
    'ggASgLMhYud29ya291dC52MS5SZXN0Q29uZmlnUgpyZXN0Q29uZmlnEiAKC2luc3RydWN0aW9u'
    'GAkgASgJUgtpbnN0cnVjdGlvbhIwChRwcmVzY3JpYmVkX2J5X3JlZ2ltZRgKIAEoCFIScHJlc2'
    'NyaWJlZEJ5UmVnaW1l');

@$core.Deprecated('Use proposedSetDescriptor instead')
const ProposedSet$json = {
  '1': 'ProposedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'workout_order', '3': 3, '4': 1, '5': 5, '10': 'workoutOrder'},
    {
      '1': 'exercise',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'target_reps', '3': 5, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'target_weight', '3': 6, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'warmup', '3': 7, '4': 1, '5': 8, '10': 'warmup'},
    {'1': 'exercise_group_id', '3': 8, '4': 1, '5': 9, '10': 'exerciseGroupId'},
    {
      '1': 'rest_after_success',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'restAfterSuccess'
    },
    {
      '1': 'rest_after_failure',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'restAfterFailure'
    },
    {'1': 'cancelled', '3': 11, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'is_amrap', '3': 12, '4': 1, '5': 8, '10': 'isAmrap'},
    {'1': 'instruction', '3': 13, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'progression_hint',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgressionHint',
      '10': 'progressionHint'
    },
  ],
};

/// Descriptor for `ProposedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedSetDescriptor = $convert.base64Decode(
    'CgtQcm9wb3NlZFNldBIOCgJpZBgBIAEoCVICaWQSHQoKd29ya291dF9pZBgCIAEoCVIJd29ya2'
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIwCghleGVyY2lzZRgE'
    'IAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEh8KC3RhcmdldF9yZXBzGAUgAS'
    'gFUgp0YXJnZXRSZXBzEiMKDXRhcmdldF93ZWlnaHQYBiABKAJSDHRhcmdldFdlaWdodBIWCgZ3'
    'YXJtdXAYByABKAhSBndhcm11cBIqChFleGVyY2lzZV9ncm91cF9pZBgIIAEoCVIPZXhlcmNpc2'
    'VHcm91cElkEiwKEnJlc3RfYWZ0ZXJfc3VjY2VzcxgJIAEoBVIQcmVzdEFmdGVyU3VjY2VzcxIs'
    'ChJyZXN0X2FmdGVyX2ZhaWx1cmUYCiABKAVSEHJlc3RBZnRlckZhaWx1cmUSHAoJY2FuY2VsbG'
    'VkGAsgASgIUgljYW5jZWxsZWQSGQoIaXNfYW1yYXAYDCABKAhSB2lzQW1yYXASIAoLaW5zdHJ1'
    'Y3Rpb24YDSABKAlSC2luc3RydWN0aW9uEkYKEHByb2dyZXNzaW9uX2hpbnQYDiABKAsyGy53b3'
    'Jrb3V0LnYxLlByb2dyZXNzaW9uSGludFIPcHJvZ3Jlc3Npb25IaW50');

@$core.Deprecated('Use completedSetDescriptor instead')
const CompletedSet$json = {
  '1': 'CompletedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 3, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 4, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 5, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'started_at', '3': 6, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'ended_at', '3': 7, '4': 1, '5': 3, '10': 'endedAt'},
    {'1': 'rest_until', '3': 8, '4': 1, '5': 3, '10': 'restUntil'},
  ],
};

/// Descriptor for `CompletedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completedSetDescriptor = $convert.base64Decode(
    'CgxDb21wbGV0ZWRTZXQSDgoCaWQYASABKAlSAmlkEh0KCndvcmtvdXRfaWQYAiABKAlSCXdvcm'
    'tvdXRJZBImCg9wcm9wb3NlZF9zZXRfaWQYAyABKAlSDXByb3Bvc2VkU2V0SWQSHwoLYWN0dWFs'
    'X3JlcHMYBCABKAVSCmFjdHVhbFJlcHMSIwoNYWN0dWFsX3dlaWdodBgFIAEoAlIMYWN0dWFsV2'
    'VpZ2h0Eh0KCnN0YXJ0ZWRfYXQYBiABKANSCXN0YXJ0ZWRBdBIZCghlbmRlZF9hdBgHIAEoA1IH'
    'ZW5kZWRBdBIdCgpyZXN0X3VudGlsGAggASgDUglyZXN0VW50aWw=');

@$core.Deprecated('Use progressionDetailsDescriptor instead')
const ProgressionDetails$json = {
  '1': 'ProgressionDetails',
  '2': [
    {
      '1': 'change_kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ProgressionChangeKind',
      '10': 'changeKind'
    },
    {
      '1': 'metric_kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ProgressionMetricKind',
      '10': 'metricKind'
    },
    {'1': 'previous_weight', '3': 3, '4': 1, '5': 2, '10': 'previousWeight'},
    {'1': 'next_weight', '3': 4, '4': 1, '5': 2, '10': 'nextWeight'},
    {'1': 'previous_stage', '3': 5, '4': 1, '5': 9, '10': 'previousStage'},
    {'1': 'next_stage', '3': 6, '4': 1, '5': 9, '10': 'nextStage'},
    {'1': 'source_workout_id', '3': 7, '4': 1, '5': 9, '10': 'sourceWorkoutId'},
    {'1': 'context_label', '3': 8, '4': 1, '5': 9, '10': 'contextLabel'},
    {
      '1': 'reason_kind',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ProgressionReasonKind',
      '10': 'reasonKind'
    },
    {'1': 'reason_text', '3': 10, '4': 1, '5': 9, '10': 'reasonText'},
  ],
};

/// Descriptor for `ProgressionDetails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List progressionDetailsDescriptor = $convert.base64Decode(
    'ChJQcm9ncmVzc2lvbkRldGFpbHMSQgoLY2hhbmdlX2tpbmQYASABKA4yIS53b3Jrb3V0LnYxLl'
    'Byb2dyZXNzaW9uQ2hhbmdlS2luZFIKY2hhbmdlS2luZBJCCgttZXRyaWNfa2luZBgCIAEoDjIh'
    'LndvcmtvdXQudjEuUHJvZ3Jlc3Npb25NZXRyaWNLaW5kUgptZXRyaWNLaW5kEicKD3ByZXZpb3'
    'VzX3dlaWdodBgDIAEoAlIOcHJldmlvdXNXZWlnaHQSHwoLbmV4dF93ZWlnaHQYBCABKAJSCm5l'
    'eHRXZWlnaHQSJQoOcHJldmlvdXNfc3RhZ2UYBSABKAlSDXByZXZpb3VzU3RhZ2USHQoKbmV4dF'
    '9zdGFnZRgGIAEoCVIJbmV4dFN0YWdlEioKEXNvdXJjZV93b3Jrb3V0X2lkGAcgASgJUg9zb3Vy'
    'Y2VXb3Jrb3V0SWQSIwoNY29udGV4dF9sYWJlbBgIIAEoCVIMY29udGV4dExhYmVsEkIKC3JlYX'
    'Nvbl9raW5kGAkgASgOMiEud29ya291dC52MS5Qcm9ncmVzc2lvblJlYXNvbktpbmRSCnJlYXNv'
    'bktpbmQSHwoLcmVhc29uX3RleHQYCiABKAlSCnJlYXNvblRleHQ=');

@$core.Deprecated('Use userMessageDetailsDescriptor instead')
const UserMessageDetails$json = {
  '1': 'UserMessageDetails',
  '2': [
    {
      '1': 'progression',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgressionDetails',
      '9': 0,
      '10': 'progression'
    },
  ],
  '8': [
    {'1': 'detail'},
  ],
};

/// Descriptor for `UserMessageDetails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userMessageDetailsDescriptor = $convert.base64Decode(
    'ChJVc2VyTWVzc2FnZURldGFpbHMSQgoLcHJvZ3Jlc3Npb24YASABKAsyHi53b3Jrb3V0LnYxLl'
    'Byb2dyZXNzaW9uRGV0YWlsc0gAUgtwcm9ncmVzc2lvbkIICgZkZXRhaWw=');

@$core.Deprecated('Use userMessageDescriptor instead')
const UserMessage$json = {
  '1': 'UserMessage',
  '2': [
    {'1': 'message_key', '3': 1, '4': 1, '5': 9, '10': 'messageKey'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.UserMessageKind',
      '10': 'kind'
    },
    {
      '1': 'surface',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.UserMessageSurface',
      '10': 'surface'
    },
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'body', '3': 5, '4': 1, '5': 9, '10': 'body'},
    {'1': 'dismissible', '3': 6, '4': 1, '5': 8, '10': 'dismissible'},
    {'1': 'created_at', '3': 7, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'updated_at', '3': 8, '4': 1, '5': 3, '10': 'updatedAt'},
    {'1': 'workout_id', '3': 9, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise_group_id',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'exerciseGroupId'
    },
    {
      '1': 'exercise',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'slot_key', '3': 12, '4': 1, '5': 9, '10': 'slotKey'},
    {
      '1': 'details',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.UserMessageDetails',
      '10': 'details'
    },
    {
      '1': 'source_workout_id',
      '3': 15,
      '4': 1,
      '5': 9,
      '10': 'sourceWorkoutId'
    },
  ],
  '9': [
    {'1': 13, '2': 14},
  ],
  '10': ['metadata_json'],
};

/// Descriptor for `UserMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userMessageDescriptor = $convert.base64Decode(
    'CgtVc2VyTWVzc2FnZRIfCgttZXNzYWdlX2tleRgBIAEoCVIKbWVzc2FnZUtleRIvCgRraW5kGA'
    'IgASgOMhsud29ya291dC52MS5Vc2VyTWVzc2FnZUtpbmRSBGtpbmQSOAoHc3VyZmFjZRgDIAEo'
    'DjIeLndvcmtvdXQudjEuVXNlck1lc3NhZ2VTdXJmYWNlUgdzdXJmYWNlEhQKBXRpdGxlGAQgAS'
    'gJUgV0aXRsZRISCgRib2R5GAUgASgJUgRib2R5EiAKC2Rpc21pc3NpYmxlGAYgASgIUgtkaXNt'
    'aXNzaWJsZRIdCgpjcmVhdGVkX2F0GAcgASgDUgljcmVhdGVkQXQSHQoKdXBkYXRlZF9hdBgIIA'
    'EoA1IJdXBkYXRlZEF0Eh0KCndvcmtvdXRfaWQYCSABKAlSCXdvcmtvdXRJZBIqChFleGVyY2lz'
    'ZV9ncm91cF9pZBgKIAEoCVIPZXhlcmNpc2VHcm91cElkEjAKCGV4ZXJjaXNlGAsgASgOMhQud2'
    '9ya291dC52MS5FeGVyY2lzZVIIZXhlcmNpc2USGQoIc2xvdF9rZXkYDCABKAlSB3Nsb3RLZXkS'
    'OAoHZGV0YWlscxgOIAEoCzIeLndvcmtvdXQudjEuVXNlck1lc3NhZ2VEZXRhaWxzUgdkZXRhaW'
    'xzEioKEXNvdXJjZV93b3Jrb3V0X2lkGA8gASgJUg9zb3VyY2VXb3Jrb3V0SWRKBAgNEA5SDW1l'
    'dGFkYXRhX2pzb24=');

@$core.Deprecated('Use startWorkoutRequestDescriptor instead')
const StartWorkoutRequest$json = {
  '1': 'StartWorkoutRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'exercise_groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
  ],
};

/// Descriptor for `StartWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFdvcmtvdXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSQgoPZXhlcmNpc2VfZ3'
    'JvdXBzGAIgAygLMhkud29ya291dC52MS5FeGVyY2lzZUdyb3VwUg5leGVyY2lzZUdyb3VwcxId'
    'CgpzdGFydGVkX2F0GAMgASgDUglzdGFydGVkQXQ=');

@$core.Deprecated('Use startWorkoutResponseDescriptor instead')
const StartWorkoutResponse$json = {
  '1': 'StartWorkoutResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'workout',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
    {
      '1': 'exercise_groups',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {
      '1': 'proposed_sets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
    {
      '1': 'next_up_set',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `StartWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutResponseDescriptor = $convert.base64Decode(
    'ChRTdGFydFdvcmtvdXRSZXNwb25zZRIOCgJpZBgBIAEoCVICaWQSLQoHd29ya291dBgCIAEoCz'
    'ITLndvcmtvdXQudjEuV29ya291dFIHd29ya291dBJCCg9leGVyY2lzZV9ncm91cHMYAyADKAsy'
    'GS53b3Jrb3V0LnYxLkV4ZXJjaXNlR3JvdXBSDmV4ZXJjaXNlR3JvdXBzEjwKDXByb3Bvc2VkX3'
    'NldHMYBCADKAsyFy53b3Jrb3V0LnYxLlByb3Bvc2VkU2V0Ugxwcm9wb3NlZFNldHMSPwoOY29t'
    'cGxldGVkX3NldHMYBSADKAsyGC53b3Jrb3V0LnYxLkNvbXBsZXRlZFNldFINY29tcGxldGVkU2'
    'V0cxI3CgtuZXh0X3VwX3NldBgGIAEoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRV'
    'cFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgHIAEoCzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU2'
    '5hcHNob3RSDXN0YXRlU25hcHNob3QSPAoNdXNlcl9tZXNzYWdlcxgIIAMoCzIXLndvcmtvdXQu'
    'djEuVXNlck1lc3NhZ2VSDHVzZXJNZXNzYWdlcw==');

@$core.Deprecated('Use getWorkoutRequestDescriptor instead')
const GetWorkoutRequest$json = {
  '1': 'GetWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `GetWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutRequestDescriptor = $convert.base64Decode(
    'ChFHZXRXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQ=');

@$core.Deprecated('Use exerciseSummaryDescriptor instead')
const ExerciseSummary$json = {
  '1': 'ExerciseSummary',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'total_sets', '3': 2, '4': 1, '5': 5, '10': 'totalSets'},
    {'1': 'total_reps', '3': 3, '4': 1, '5': 5, '10': 'totalReps'},
    {'1': 'total_volume', '3': 4, '4': 1, '5': 2, '10': 'totalVolume'},
    {'1': 'best_one_rep_max', '3': 5, '4': 1, '5': 2, '10': 'bestOneRepMax'},
    {
      '1': 'heaviest_set_weight',
      '3': 6,
      '4': 1,
      '5': 2,
      '10': 'heaviestSetWeight'
    },
  ],
};

/// Descriptor for `ExerciseSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseSummaryDescriptor = $convert.base64Decode(
    'Cg9FeGVyY2lzZVN1bW1hcnkSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaX'
    'NlUghleGVyY2lzZRIdCgp0b3RhbF9zZXRzGAIgASgFUgl0b3RhbFNldHMSHQoKdG90YWxfcmVw'
    'cxgDIAEoBVIJdG90YWxSZXBzEiEKDHRvdGFsX3ZvbHVtZRgEIAEoAlILdG90YWxWb2x1bWUSJw'
    'oQYmVzdF9vbmVfcmVwX21heBgFIAEoAlINYmVzdE9uZVJlcE1heBIuChNoZWF2aWVzdF9zZXRf'
    'd2VpZ2h0GAYgASgCUhFoZWF2aWVzdFNldFdlaWdodA==');

@$core.Deprecated('Use workoutSummaryDescriptor instead')
const WorkoutSummary$json = {
  '1': 'WorkoutSummary',
  '2': [
    {'1': 'total_volume', '3': 1, '4': 1, '5': 2, '10': 'totalVolume'},
    {'1': 'duration_seconds', '3': 2, '4': 1, '5': 3, '10': 'durationSeconds'},
    {'1': 'lifting_seconds', '3': 3, '4': 1, '5': 3, '10': 'liftingSeconds'},
    {'1': 'resting_seconds', '3': 4, '4': 1, '5': 3, '10': 'restingSeconds'},
    {'1': 'yapping_seconds', '3': 5, '4': 1, '5': 3, '10': 'yappingSeconds'},
    {'1': 'volume_per_minute', '3': 6, '4': 1, '5': 2, '10': 'volumePerMinute'},
    {'1': 'work_rest_ratio', '3': 7, '4': 1, '5': 2, '10': 'workRestRatio'},
    {
      '1': 'exercises',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseSummary',
      '10': 'exercises'
    },
  ],
};

/// Descriptor for `WorkoutSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutSummaryDescriptor = $convert.base64Decode(
    'Cg5Xb3Jrb3V0U3VtbWFyeRIhCgx0b3RhbF92b2x1bWUYASABKAJSC3RvdGFsVm9sdW1lEikKEG'
    'R1cmF0aW9uX3NlY29uZHMYAiABKANSD2R1cmF0aW9uU2Vjb25kcxInCg9saWZ0aW5nX3NlY29u'
    'ZHMYAyABKANSDmxpZnRpbmdTZWNvbmRzEicKD3Jlc3Rpbmdfc2Vjb25kcxgEIAEoA1IOcmVzdG'
    'luZ1NlY29uZHMSJwoPeWFwcGluZ19zZWNvbmRzGAUgASgDUg55YXBwaW5nU2Vjb25kcxIqChF2'
    'b2x1bWVfcGVyX21pbnV0ZRgGIAEoAlIPdm9sdW1lUGVyTWludXRlEiYKD3dvcmtfcmVzdF9yYX'
    'RpbxgHIAEoAlINd29ya1Jlc3RSYXRpbxI5CglleGVyY2lzZXMYCCADKAsyGy53b3Jrb3V0LnYx'
    'LkV4ZXJjaXNlU3VtbWFyeVIJZXhlcmNpc2Vz');

@$core.Deprecated('Use getWorkoutResponseDescriptor instead')
const GetWorkoutResponse$json = {
  '1': 'GetWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
    {
      '1': 'exercise_groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {
      '1': 'proposed_sets',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
    {
      '1': 'next_up_set',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'plan_change_stats',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutPlanChangeStats',
      '10': 'planChangeStats'
    },
    {
      '1': 'state_snapshot',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
    {
      '1': 'summary',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutSummary',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `GetWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJHZXRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBJCCg9leGVyY2lzZV9ncm91cHMYAiADKAsyGS53b3Jrb3V0LnYxLkV4ZXJj'
    'aXNlR3JvdXBSDmV4ZXJjaXNlR3JvdXBzEjwKDXByb3Bvc2VkX3NldHMYAyADKAsyFy53b3Jrb3'
    'V0LnYxLlByb3Bvc2VkU2V0Ugxwcm9wb3NlZFNldHMSPwoOY29tcGxldGVkX3NldHMYBCADKAsy'
    'GC53b3Jrb3V0LnYxLkNvbXBsZXRlZFNldFINY29tcGxldGVkU2V0cxI3CgtuZXh0X3VwX3NldB'
    'gFIAEoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJOChFwbGFuX2NoYW5n'
    'ZV9zdGF0cxgGIAEoCzIiLndvcmtvdXQudjEuV29ya291dFBsYW5DaGFuZ2VTdGF0c1IPcGxhbk'
    'NoYW5nZVN0YXRzEkcKDnN0YXRlX3NuYXBzaG90GAcgASgLMiAud29ya291dC52MS5Xb3Jrb3V0'
    'U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdBI8Cg11c2VyX21lc3NhZ2VzGAggAygLMhcud2'
    '9ya291dC52MS5Vc2VyTWVzc2FnZVIMdXNlck1lc3NhZ2VzEjQKB3N1bW1hcnkYCSABKAsyGi53'
    'b3Jrb3V0LnYxLldvcmtvdXRTdW1tYXJ5UgdzdW1tYXJ5');

@$core.Deprecated('Use workoutPlanChangeStatsDescriptor instead')
const WorkoutPlanChangeStats$json = {
  '1': 'WorkoutPlanChangeStats',
  '2': [
    {'1': 'cancelled_total', '3': 1, '4': 1, '5': 5, '10': 'cancelledTotal'},
    {
      '1': 'cancelled_warmups',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'cancelledWarmups'
    },
    {
      '1': 'cancelled_working',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'cancelledWorking'
    },
  ],
};

/// Descriptor for `WorkoutPlanChangeStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutPlanChangeStatsDescriptor = $convert.base64Decode(
    'ChZXb3Jrb3V0UGxhbkNoYW5nZVN0YXRzEicKD2NhbmNlbGxlZF90b3RhbBgBIAEoBVIOY2FuY2'
    'VsbGVkVG90YWwSKwoRY2FuY2VsbGVkX3dhcm11cHMYAiABKAVSEGNhbmNlbGxlZFdhcm11cHMS'
    'KwoRY2FuY2VsbGVkX3dvcmtpbmcYAyABKAVSEGNhbmNlbGxlZFdvcmtpbmc=');

@$core.Deprecated('Use workoutStateSnapshotDescriptor instead')
const WorkoutStateSnapshot$json = {
  '1': 'WorkoutStateSnapshot',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WorkoutState',
      '10': 'state'
    },
    {
      '1': 'display_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'displaySet'
    },
    {'1': 'active_started_at', '3': 3, '4': 1, '5': 3, '10': 'activeStartedAt'},
    {'1': 'rest_until', '3': 4, '4': 1, '5': 3, '10': 'restUntil'},
    {'1': 'last_rest_end', '3': 5, '4': 1, '5': 3, '10': 'lastRestEnd'},
  ],
};

/// Descriptor for `WorkoutStateSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutStateSnapshotDescriptor = $convert.base64Decode(
    'ChRXb3Jrb3V0U3RhdGVTbmFwc2hvdBIuCgVzdGF0ZRgBIAEoDjIYLndvcmtvdXQudjEuV29ya2'
    '91dFN0YXRlUgVzdGF0ZRI4CgtkaXNwbGF5X3NldBgCIAEoCzIXLndvcmtvdXQudjEuUHJvcG9z'
    'ZWRTZXRSCmRpc3BsYXlTZXQSKgoRYWN0aXZlX3N0YXJ0ZWRfYXQYAyABKANSD2FjdGl2ZVN0YX'
    'J0ZWRBdBIdCgpyZXN0X3VudGlsGAQgASgDUglyZXN0VW50aWwSIgoNbGFzdF9yZXN0X2VuZBgF'
    'IAEoA1ILbGFzdFJlc3RFbmQ=');

@$core.Deprecated('Use listWorkoutsRequestDescriptor instead')
const ListWorkoutsRequest$json = {
  '1': 'ListWorkoutsRequest',
};

/// Descriptor for `ListWorkoutsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutsRequestDescriptor =
    $convert.base64Decode('ChNMaXN0V29ya291dHNSZXF1ZXN0');

@$core.Deprecated('Use listWorkoutsResponseDescriptor instead')
const ListWorkoutsResponse$json = {
  '1': 'ListWorkoutsResponse',
  '2': [
    {
      '1': 'workouts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workouts'
    },
  ],
};

/// Descriptor for `ListWorkoutsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0V29ya291dHNSZXNwb25zZRIvCgh3b3Jrb3V0cxgBIAMoCzITLndvcmtvdXQudjEuV2'
    '9ya291dFIId29ya291dHM=');

@$core.Deprecated('Use workoutWithSummaryDescriptor instead')
const WorkoutWithSummary$json = {
  '1': 'WorkoutWithSummary',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
    {
      '1': 'summary',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutSummary',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `WorkoutWithSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutWithSummaryDescriptor = $convert.base64Decode(
    'ChJXb3Jrb3V0V2l0aFN1bW1hcnkSLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBI0CgdzdW1tYXJ5GAIgASgLMhoud29ya291dC52MS5Xb3Jrb3V0U3VtbWFy'
    'eVIHc3VtbWFyeQ==');

@$core.Deprecated('Use listWorkoutSummariesRequestDescriptor instead')
const ListWorkoutSummariesRequest$json = {
  '1': 'ListWorkoutSummariesRequest',
};

/// Descriptor for `ListWorkoutSummariesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutSummariesRequestDescriptor =
    $convert.base64Decode('ChtMaXN0V29ya291dFN1bW1hcmllc1JlcXVlc3Q=');

@$core.Deprecated('Use listWorkoutSummariesResponseDescriptor instead')
const ListWorkoutSummariesResponse$json = {
  '1': 'ListWorkoutSummariesResponse',
  '2': [
    {
      '1': 'workouts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutWithSummary',
      '10': 'workouts'
    },
  ],
};

/// Descriptor for `ListWorkoutSummariesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutSummariesResponseDescriptor =
    $convert.base64Decode(
        'ChxMaXN0V29ya291dFN1bW1hcmllc1Jlc3BvbnNlEjoKCHdvcmtvdXRzGAEgAygLMh4ud29ya2'
        '91dC52MS5Xb3Jrb3V0V2l0aFN1bW1hcnlSCHdvcmtvdXRz');

@$core.Deprecated('Use exerciseProgressPointDescriptor instead')
const ExerciseProgressPoint$json = {
  '1': 'ExerciseProgressPoint',
  '2': [
    {'1': 'date', '3': 1, '4': 1, '5': 3, '10': 'date'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'top_weight', '3': 3, '4': 1, '5': 2, '10': 'topWeight'},
    {'1': 'top_reps', '3': 4, '4': 1, '5': 5, '10': 'topReps'},
    {'1': 'best_one_rep_max', '3': 5, '4': 1, '5': 2, '10': 'bestOneRepMax'},
    {'1': 'volume', '3': 6, '4': 1, '5': 2, '10': 'volume'},
    {'1': 'sets', '3': 7, '4': 1, '5': 5, '10': 'sets'},
  ],
};

/// Descriptor for `ExerciseProgressPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseProgressPointDescriptor = $convert.base64Decode(
    'ChVFeGVyY2lzZVByb2dyZXNzUG9pbnQSEgoEZGF0ZRgBIAEoA1IEZGF0ZRIdCgp3b3Jrb3V0X2'
    'lkGAIgASgJUgl3b3Jrb3V0SWQSHQoKdG9wX3dlaWdodBgDIAEoAlIJdG9wV2VpZ2h0EhkKCHRv'
    'cF9yZXBzGAQgASgFUgd0b3BSZXBzEicKEGJlc3Rfb25lX3JlcF9tYXgYBSABKAJSDWJlc3RPbm'
    'VSZXBNYXgSFgoGdm9sdW1lGAYgASgCUgZ2b2x1bWUSEgoEc2V0cxgHIAEoBVIEc2V0cw==');

@$core.Deprecated('Use exerciseProgressDescriptor instead')
const ExerciseProgress$json = {
  '1': 'ExerciseProgress',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {
      '1': 'points',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseProgressPoint',
      '10': 'points'
    },
  ],
};

/// Descriptor for `ExerciseProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseProgressDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZVByb2dyZXNzEjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC52MS5FeGVyY2'
    'lzZVIIZXhlcmNpc2USOQoGcG9pbnRzGAIgAygLMiEud29ya291dC52MS5FeGVyY2lzZVByb2dy'
    'ZXNzUG9pbnRSBnBvaW50cw==');

@$core.Deprecated('Use recommendedWeightDescriptor instead')
const RecommendedWeight$json = {
  '1': 'RecommendedWeight',
  '2': [
    {'1': 'field_key', '3': 1, '4': 1, '5': 9, '10': 'fieldKey'},
    {'1': 'pounds', '3': 2, '4': 1, '5': 2, '10': 'pounds'},
  ],
};

/// Descriptor for `RecommendedWeight`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recommendedWeightDescriptor = $convert.base64Decode(
    'ChFSZWNvbW1lbmRlZFdlaWdodBIbCglmaWVsZF9rZXkYASABKAlSCGZpZWxkS2V5EhYKBnBvdW'
    '5kcxgCIAEoAlIGcG91bmRz');

@$core.Deprecated('Use getRecommendedStartingWeightsRequestDescriptor instead')
const GetRecommendedStartingWeightsRequest$json = {
  '1': 'GetRecommendedStartingWeightsRequest',
  '2': [
    {'1': 'bodyweight_kg', '3': 1, '4': 1, '5': 1, '10': 'bodyweightKg'},
    {
      '1': 'experience',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ExperienceLevel',
      '10': 'experience'
    },
  ],
};

/// Descriptor for `GetRecommendedStartingWeightsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRecommendedStartingWeightsRequestDescriptor =
    $convert.base64Decode(
        'CiRHZXRSZWNvbW1lbmRlZFN0YXJ0aW5nV2VpZ2h0c1JlcXVlc3QSIwoNYm9keXdlaWdodF9rZx'
        'gBIAEoAVIMYm9keXdlaWdodEtnEjsKCmV4cGVyaWVuY2UYAiABKA4yGy53b3Jrb3V0LnYxLkV4'
        'cGVyaWVuY2VMZXZlbFIKZXhwZXJpZW5jZQ==');

@$core.Deprecated('Use getRecommendedStartingWeightsResponseDescriptor instead')
const GetRecommendedStartingWeightsResponse$json = {
  '1': 'GetRecommendedStartingWeightsResponse',
  '2': [
    {
      '1': 'weights',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.RecommendedWeight',
      '10': 'weights'
    },
  ],
};

/// Descriptor for `GetRecommendedStartingWeightsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRecommendedStartingWeightsResponseDescriptor =
    $convert.base64Decode(
        'CiVHZXRSZWNvbW1lbmRlZFN0YXJ0aW5nV2VpZ2h0c1Jlc3BvbnNlEjcKB3dlaWdodHMYASADKA'
        'syHS53b3Jrb3V0LnYxLlJlY29tbWVuZGVkV2VpZ2h0Ugd3ZWlnaHRz');

@$core.Deprecated('Use getExerciseProgressRequestDescriptor instead')
const GetExerciseProgressRequest$json = {
  '1': 'GetExerciseProgressRequest',
};

/// Descriptor for `GetExerciseProgressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExerciseProgressRequestDescriptor =
    $convert.base64Decode('ChpHZXRFeGVyY2lzZVByb2dyZXNzUmVxdWVzdA==');

@$core.Deprecated('Use getExerciseProgressResponseDescriptor instead')
const GetExerciseProgressResponse$json = {
  '1': 'GetExerciseProgressResponse',
  '2': [
    {
      '1': 'exercises',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseProgress',
      '10': 'exercises'
    },
    {'1': 'workout_count', '3': 2, '4': 1, '5': 5, '10': 'workoutCount'},
    {'1': 'total_volume', '3': 3, '4': 1, '5': 2, '10': 'totalVolume'},
    {'1': 'since', '3': 4, '4': 1, '5': 3, '10': 'since'},
  ],
};

/// Descriptor for `GetExerciseProgressResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExerciseProgressResponseDescriptor = $convert.base64Decode(
    'ChtHZXRFeGVyY2lzZVByb2dyZXNzUmVzcG9uc2USOgoJZXhlcmNpc2VzGAEgAygLMhwud29ya2'
    '91dC52MS5FeGVyY2lzZVByb2dyZXNzUglleGVyY2lzZXMSIwoNd29ya291dF9jb3VudBgCIAEo'
    'BVIMd29ya291dENvdW50EiEKDHRvdGFsX3ZvbHVtZRgDIAEoAlILdG90YWxWb2x1bWUSFAoFc2'
    'luY2UYBCABKANSBXNpbmNl');

@$core.Deprecated('Use plannedGroupSetDescriptor instead')
const PlannedGroupSet$json = {
  '1': 'PlannedGroupSet',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'target_reps', '3': 2, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'target_weight', '3': 3, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'warmup', '3': 4, '4': 1, '5': 8, '10': 'warmup'},
    {
      '1': 'rest_after_success',
      '3': 5,
      '4': 1,
      '5': 5,
      '10': 'restAfterSuccess'
    },
    {
      '1': 'rest_after_failure',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'restAfterFailure'
    },
    {'1': 'is_amrap', '3': 7, '4': 1, '5': 8, '10': 'isAmrap'},
    {'1': 'instruction', '3': 8, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'progression_hint',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgressionHint',
      '10': 'progressionHint'
    },
    {'1': 'client_set_id', '3': 10, '4': 1, '5': 9, '10': 'clientSetId'},
  ],
};

/// Descriptor for `PlannedGroupSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plannedGroupSetDescriptor = $convert.base64Decode(
    'Cg9QbGFubmVkR3JvdXBTZXQSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaX'
    'NlUghleGVyY2lzZRIfCgt0YXJnZXRfcmVwcxgCIAEoBVIKdGFyZ2V0UmVwcxIjCg10YXJnZXRf'
    'd2VpZ2h0GAMgASgCUgx0YXJnZXRXZWlnaHQSFgoGd2FybXVwGAQgASgIUgZ3YXJtdXASLAoScm'
    'VzdF9hZnRlcl9zdWNjZXNzGAUgASgFUhByZXN0QWZ0ZXJTdWNjZXNzEiwKEnJlc3RfYWZ0ZXJf'
    'ZmFpbHVyZRgGIAEoBVIQcmVzdEFmdGVyRmFpbHVyZRIZCghpc19hbXJhcBgHIAEoCFIHaXNBbX'
    'JhcBIgCgtpbnN0cnVjdGlvbhgIIAEoCVILaW5zdHJ1Y3Rpb24SRgoQcHJvZ3Jlc3Npb25faGlu'
    'dBgJIAEoCzIbLndvcmtvdXQudjEuUHJvZ3Jlc3Npb25IaW50Ug9wcm9ncmVzc2lvbkhpbnQSIg'
    'oNY2xpZW50X3NldF9pZBgKIAEoCVILY2xpZW50U2V0SWQ=');

@$core.Deprecated('Use progressionHintDescriptor instead')
const ProgressionHint$json = {
  '1': 'ProgressionHint',
  '2': [
    {'1': 'slot_key', '3': 1, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'tier', '3': 2, '4': 1, '5': 9, '10': 'tier'},
    {
      '1': 'rule',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ProgressionRule',
      '10': 'rule'
    },
    {
      '1': 'amrap_success_threshold',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'amrapSuccessThreshold'
    },
    {
      '1': 'counts_toward_program',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'countsTowardProgram'
    },
  ],
};

/// Descriptor for `ProgressionHint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List progressionHintDescriptor = $convert.base64Decode(
    'Cg9Qcm9ncmVzc2lvbkhpbnQSGQoIc2xvdF9rZXkYASABKAlSB3Nsb3RLZXkSEgoEdGllchgCIA'
    'EoCVIEdGllchIvCgRydWxlGAMgASgOMhsud29ya291dC52MS5Qcm9ncmVzc2lvblJ1bGVSBHJ1'
    'bGUSNgoXYW1yYXBfc3VjY2Vzc190aHJlc2hvbGQYBCABKAVSFWFtcmFwU3VjY2Vzc1RocmVzaG'
    '9sZBIyChVjb3VudHNfdG93YXJkX3Byb2dyYW0YBSABKAhSE2NvdW50c1Rvd2FyZFByb2dyYW0=');

@$core.Deprecated('Use replaceExerciseGroupPlanRequestDescriptor instead')
const ReplaceExerciseGroupPlanRequest$json = {
  '1': 'ReplaceExerciseGroupPlanRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise_group_id', '3': 2, '4': 1, '5': 9, '10': 'exerciseGroupId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'interleave_warmups',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'sets',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PlannedGroupSet',
      '10': 'sets'
    },
    {
      '1': 'rest_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {
      '1': 'delete_group_if_empty',
      '3': 7,
      '4': 1,
      '5': 8,
      '10': 'deleteGroupIfEmpty'
    },
    {'1': 'instruction', '3': 8, '4': 1, '5': 9, '10': 'instruction'},
    {'1': 'create_if_missing', '3': 9, '4': 1, '5': 8, '10': 'createIfMissing'},
  ],
};

/// Descriptor for `ReplaceExerciseGroupPlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replaceExerciseGroupPlanRequestDescriptor = $convert.base64Decode(
    'Ch9SZXBsYWNlRXhlcmNpc2VHcm91cFBsYW5SZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCX'
    'dvcmtvdXRJZBIqChFleGVyY2lzZV9ncm91cF9pZBgCIAEoCVIPZXhlcmNpc2VHcm91cElkEhIK'
    'BG5hbWUYAyABKAlSBG5hbWUSLQoSaW50ZXJsZWF2ZV93YXJtdXBzGAQgASgIUhFpbnRlcmxlYX'
    'ZlV2FybXVwcxIvCgRzZXRzGAUgAygLMhsud29ya291dC52MS5QbGFubmVkR3JvdXBTZXRSBHNl'
    'dHMSNwoLcmVzdF9jb25maWcYBiABKAsyFi53b3Jrb3V0LnYxLlJlc3RDb25maWdSCnJlc3RDb2'
    '5maWcSMQoVZGVsZXRlX2dyb3VwX2lmX2VtcHR5GAcgASgIUhJkZWxldGVHcm91cElmRW1wdHkS'
    'IAoLaW5zdHJ1Y3Rpb24YCCABKAlSC2luc3RydWN0aW9uEioKEWNyZWF0ZV9pZl9taXNzaW5nGA'
    'kgASgIUg9jcmVhdGVJZk1pc3Npbmc=');

@$core.Deprecated('Use replaceExerciseGroupPlanResponseDescriptor instead')
const ReplaceExerciseGroupPlanResponse$json = {
  '1': 'ReplaceExerciseGroupPlanResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
    {
      '1': 'generated_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'generatedSets'
    },
    {
      '1': 'next_up_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `ReplaceExerciseGroupPlanResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replaceExerciseGroupPlanResponseDescriptor = $convert.base64Decode(
    'CiBSZXBsYWNlRXhlcmNpc2VHcm91cFBsYW5SZXNwb25zZRIvCgVncm91cBgBIAEoCzIZLndvcm'
    'tvdXQudjEuRXhlcmNpc2VHcm91cFIFZ3JvdXASPgoOZ2VuZXJhdGVkX3NldHMYAiADKAsyFy53'
    'b3Jrb3V0LnYxLlByb3Bvc2VkU2V0Ug1nZW5lcmF0ZWRTZXRzEjcKC25leHRfdXBfc2V0GAMgAS'
    'gLMhcud29ya291dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90'
    'GAQgASgLMiAud29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdA'
    '==');

@$core.Deprecated('Use createExerciseGroupRequestDescriptor instead')
const CreateExerciseGroupRequest$json = {
  '1': 'CreateExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 3, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `CreateExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExerciseGroupRequestDescriptor = $convert.base64Decode(
    'ChpDcmVhdGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
    'V0SWQSEgoEbmFtZRgCIAEoCVIEbmFtZRISCgRzZXRzGAMgASgFUgRzZXRzEi0KEmludGVybGVh'
    'dmVfd2FybXVwcxgEIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMSSQoQZXhlcmNpc2VfY29uZmlncx'
    'gFIAMoCzIeLndvcmtvdXQudjEuRXhlcmNpc2VUeXBlQ29uZmlnUg9leGVyY2lzZUNvbmZpZ3MS'
    'NwoLcmVzdF9jb25maWcYBiABKAsyFi53b3Jrb3V0LnYxLlJlc3RDb25maWdSCnJlc3RDb25maW'
    'c=');

@$core.Deprecated('Use createExerciseGroupResponseDescriptor instead')
const CreateExerciseGroupResponse$json = {
  '1': 'CreateExerciseGroupResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
    {
      '1': 'generated_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'generatedSets'
    },
    {
      '1': 'next_up_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `CreateExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExerciseGroupResponseDescriptor = $convert.base64Decode(
    'ChtDcmVhdGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USLwoFZ3JvdXAYASABKAsyGS53b3Jrb3V0Ln'
    'YxLkV4ZXJjaXNlR3JvdXBSBWdyb3VwEj4KDmdlbmVyYXRlZF9zZXRzGAIgAygLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFINZ2VuZXJhdGVkU2V0cxI3CgtuZXh0X3VwX3NldBgDIAEoCzIXLn'
    'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgEIAEo'
    'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3Q=');

@$core.Deprecated('Use startSetRequestDescriptor instead')
const StartSetRequest$json = {
  '1': 'StartSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
  ],
};

/// Descriptor for `StartSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetRequestDescriptor = $convert.base64Decode(
    'Cg9TdGFydFNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3Byb3'
    'Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZBIdCgpzdGFydGVkX2F0GAMgASgDUglz'
    'dGFydGVkQXQ=');

@$core.Deprecated('Use startSetResponseDescriptor instead')
const StartSetResponse$json = {
  '1': 'StartSetResponse',
  '2': [
    {
      '1': 'completed_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSet'
    },
    {
      '1': 'next_up_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `StartSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetResponseDescriptor = $convert.base64Decode(
    'ChBTdGFydFNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0LnYxLk'
    'NvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0EjcKC25leHRfdXBfc2V0GAIgASgLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAMgASgLMiAud2'
    '9ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdBI8Cg11c2VyX21l'
    'c3NhZ2VzGAQgAygLMhcud29ya291dC52MS5Vc2VyTWVzc2FnZVIMdXNlck1lc3NhZ2Vz');

@$core.Deprecated('Use completeSetRequestDescriptor instead')
const CompleteSetRequest$json = {
  '1': 'CompleteSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 3, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 4, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'completed_at', '3': 5, '4': 1, '5': 3, '10': 'completedAt'},
  ],
};

/// Descriptor for `CompleteSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetRequestDescriptor = $convert.base64Decode(
    'ChJDb21wbGV0ZVNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3'
    'Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZBIfCgthY3R1YWxfcmVwcxgDIAEo'
    'BVIKYWN0dWFsUmVwcxIjCg1hY3R1YWxfd2VpZ2h0GAQgASgCUgxhY3R1YWxXZWlnaHQSIQoMY2'
    '9tcGxldGVkX2F0GAUgASgDUgtjb21wbGV0ZWRBdA==');

@$core.Deprecated('Use completeSetResponseDescriptor instead')
const CompleteSetResponse$json = {
  '1': 'CompleteSetResponse',
  '2': [
    {
      '1': 'completed_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSet'
    },
    {
      '1': 'next_up_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `CompleteSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetResponseDescriptor = $convert.base64Decode(
    'ChNDb21wbGV0ZVNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0Ln'
    'YxLkNvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0EjcKC25leHRfdXBfc2V0GAIgASgLMhcud29y'
    'a291dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAMgASgLMi'
    'Aud29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdBI8Cg11c2Vy'
    'X21lc3NhZ2VzGAQgAygLMhcud29ya291dC52MS5Vc2VyTWVzc2FnZVIMdXNlck1lc3NhZ2Vz');

@$core.Deprecated('Use deleteCompletedSetRequestDescriptor instead')
const DeleteCompletedSetRequest$json = {
  '1': 'DeleteCompletedSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'completed_set_id', '3': 2, '4': 1, '5': 9, '10': 'completedSetId'},
  ],
};

/// Descriptor for `DeleteCompletedSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetRequestDescriptor =
    $convert.base64Decode(
        'ChlEZWxldGVDb21wbGV0ZWRTZXRSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdX'
        'RJZBIoChBjb21wbGV0ZWRfc2V0X2lkGAIgASgJUg5jb21wbGV0ZWRTZXRJZA==');

@$core.Deprecated('Use deleteCompletedSetResponseDescriptor instead')
const DeleteCompletedSetResponse$json = {
  '1': 'DeleteCompletedSetResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `DeleteCompletedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetResponseDescriptor = $convert.base64Decode(
    'ChpEZWxldGVDb21wbGV0ZWRTZXRSZXNwb25zZRI3CgtuZXh0X3VwX3NldBgBIAEoCzIXLndvcm'
    'tvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgCIAEoCzIg'
    'LndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3QSPAoNdXNlcl'
    '9tZXNzYWdlcxgDIAMoCzIXLndvcmtvdXQudjEuVXNlck1lc3NhZ2VSDHVzZXJNZXNzYWdlcw==');

@$core.Deprecated('Use cancelProposedSetRequestDescriptor instead')
const CancelProposedSetRequest$json = {
  '1': 'CancelProposedSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
  ],
};

/// Descriptor for `CancelProposedSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelProposedSetRequestDescriptor =
    $convert.base64Decode(
        'ChhDYW5jZWxQcm9wb3NlZFNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dE'
        'lkEiYKD3Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZA==');

@$core.Deprecated('Use cancelProposedSetResponseDescriptor instead')
const CancelProposedSetResponse$json = {
  '1': 'CancelProposedSetResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `CancelProposedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelProposedSetResponseDescriptor = $convert.base64Decode(
    'ChlDYW5jZWxQcm9wb3NlZFNldFJlc3BvbnNlEjcKC25leHRfdXBfc2V0GAEgASgLMhcud29ya2'
    '91dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAIgASgLMiAu'
    'd29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdBI8Cg11c2VyX2'
    '1lc3NhZ2VzGAMgAygLMhcud29ya291dC52MS5Vc2VyTWVzc2FnZVIMdXNlck1lc3NhZ2Vz');

@$core.Deprecated('Use endWorkoutRequestDescriptor instead')
const EndWorkoutRequest$json = {
  '1': 'EndWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'ended_at', '3': 2, '4': 1, '5': 3, '10': 'endedAt'},
  ],
};

/// Descriptor for `EndWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutRequestDescriptor = $convert.base64Decode(
    'ChFFbmRXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSGQoIZW'
    '5kZWRfYXQYAiABKANSB2VuZGVkQXQ=');

@$core.Deprecated('Use endWorkoutResponseDescriptor instead')
const EndWorkoutResponse$json = {
  '1': 'EndWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
    {
      '1': 'user_messages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `EndWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJFbmRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBI8Cg11c2VyX21lc3NhZ2VzGAIgAygLMhcud29ya291dC52MS5Vc2VyTWVz'
    'c2FnZVIMdXNlck1lc3NhZ2Vz');

@$core.Deprecated('Use getProposedWorkoutScheduleRequestDescriptor instead')
const GetProposedWorkoutScheduleRequest$json = {
  '1': 'GetProposedWorkoutScheduleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'at_time', '3': 2, '4': 1, '5': 3, '10': 'atTime'},
  ],
};

/// Descriptor for `GetProposedWorkoutScheduleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProposedWorkoutScheduleRequestDescriptor =
    $convert.base64Decode(
        'CiFHZXRQcm9wb3NlZFdvcmtvdXRTY2hlZHVsZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdX'
        'NlcklkEhcKB2F0X3RpbWUYAiABKANSBmF0VGltZQ==');

@$core.Deprecated('Use exerciseStatusDescriptor instead')
const ExerciseStatus$json = {
  '1': 'ExerciseStatus',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'target_weight', '3': 2, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'last_performed_at', '3': 3, '4': 1, '5': 3, '10': 'lastPerformedAt'},
    {'1': 'weight_history', '3': 4, '4': 3, '5': 2, '10': 'weightHistory'},
    {
      '1': 'muscle_groups',
      '3': 5,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscleGroups'
    },
    {'1': 'default_sets', '3': 6, '4': 1, '5': 5, '10': 'defaultSets'},
    {'1': 'default_reps', '3': 7, '4': 1, '5': 5, '10': 'defaultReps'},
    {'1': 'recovered', '3': 8, '4': 1, '5': 8, '10': 'recovered'},
    {'1': 'always_include', '3': 9, '4': 1, '5': 8, '10': 'alwaysInclude'},
    {
      '1': 'category',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ExerciseCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `ExerciseStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseStatusDescriptor = $convert.base64Decode(
    'Cg5FeGVyY2lzZVN0YXR1cxIwCghleGVyY2lzZRgBIAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2'
    'VSCGV4ZXJjaXNlEiMKDXRhcmdldF93ZWlnaHQYAiABKAJSDHRhcmdldFdlaWdodBIqChFsYXN0'
    'X3BlcmZvcm1lZF9hdBgDIAEoA1IPbGFzdFBlcmZvcm1lZEF0EiUKDndlaWdodF9oaXN0b3J5GA'
    'QgAygCUg13ZWlnaHRIaXN0b3J5EjwKDW11c2NsZV9ncm91cHMYBSADKA4yFy53b3Jrb3V0LnYx'
    'Lk11c2NsZUdyb3VwUgxtdXNjbGVHcm91cHMSIQoMZGVmYXVsdF9zZXRzGAYgASgFUgtkZWZhdW'
    'x0U2V0cxIhCgxkZWZhdWx0X3JlcHMYByABKAVSC2RlZmF1bHRSZXBzEhwKCXJlY292ZXJlZBgI'
    'IAEoCFIJcmVjb3ZlcmVkEiUKDmFsd2F5c19pbmNsdWRlGAkgASgIUg1hbHdheXNJbmNsdWRlEj'
    'gKCGNhdGVnb3J5GAogASgOMhwud29ya291dC52MS5FeGVyY2lzZUNhdGVnb3J5UghjYXRlZ29y'
    'eQ==');

@$core.Deprecated('Use proposedExerciseGroupDescriptor instead')
const ProposedExerciseGroup$json = {
  '1': 'ProposedExerciseGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 2, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {'1': 'tags', '3': 6, '4': 3, '5': 9, '10': 'tags'},
    {
      '1': 'prescribed_by_regime',
      '3': 7,
      '4': 1,
      '5': 8,
      '10': 'prescribedByRegime'
    },
    {
      '1': 'estimated_duration_seconds',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'estimatedDurationSeconds'
    },
  ],
};

/// Descriptor for `ProposedExerciseGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedExerciseGroupDescriptor = $convert.base64Decode(
    'ChVQcm9wb3NlZEV4ZXJjaXNlR3JvdXASEgoEbmFtZRgBIAEoCVIEbmFtZRISCgRzZXRzGAIgAS'
    'gFUgRzZXRzEi0KEmludGVybGVhdmVfd2FybXVwcxgDIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMS'
    'SQoQZXhlcmNpc2VfY29uZmlncxgEIAMoCzIeLndvcmtvdXQudjEuRXhlcmNpc2VUeXBlQ29uZm'
    'lnUg9leGVyY2lzZUNvbmZpZ3MSNwoLcmVzdF9jb25maWcYBSABKAsyFi53b3Jrb3V0LnYxLlJl'
    'c3RDb25maWdSCnJlc3RDb25maWcSEgoEdGFncxgGIAMoCVIEdGFncxIwChRwcmVzY3JpYmVkX2'
    'J5X3JlZ2ltZRgHIAEoCFIScHJlc2NyaWJlZEJ5UmVnaW1lEjwKGmVzdGltYXRlZF9kdXJhdGlv'
    'bl9zZWNvbmRzGAggASgDUhhlc3RpbWF0ZWREdXJhdGlvblNlY29uZHM=');

@$core.Deprecated('Use slotTrainingStatusDescriptor instead')
const SlotTrainingStatus$json = {
  '1': 'SlotTrainingStatus',
  '2': [
    {'1': 'slot_key', '3': 1, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'tier', '3': 3, '4': 1, '5': 9, '10': 'tier'},
    {'1': 'last_trained_at', '3': 4, '4': 1, '5': 3, '10': 'lastTrainedAt'},
    {
      '1': 'days_since_last_trained',
      '3': 5,
      '4': 1,
      '5': 5,
      '10': 'daysSinceLastTrained'
    },
    {
      '1': 'target_sets_per_7_days',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'targetSetsPer7Days'
    },
    {
      '1': 'completed_sets_per_7_days',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'completedSetsPer7Days'
    },
    {
      '1': 'remaining_sets_per_7_days',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'remainingSetsPer7Days'
    },
    {
      '1': 'appears_in_next_workout',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'appearsInNextWorkout'
    },
    {'1': 'status_label', '3': 10, '4': 1, '5': 9, '10': 'statusLabel'},
  ],
};

/// Descriptor for `SlotTrainingStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List slotTrainingStatusDescriptor = $convert.base64Decode(
    'ChJTbG90VHJhaW5pbmdTdGF0dXMSGQoIc2xvdF9rZXkYASABKAlSB3Nsb3RLZXkSFAoFbGFiZW'
    'wYAiABKAlSBWxhYmVsEhIKBHRpZXIYAyABKAlSBHRpZXISJgoPbGFzdF90cmFpbmVkX2F0GAQg'
    'ASgDUg1sYXN0VHJhaW5lZEF0EjUKF2RheXNfc2luY2VfbGFzdF90cmFpbmVkGAUgASgFUhRkYX'
    'lzU2luY2VMYXN0VHJhaW5lZBIyChZ0YXJnZXRfc2V0c19wZXJfN19kYXlzGAYgASgFUhJ0YXJn'
    'ZXRTZXRzUGVyN0RheXMSOAoZY29tcGxldGVkX3NldHNfcGVyXzdfZGF5cxgHIAEoBVIVY29tcG'
    'xldGVkU2V0c1BlcjdEYXlzEjgKGXJlbWFpbmluZ19zZXRzX3Blcl83X2RheXMYCCABKAVSFXJl'
    'bWFpbmluZ1NldHNQZXI3RGF5cxI1ChdhcHBlYXJzX2luX25leHRfd29ya291dBgJIAEoCFIUYX'
    'BwZWFyc0luTmV4dFdvcmtvdXQSIQoMc3RhdHVzX2xhYmVsGAogASgJUgtzdGF0dXNMYWJlbA==');

@$core.Deprecated('Use trainingStatusDescriptor instead')
const TrainingStatus$json = {
  '1': 'TrainingStatus',
  '2': [
    {'1': 'next_session_at', '3': 1, '4': 1, '5': 3, '10': 'nextSessionAt'},
    {'1': 'last_session_at', '3': 2, '4': 1, '5': 3, '10': 'lastSessionAt'},
    {'1': 'headline', '3': 3, '4': 1, '5': 9, '10': 'headline'},
    {'1': 'detail', '3': 4, '4': 1, '5': 9, '10': 'detail'},
    {'1': 'should_train_now', '3': 5, '4': 1, '5': 8, '10': 'shouldTrainNow'},
    {
      '1': 'target_sessions_per_7_days',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'targetSessionsPer7Days'
    },
    {
      '1': 'completed_sessions_per_7_days',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'completedSessionsPer7Days'
    },
    {
      '1': 'remaining_sessions_per_7_days',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'remainingSessionsPer7Days'
    },
    {
      '1': 'target_sets_per_7_days',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'targetSetsPer7Days'
    },
    {
      '1': 'completed_sets_per_7_days',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'completedSetsPer7Days'
    },
    {
      '1': 'remaining_sets_per_7_days',
      '3': 11,
      '4': 1,
      '5': 5,
      '10': 'remainingSetsPer7Days'
    },
    {
      '1': 'slot_statuses',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SlotTrainingStatus',
      '10': 'slotStatuses'
    },
  ],
};

/// Descriptor for `TrainingStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingStatusDescriptor = $convert.base64Decode(
    'Cg5UcmFpbmluZ1N0YXR1cxImCg9uZXh0X3Nlc3Npb25fYXQYASABKANSDW5leHRTZXNzaW9uQX'
    'QSJgoPbGFzdF9zZXNzaW9uX2F0GAIgASgDUg1sYXN0U2Vzc2lvbkF0EhoKCGhlYWRsaW5lGAMg'
    'ASgJUghoZWFkbGluZRIWCgZkZXRhaWwYBCABKAlSBmRldGFpbBIoChBzaG91bGRfdHJhaW5fbm'
    '93GAUgASgIUg5zaG91bGRUcmFpbk5vdxI6Chp0YXJnZXRfc2Vzc2lvbnNfcGVyXzdfZGF5cxgG'
    'IAEoBVIWdGFyZ2V0U2Vzc2lvbnNQZXI3RGF5cxJACh1jb21wbGV0ZWRfc2Vzc2lvbnNfcGVyXz'
    'dfZGF5cxgHIAEoBVIZY29tcGxldGVkU2Vzc2lvbnNQZXI3RGF5cxJACh1yZW1haW5pbmdfc2Vz'
    'c2lvbnNfcGVyXzdfZGF5cxgIIAEoBVIZcmVtYWluaW5nU2Vzc2lvbnNQZXI3RGF5cxIyChZ0YX'
    'JnZXRfc2V0c19wZXJfN19kYXlzGAkgASgFUhJ0YXJnZXRTZXRzUGVyN0RheXMSOAoZY29tcGxl'
    'dGVkX3NldHNfcGVyXzdfZGF5cxgKIAEoBVIVY29tcGxldGVkU2V0c1BlcjdEYXlzEjgKGXJlbW'
    'FpbmluZ19zZXRzX3Blcl83X2RheXMYCyABKAVSFXJlbWFpbmluZ1NldHNQZXI3RGF5cxJDCg1z'
    'bG90X3N0YXR1c2VzGAwgAygLMh4ud29ya291dC52MS5TbG90VHJhaW5pbmdTdGF0dXNSDHNsb3'
    'RTdGF0dXNlcw==');

@$core.Deprecated('Use regimeContextDescriptor instead')
const RegimeContext$json = {
  '1': 'RegimeContext',
  '2': [
    {
      '1': 'regime_display_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'regimeDisplayName'
    },
    {
      '1': 'session_description',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'sessionDescription'
    },
    {
      '1': 'next_session_preview',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'nextSessionPreview'
    },
  ],
};

/// Descriptor for `RegimeContext`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regimeContextDescriptor = $convert.base64Decode(
    'Cg1SZWdpbWVDb250ZXh0Ei4KE3JlZ2ltZV9kaXNwbGF5X25hbWUYASABKAlSEXJlZ2ltZURpc3'
    'BsYXlOYW1lEi8KE3Nlc3Npb25fZGVzY3JpcHRpb24YAiABKAlSEnNlc3Npb25EZXNjcmlwdGlv'
    'bhIwChRuZXh0X3Nlc3Npb25fcHJldmlldxgDIAEoCVISbmV4dFNlc3Npb25QcmV2aWV3');

@$core.Deprecated('Use getProposedWorkoutScheduleResponseDescriptor instead')
const GetProposedWorkoutScheduleResponse$json = {
  '1': 'GetProposedWorkoutScheduleResponse',
  '2': [
    {
      '1': 'exercise_statuses',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseStatus',
      '10': 'exerciseStatuses'
    },
    {'1': 'active_workout_id', '3': 2, '4': 1, '5': 9, '10': 'activeWorkoutId'},
    {
      '1': 'proposed_groups',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedExerciseGroup',
      '10': 'proposedGroups'
    },
    {
      '1': 'regime_context',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RegimeContext',
      '10': 'regimeContext'
    },
    {
      '1': 'training_status',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingStatus',
      '10': 'trainingStatus'
    },
    {
      '1': 'suggested_workout_name',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'suggestedWorkoutName'
    },
    {
      '1': 'draft',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutDraft',
      '10': 'draft'
    },
    {
      '1': 'saved_exercise_groups',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'savedExerciseGroups'
    },
    {
      '1': 'user_messages',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `GetProposedWorkoutScheduleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProposedWorkoutScheduleResponseDescriptor = $convert.base64Decode(
    'CiJHZXRQcm9wb3NlZFdvcmtvdXRTY2hlZHVsZVJlc3BvbnNlEkcKEWV4ZXJjaXNlX3N0YXR1c2'
    'VzGAEgAygLMhoud29ya291dC52MS5FeGVyY2lzZVN0YXR1c1IQZXhlcmNpc2VTdGF0dXNlcxIq'
    'ChFhY3RpdmVfd29ya291dF9pZBgCIAEoCVIPYWN0aXZlV29ya291dElkEkoKD3Byb3Bvc2VkX2'
    'dyb3VwcxgDIAMoCzIhLndvcmtvdXQudjEuUHJvcG9zZWRFeGVyY2lzZUdyb3VwUg5wcm9wb3Nl'
    'ZEdyb3VwcxJACg5yZWdpbWVfY29udGV4dBgEIAEoCzIZLndvcmtvdXQudjEuUmVnaW1lQ29udG'
    'V4dFINcmVnaW1lQ29udGV4dBJDCg90cmFpbmluZ19zdGF0dXMYBSABKAsyGi53b3Jrb3V0LnYx'
    'LlRyYWluaW5nU3RhdHVzUg50cmFpbmluZ1N0YXR1cxI0ChZzdWdnZXN0ZWRfd29ya291dF9uYW'
    '1lGAYgASgJUhRzdWdnZXN0ZWRXb3Jrb3V0TmFtZRIuCgVkcmFmdBgHIAEoCzIYLndvcmtvdXQu'
    'djEuV29ya291dERyYWZ0UgVkcmFmdBJNChVzYXZlZF9leGVyY2lzZV9ncm91cHMYCCADKAsyGS'
    '53b3Jrb3V0LnYxLkV4ZXJjaXNlR3JvdXBSE3NhdmVkRXhlcmNpc2VHcm91cHMSPAoNdXNlcl9t'
    'ZXNzYWdlcxgJIAMoCzIXLndvcmtvdXQudjEuVXNlck1lc3NhZ2VSDHVzZXJNZXNzYWdlcw==');

@$core.Deprecated('Use saveProfileExerciseGroupRequestDescriptor instead')
const SaveProfileExerciseGroupRequest$json = {
  '1': 'SaveProfileExerciseGroupRequest',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
  ],
};

/// Descriptor for `SaveProfileExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveProfileExerciseGroupRequestDescriptor =
    $convert.base64Decode(
        'Ch9TYXZlUHJvZmlsZUV4ZXJjaXNlR3JvdXBSZXF1ZXN0Ei8KBWdyb3VwGAEgASgLMhkud29ya2'
        '91dC52MS5FeGVyY2lzZUdyb3VwUgVncm91cA==');

@$core.Deprecated('Use saveProfileExerciseGroupResponseDescriptor instead')
const SaveProfileExerciseGroupResponse$json = {
  '1': 'SaveProfileExerciseGroupResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
  ],
};

/// Descriptor for `SaveProfileExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveProfileExerciseGroupResponseDescriptor =
    $convert.base64Decode(
        'CiBTYXZlUHJvZmlsZUV4ZXJjaXNlR3JvdXBSZXNwb25zZRIvCgVncm91cBgBIAEoCzIZLndvcm'
        'tvdXQudjEuRXhlcmNpc2VHcm91cFIFZ3JvdXA=');

@$core.Deprecated('Use deleteProfileExerciseGroupRequestDescriptor instead')
const DeleteProfileExerciseGroupRequest$json = {
  '1': 'DeleteProfileExerciseGroupRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `DeleteProfileExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteProfileExerciseGroupRequestDescriptor =
    $convert.base64Decode(
        'CiFEZWxldGVQcm9maWxlRXhlcmNpc2VHcm91cFJlcXVlc3QSGQoIZ3JvdXBfaWQYASABKAlSB2'
        'dyb3VwSWQ=');

@$core.Deprecated('Use deleteProfileExerciseGroupResponseDescriptor instead')
const DeleteProfileExerciseGroupResponse$json = {
  '1': 'DeleteProfileExerciseGroupResponse',
};

/// Descriptor for `DeleteProfileExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteProfileExerciseGroupResponseDescriptor =
    $convert.base64Decode('CiJEZWxldGVQcm9maWxlRXhlcmNpc2VHcm91cFJlc3BvbnNl');

@$core.Deprecated('Use workoutDraftDescriptor instead')
const WorkoutDraft$json = {
  '1': 'WorkoutDraft',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'exercise_groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {'1': 'updated_at', '3': 3, '4': 1, '5': 3, '10': 'updatedAt'},
  ],
};

/// Descriptor for `WorkoutDraft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDraftDescriptor = $convert.base64Decode(
    'CgxXb3Jrb3V0RHJhZnQSEgoEbmFtZRgBIAEoCVIEbmFtZRJCCg9leGVyY2lzZV9ncm91cHMYAi'
    'ADKAsyGS53b3Jrb3V0LnYxLkV4ZXJjaXNlR3JvdXBSDmV4ZXJjaXNlR3JvdXBzEh0KCnVwZGF0'
    'ZWRfYXQYAyABKANSCXVwZGF0ZWRBdA==');

@$core.Deprecated('Use saveWorkoutDraftRequestDescriptor instead')
const SaveWorkoutDraftRequest$json = {
  '1': 'SaveWorkoutDraftRequest',
  '2': [
    {
      '1': 'draft',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutDraft',
      '10': 'draft'
    },
  ],
};

/// Descriptor for `SaveWorkoutDraftRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveWorkoutDraftRequestDescriptor =
    $convert.base64Decode(
        'ChdTYXZlV29ya291dERyYWZ0UmVxdWVzdBIuCgVkcmFmdBgBIAEoCzIYLndvcmtvdXQudjEuV2'
        '9ya291dERyYWZ0UgVkcmFmdA==');

@$core.Deprecated('Use saveWorkoutDraftResponseDescriptor instead')
const SaveWorkoutDraftResponse$json = {
  '1': 'SaveWorkoutDraftResponse',
  '2': [
    {
      '1': 'draft',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutDraft',
      '10': 'draft'
    },
  ],
};

/// Descriptor for `SaveWorkoutDraftResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveWorkoutDraftResponseDescriptor =
    $convert.base64Decode(
        'ChhTYXZlV29ya291dERyYWZ0UmVzcG9uc2USLgoFZHJhZnQYASABKAsyGC53b3Jrb3V0LnYxLl'
        'dvcmtvdXREcmFmdFIFZHJhZnQ=');

@$core.Deprecated('Use clearWorkoutDraftRequestDescriptor instead')
const ClearWorkoutDraftRequest$json = {
  '1': 'ClearWorkoutDraftRequest',
};

/// Descriptor for `ClearWorkoutDraftRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearWorkoutDraftRequestDescriptor =
    $convert.base64Decode('ChhDbGVhcldvcmtvdXREcmFmdFJlcXVlc3Q=');

@$core.Deprecated('Use clearWorkoutDraftResponseDescriptor instead')
const ClearWorkoutDraftResponse$json = {
  '1': 'ClearWorkoutDraftResponse',
};

/// Descriptor for `ClearWorkoutDraftResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearWorkoutDraftResponseDescriptor =
    $convert.base64Decode('ChlDbGVhcldvcmtvdXREcmFmdFJlc3BvbnNl');

@$core.Deprecated('Use getActiveWorkoutRequestDescriptor instead')
const GetActiveWorkoutRequest$json = {
  '1': 'GetActiveWorkoutRequest',
};

/// Descriptor for `GetActiveWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveWorkoutRequestDescriptor =
    $convert.base64Decode('ChdHZXRBY3RpdmVXb3Jrb3V0UmVxdWVzdA==');

@$core.Deprecated('Use getActiveWorkoutResponseDescriptor instead')
const GetActiveWorkoutResponse$json = {
  '1': 'GetActiveWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
  ],
};

/// Descriptor for `GetActiveWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveWorkoutResponseDescriptor =
    $convert.base64Decode(
        'ChhHZXRBY3RpdmVXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudj'
        'EuV29ya291dFIHd29ya291dA==');

@$core.Deprecated('Use updateExerciseGroupRequestDescriptor instead')
const UpdateExerciseGroupRequest$json = {
  '1': 'UpdateExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise_group_id', '3': 2, '4': 1, '5': 9, '10': 'exerciseGroupId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `UpdateExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateExerciseGroupRequestDescriptor = $convert.base64Decode(
    'ChpVcGRhdGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
    'V0SWQSKgoRZXhlcmNpc2VfZ3JvdXBfaWQYAiABKAlSD2V4ZXJjaXNlR3JvdXBJZBISCgRuYW1l'
    'GAMgASgJUgRuYW1lEhIKBHNldHMYBCABKAVSBHNldHMSLQoSaW50ZXJsZWF2ZV93YXJtdXBzGA'
    'UgASgIUhFpbnRlcmxlYXZlV2FybXVwcxJJChBleGVyY2lzZV9jb25maWdzGAYgAygLMh4ud29y'
    'a291dC52MS5FeGVyY2lzZVR5cGVDb25maWdSD2V4ZXJjaXNlQ29uZmlncxI3CgtyZXN0X2Nvbm'
    'ZpZxgHIAEoCzIWLndvcmtvdXQudjEuUmVzdENvbmZpZ1IKcmVzdENvbmZpZw==');

@$core.Deprecated('Use updateExerciseGroupResponseDescriptor instead')
const UpdateExerciseGroupResponse$json = {
  '1': 'UpdateExerciseGroupResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
    {
      '1': 'generated_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'generatedSets'
    },
    {
      '1': 'next_up_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `UpdateExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateExerciseGroupResponseDescriptor = $convert.base64Decode(
    'ChtVcGRhdGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USLwoFZ3JvdXAYASABKAsyGS53b3Jrb3V0Ln'
    'YxLkV4ZXJjaXNlR3JvdXBSBWdyb3VwEj4KDmdlbmVyYXRlZF9zZXRzGAIgAygLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFINZ2VuZXJhdGVkU2V0cxI3CgtuZXh0X3VwX3NldBgDIAEoCzIXLn'
    'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgEIAEo'
    'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3QSPAoNdX'
    'Nlcl9tZXNzYWdlcxgFIAMoCzIXLndvcmtvdXQudjEuVXNlck1lc3NhZ2VSDHVzZXJNZXNzYWdl'
    'cw==');

@$core.Deprecated('Use deleteExerciseGroupRequestDescriptor instead')
const DeleteExerciseGroupRequest$json = {
  '1': 'DeleteExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise_group_id', '3': 2, '4': 1, '5': 9, '10': 'exerciseGroupId'},
  ],
};

/// Descriptor for `DeleteExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteExerciseGroupRequestDescriptor =
    $convert.base64Decode(
        'ChpEZWxldGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
        'V0SWQSKgoRZXhlcmNpc2VfZ3JvdXBfaWQYAiABKAlSD2V4ZXJjaXNlR3JvdXBJZA==');

@$core.Deprecated('Use deleteExerciseGroupResponseDescriptor instead')
const DeleteExerciseGroupResponse$json = {
  '1': 'DeleteExerciseGroupResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `DeleteExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteExerciseGroupResponseDescriptor = $convert.base64Decode(
    'ChtEZWxldGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USNwoLbmV4dF91cF9zZXQYASABKAsyFy53b3'
    'Jrb3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdGVfc25hcHNob3QYAiABKAsy'
    'IC53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0ZVNuYXBzaG90EjwKDXVzZX'
    'JfbWVzc2FnZXMYAyADKAsyFy53b3Jrb3V0LnYxLlVzZXJNZXNzYWdlUgx1c2VyTWVzc2FnZXM=');

@$core.Deprecated('Use reorderExerciseGroupsRequestDescriptor instead')
const ReorderExerciseGroupsRequest$json = {
  '1': 'ReorderExerciseGroupsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise_group_ids',
      '3': 2,
      '4': 3,
      '5': 9,
      '10': 'exerciseGroupIds'
    },
  ],
};

/// Descriptor for `ReorderExerciseGroupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExerciseGroupsRequestDescriptor =
    $convert.base64Decode(
        'ChxSZW9yZGVyRXhlcmNpc2VHcm91cHNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcm'
        'tvdXRJZBIsChJleGVyY2lzZV9ncm91cF9pZHMYAiADKAlSEGV4ZXJjaXNlR3JvdXBJZHM=');

@$core.Deprecated('Use reorderExerciseGroupsResponseDescriptor instead')
const ReorderExerciseGroupsResponse$json = {
  '1': 'ReorderExerciseGroupsResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'user_messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
};

/// Descriptor for `ReorderExerciseGroupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExerciseGroupsResponseDescriptor = $convert.base64Decode(
    'Ch1SZW9yZGVyRXhlcmNpc2VHcm91cHNSZXNwb25zZRI3CgtuZXh0X3VwX3NldBgBIAEoCzIXLn'
    'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgCIAEo'
    'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3QSPAoNdX'
    'Nlcl9tZXNzYWdlcxgDIAMoCzIXLndvcmtvdXQudjEuVXNlck1lc3NhZ2VSDHVzZXJNZXNzYWdl'
    'cw==');

@$core.Deprecated('Use workoutHeartRatePointDescriptor instead')
const WorkoutHeartRatePoint$json = {
  '1': 'WorkoutHeartRatePoint',
  '2': [
    {'1': 'sampled_at', '3': 1, '4': 1, '5': 3, '10': 'sampledAt'},
    {'1': 'bpm', '3': 2, '4': 1, '5': 2, '10': 'bpm'},
    {'1': 'availability', '3': 3, '4': 1, '5': 5, '10': 'availability'},
  ],
};

/// Descriptor for `WorkoutHeartRatePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutHeartRatePointDescriptor = $convert.base64Decode(
    'ChVXb3Jrb3V0SGVhcnRSYXRlUG9pbnQSHQoKc2FtcGxlZF9hdBgBIAEoA1IJc2FtcGxlZEF0Eh'
    'AKA2JwbRgCIAEoAlIDYnBtEiIKDGF2YWlsYWJpbGl0eRgDIAEoBVIMYXZhaWxhYmlsaXR5');

@$core.Deprecated('Use appendWorkoutHeartRateRequestDescriptor instead')
const AppendWorkoutHeartRateRequest$json = {
  '1': 'AppendWorkoutHeartRateRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'samples',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutHeartRatePoint',
      '10': 'samples'
    },
  ],
};

/// Descriptor for `AppendWorkoutHeartRateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutHeartRateRequestDescriptor =
    $convert.base64Decode(
        'Ch1BcHBlbmRXb3Jrb3V0SGVhcnRSYXRlUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3'
        'Jrb3V0SWQSOwoHc2FtcGxlcxgCIAMoCzIhLndvcmtvdXQudjEuV29ya291dEhlYXJ0UmF0ZVBv'
        'aW50UgdzYW1wbGVz');

@$core.Deprecated('Use appendWorkoutHeartRateResponseDescriptor instead')
const AppendWorkoutHeartRateResponse$json = {
  '1': 'AppendWorkoutHeartRateResponse',
  '2': [
    {'1': 'stored', '3': 1, '4': 1, '5': 5, '10': 'stored'},
  ],
};

/// Descriptor for `AppendWorkoutHeartRateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutHeartRateResponseDescriptor =
    $convert.base64Decode(
        'Ch5BcHBlbmRXb3Jrb3V0SGVhcnRSYXRlUmVzcG9uc2USFgoGc3RvcmVkGAEgASgFUgZzdG9yZW'
        'Q=');

@$core.Deprecated('Use getWorkoutHeartRateRequestDescriptor instead')
const GetWorkoutHeartRateRequest$json = {
  '1': 'GetWorkoutHeartRateRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `GetWorkoutHeartRateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutHeartRateRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRXb3Jrb3V0SGVhcnRSYXRlUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
        'V0SWQ=');

@$core.Deprecated('Use getWorkoutHeartRateResponseDescriptor instead')
const GetWorkoutHeartRateResponse$json = {
  '1': 'GetWorkoutHeartRateResponse',
  '2': [
    {
      '1': 'samples',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutHeartRatePoint',
      '10': 'samples'
    },
  ],
};

/// Descriptor for `GetWorkoutHeartRateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutHeartRateResponseDescriptor =
    $convert.base64Decode(
        'ChtHZXRXb3Jrb3V0SGVhcnRSYXRlUmVzcG9uc2USOwoHc2FtcGxlcxgBIAMoCzIhLndvcmtvdX'
        'QudjEuV29ya291dEhlYXJ0UmF0ZVBvaW50UgdzYW1wbGVz');

@$core.Deprecated('Use workoutMutationDescriptor instead')
const WorkoutMutation$json = {
  '1': 'WorkoutMutation',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'client_created_at', '3': 2, '4': 1, '5': 3, '10': 'clientCreatedAt'},
    {
      '1': 'start_set',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartSetRequest',
      '9': 0,
      '10': 'startSet'
    },
    {
      '1': 'complete_set',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompleteSetRequest',
      '9': 0,
      '10': 'completeSet'
    },
    {
      '1': 'cancel_proposed_set',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CancelProposedSetRequest',
      '9': 0,
      '10': 'cancelProposedSet'
    },
    {
      '1': 'delete_completed_set',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.DeleteCompletedSetRequest',
      '9': 0,
      '10': 'deleteCompletedSet'
    },
    {
      '1': 'end_workout',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.EndWorkoutRequest',
      '9': 0,
      '10': 'endWorkout'
    },
    {
      '1': 'replace_exercise_group_plan',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ReplaceExerciseGroupPlanRequest',
      '9': 0,
      '10': 'replaceExerciseGroupPlan'
    },
    {
      '1': 'reorder_exercise_groups',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ReorderExerciseGroupsRequest',
      '9': 0,
      '10': 'reorderExerciseGroups'
    },
  ],
  '8': [
    {'1': 'mutation'},
  ],
};

/// Descriptor for `WorkoutMutation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutMutationDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0TXV0YXRpb24SGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQSKgoRY2xpZW50X2'
    'NyZWF0ZWRfYXQYAiABKANSD2NsaWVudENyZWF0ZWRBdBI6CglzdGFydF9zZXQYCiABKAsyGy53'
    'b3Jrb3V0LnYxLlN0YXJ0U2V0UmVxdWVzdEgAUghzdGFydFNldBJDCgxjb21wbGV0ZV9zZXQYCy'
    'ABKAsyHi53b3Jrb3V0LnYxLkNvbXBsZXRlU2V0UmVxdWVzdEgAUgtjb21wbGV0ZVNldBJWChNj'
    'YW5jZWxfcHJvcG9zZWRfc2V0GAwgASgLMiQud29ya291dC52MS5DYW5jZWxQcm9wb3NlZFNldF'
    'JlcXVlc3RIAFIRY2FuY2VsUHJvcG9zZWRTZXQSWQoUZGVsZXRlX2NvbXBsZXRlZF9zZXQYDSAB'
    'KAsyJS53b3Jrb3V0LnYxLkRlbGV0ZUNvbXBsZXRlZFNldFJlcXVlc3RIAFISZGVsZXRlQ29tcG'
    'xldGVkU2V0EkAKC2VuZF93b3Jrb3V0GA4gASgLMh0ud29ya291dC52MS5FbmRXb3Jrb3V0UmVx'
    'dWVzdEgAUgplbmRXb3Jrb3V0EmwKG3JlcGxhY2VfZXhlcmNpc2VfZ3JvdXBfcGxhbhgPIAEoCz'
    'IrLndvcmtvdXQudjEuUmVwbGFjZUV4ZXJjaXNlR3JvdXBQbGFuUmVxdWVzdEgAUhhyZXBsYWNl'
    'RXhlcmNpc2VHcm91cFBsYW4SYgoXcmVvcmRlcl9leGVyY2lzZV9ncm91cHMYECABKAsyKC53b3'
    'Jrb3V0LnYxLlJlb3JkZXJFeGVyY2lzZUdyb3Vwc1JlcXVlc3RIAFIVcmVvcmRlckV4ZXJjaXNl'
    'R3JvdXBzQgoKCG11dGF0aW9u');

@$core.Deprecated('Use appendWorkoutMutationsRequestDescriptor instead')
const AppendWorkoutMutationsRequest$json = {
  '1': 'AppendWorkoutMutationsRequest',
  '2': [
    {
      '1': 'mutations',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutMutation',
      '10': 'mutations'
    },
  ],
};

/// Descriptor for `AppendWorkoutMutationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutMutationsRequestDescriptor =
    $convert.base64Decode(
        'Ch1BcHBlbmRXb3Jrb3V0TXV0YXRpb25zUmVxdWVzdBI5CgltdXRhdGlvbnMYASADKAsyGy53b3'
        'Jrb3V0LnYxLldvcmtvdXRNdXRhdGlvblIJbXV0YXRpb25z');

@$core.Deprecated('Use appendWorkoutMutationsResponseDescriptor instead')
const AppendWorkoutMutationsResponse$json = {
  '1': 'AppendWorkoutMutationsResponse',
  '2': [
    {'1': 'applied_event_ids', '3': 1, '4': 3, '5': 9, '10': 'appliedEventIds'},
    {
      '1': 'workout_state',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetWorkoutResponse',
      '10': 'workoutState'
    },
  ],
};

/// Descriptor for `AppendWorkoutMutationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutMutationsResponseDescriptor =
    $convert.base64Decode(
        'Ch5BcHBlbmRXb3Jrb3V0TXV0YXRpb25zUmVzcG9uc2USKgoRYXBwbGllZF9ldmVudF9pZHMYAS'
        'ADKAlSD2FwcGxpZWRFdmVudElkcxJDCg13b3Jrb3V0X3N0YXRlGAIgASgLMh4ud29ya291dC52'
        'MS5HZXRXb3Jrb3V0UmVzcG9uc2VSDHdvcmtvdXRTdGF0ZQ==');

@$core.Deprecated('Use dismissUserMessagesRequestDescriptor instead')
const DismissUserMessagesRequest$json = {
  '1': 'DismissUserMessagesRequest',
  '2': [
    {'1': 'message_keys', '3': 1, '4': 3, '5': 9, '10': 'messageKeys'},
  ],
};

/// Descriptor for `DismissUserMessagesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissUserMessagesRequestDescriptor =
    $convert.base64Decode(
        'ChpEaXNtaXNzVXNlck1lc3NhZ2VzUmVxdWVzdBIhCgxtZXNzYWdlX2tleXMYASADKAlSC21lc3'
        'NhZ2VLZXlz');

@$core.Deprecated('Use dismissUserMessagesResponseDescriptor instead')
const DismissUserMessagesResponse$json = {
  '1': 'DismissUserMessagesResponse',
  '2': [
    {
      '1': 'dismissed_message_keys',
      '3': 1,
      '4': 3,
      '5': 9,
      '10': 'dismissedMessageKeys'
    },
  ],
};

/// Descriptor for `DismissUserMessagesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissUserMessagesResponseDescriptor =
    $convert.base64Decode(
        'ChtEaXNtaXNzVXNlck1lc3NhZ2VzUmVzcG9uc2USNAoWZGlzbWlzc2VkX21lc3NhZ2Vfa2V5cx'
        'gBIAMoCVIUZGlzbWlzc2VkTWVzc2FnZUtleXM=');

@$core.Deprecated('Use rehydrateWorkoutFromEventsRequestDescriptor instead')
const RehydrateWorkoutFromEventsRequest$json = {
  '1': 'RehydrateWorkoutFromEventsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'persist', '3': 2, '4': 1, '5': 8, '10': 'persist'},
  ],
};

/// Descriptor for `RehydrateWorkoutFromEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rehydrateWorkoutFromEventsRequestDescriptor =
    $convert.base64Decode(
        'CiFSZWh5ZHJhdGVXb3Jrb3V0RnJvbUV2ZW50c1JlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCV'
        'IJd29ya291dElkEhgKB3BlcnNpc3QYAiABKAhSB3BlcnNpc3Q=');

@$core.Deprecated('Use rehydrateWorkoutFromEventsResponseDescriptor instead')
const RehydrateWorkoutFromEventsResponse$json = {
  '1': 'RehydrateWorkoutFromEventsResponse',
  '2': [
    {
      '1': 'workout_state',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetWorkoutResponse',
      '10': 'workoutState'
    },
    {
      '1': 'applied_event_count',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'appliedEventCount'
    },
  ],
};

/// Descriptor for `RehydrateWorkoutFromEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rehydrateWorkoutFromEventsResponseDescriptor =
    $convert.base64Decode(
        'CiJSZWh5ZHJhdGVXb3Jrb3V0RnJvbUV2ZW50c1Jlc3BvbnNlEkMKDXdvcmtvdXRfc3RhdGUYAS'
        'ABKAsyHi53b3Jrb3V0LnYxLkdldFdvcmtvdXRSZXNwb25zZVIMd29ya291dFN0YXRlEi4KE2Fw'
        'cGxpZWRfZXZlbnRfY291bnQYAiABKAVSEWFwcGxpZWRFdmVudENvdW50');

@$core.Deprecated('Use createUserRequestDescriptor instead')
const CreateUserRequest$json = {
  '1': 'CreateUserRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserRequestDescriptor = $convert
    .base64Decode('ChFDcmVhdGVVc2VyUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1l');

@$core.Deprecated('Use createUserResponseDescriptor instead')
const CreateUserResponse$json = {
  '1': 'CreateUserResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
  ],
};

/// Descriptor for `CreateUserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserResponseDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVVc2VyUmVzcG9uc2USJAoEdXNlchgBIAEoCzIQLndvcmtvdXQudjEuVXNlclIEdX'
    'Nlcg==');

@$core.Deprecated('Use getUserRequestDescriptor instead')
const GetUserRequest$json = {
  '1': 'GetUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `GetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserRequestDescriptor = $convert
    .base64Decode('Cg5HZXRVc2VyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use getUserResponseDescriptor instead')
const GetUserResponse$json = {
  '1': 'GetUserResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
  ],
};

/// Descriptor for `GetUserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRVc2VyUmVzcG9uc2USJAoEdXNlchgBIAEoCzIQLndvcmtvdXQudjEuVXNlclIEdXNlcg'
    '==');

@$core.Deprecated('Use updateMyProfileRequestDescriptor instead')
const UpdateMyProfileRequest$json = {
  '1': 'UpdateMyProfileRequest',
  '2': [
    {'1': 'profile_emoji', '3': 1, '4': 1, '5': 9, '10': 'profileEmoji'},
    {'1': 'profile_color_hex', '3': 2, '4': 1, '5': 9, '10': 'profileColorHex'},
    {'1': 'body_weight_kg', '3': 3, '4': 1, '5': 2, '10': 'bodyWeightKg'},
  ],
};

/// Descriptor for `UpdateMyProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateMyProfileRequestDescriptor = $convert.base64Decode(
    'ChZVcGRhdGVNeVByb2ZpbGVSZXF1ZXN0EiMKDXByb2ZpbGVfZW1vamkYASABKAlSDHByb2ZpbG'
    'VFbW9qaRIqChFwcm9maWxlX2NvbG9yX2hleBgCIAEoCVIPcHJvZmlsZUNvbG9ySGV4EiQKDmJv'
    'ZHlfd2VpZ2h0X2tnGAMgASgCUgxib2R5V2VpZ2h0S2c=');

@$core.Deprecated('Use updateMyProfileResponseDescriptor instead')
const UpdateMyProfileResponse$json = {
  '1': 'UpdateMyProfileResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
  ],
};

/// Descriptor for `UpdateMyProfileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateMyProfileResponseDescriptor =
    $convert.base64Decode(
        'ChdVcGRhdGVNeVByb2ZpbGVSZXNwb25zZRIkCgR1c2VyGAEgASgLMhAud29ya291dC52MS5Vc2'
        'VyUgR1c2Vy');
