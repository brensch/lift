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
    {'1': 'MUSCLE_GROUP_CALVES', '2': 9},
    {'1': 'MUSCLE_GROUP_CORE', '2': 10},
  ],
};

/// Descriptor for `MuscleGroup`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List muscleGroupDescriptor = $convert.base64Decode(
    'CgtNdXNjbGVHcm91cBIcChhNVVNDTEVfR1JPVVBfVU5TUEVDSUZJRUQQABIWChJNVVNDTEVfR1'
    'JPVVBfUVVBRFMQARIbChdNVVNDTEVfR1JPVVBfSEFNU1RSSU5HUxACEhcKE01VU0NMRV9HUk9V'
    'UF9HTFVURVMQAxIWChJNVVNDTEVfR1JPVVBfQ0hFU1QQBBIVChFNVVNDTEVfR1JPVVBfQkFDSx'
    'AFEhoKFk1VU0NMRV9HUk9VUF9TSE9VTERFUlMQBhIXChNNVVNDTEVfR1JPVVBfQklDRVBTEAcS'
    'GAoUTVVTQ0xFX0dST1VQX1RSSUNFUFMQCBIXChNNVVNDTEVfR1JPVVBfQ0FMVkVTEAkSFQoRTV'
    'VTQ0xFX0dST1VQX0NPUkUQCg==');

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

@$core.Deprecated('Use equipmentKindDescriptor instead')
const EquipmentKind$json = {
  '1': 'EquipmentKind',
  '2': [
    {'1': 'EQUIPMENT_KIND_UNSPECIFIED', '2': 0},
    {'1': 'EQUIPMENT_KIND_BARBELL', '2': 1},
    {'1': 'EQUIPMENT_KIND_DUMBBELL', '2': 2},
    {'1': 'EQUIPMENT_KIND_MACHINE', '2': 3},
    {'1': 'EQUIPMENT_KIND_CABLE', '2': 4},
    {'1': 'EQUIPMENT_KIND_BODYWEIGHT', '2': 5},
  ],
};

/// Descriptor for `EquipmentKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List equipmentKindDescriptor = $convert.base64Decode(
    'Cg1FcXVpcG1lbnRLaW5kEh4KGkVRVUlQTUVOVF9LSU5EX1VOU1BFQ0lGSUVEEAASGgoWRVFVSV'
    'BNRU5UX0tJTkRfQkFSQkVMTBABEhsKF0VRVUlQTUVOVF9LSU5EX0RVTUJCRUxMEAISGgoWRVFV'
    'SVBNRU5UX0tJTkRfTUFDSElORRADEhgKFEVRVUlQTUVOVF9LSU5EX0NBQkxFEAQSHQoZRVFVSV'
    'BNRU5UX0tJTkRfQk9EWVdFSUdIVBAF');

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

@$core.Deprecated('Use planReasonKindDescriptor instead')
const PlanReasonKind$json = {
  '1': 'PlanReasonKind',
  '2': [
    {'1': 'PLAN_REASON_KIND_UNSPECIFIED', '2': 0},
    {'1': 'PLAN_REASON_KIND_MAX_UP', '2': 1},
    {'1': 'PLAN_REASON_KIND_MAX_FROM_MISS', '2': 2},
    {'1': 'PLAN_REASON_KIND_HELD', '2': 3},
    {'1': 'PLAN_REASON_KIND_TIME_OFF', '2': 4},
    {'1': 'PLAN_REASON_KIND_FIRST_TIME', '2': 5},
    {'1': 'PLAN_REASON_KIND_USER_SET', '2': 6},
    {'1': 'PLAN_REASON_KIND_SETS_FROM_TIME', '2': 7},
    {'1': 'PLAN_REASON_KIND_WEIGHT_UP', '2': 8},
    {'1': 'PLAN_REASON_KIND_WEIGHT_DOWN', '2': 9},
    {'1': 'PLAN_REASON_KIND_REPS_UP', '2': 10},
    {'1': 'PLAN_REASON_KIND_REPS_DOWN', '2': 11},
    {'1': 'PLAN_REASON_KIND_SAME_AS_LAST', '2': 12},
  ],
};

/// Descriptor for `PlanReasonKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List planReasonKindDescriptor = $convert.base64Decode(
    'Cg5QbGFuUmVhc29uS2luZBIgChxQTEFOX1JFQVNPTl9LSU5EX1VOU1BFQ0lGSUVEEAASGwoXUE'
    'xBTl9SRUFTT05fS0lORF9NQVhfVVAQARIiCh5QTEFOX1JFQVNPTl9LSU5EX01BWF9GUk9NX01J'
    'U1MQAhIZChVQTEFOX1JFQVNPTl9LSU5EX0hFTEQQAxIdChlQTEFOX1JFQVNPTl9LSU5EX1RJTU'
    'VfT0ZGEAQSHwobUExBTl9SRUFTT05fS0lORF9GSVJTVF9USU1FEAUSHQoZUExBTl9SRUFTT05f'
    'S0lORF9VU0VSX1NFVBAGEiMKH1BMQU5fUkVBU09OX0tJTkRfU0VUU19GUk9NX1RJTUUQBxIeCh'
    'pQTEFOX1JFQVNPTl9LSU5EX1dFSUdIVF9VUBAIEiAKHFBMQU5fUkVBU09OX0tJTkRfV0VJR0hU'
    'X0RPV04QCRIcChhQTEFOX1JFQVNPTl9LSU5EX1JFUFNfVVAQChIeChpQTEFOX1JFQVNPTl9LSU'
    '5EX1JFUFNfRE9XThALEiEKHVBMQU5fUkVBU09OX0tJTkRfU0FNRV9BU19MQVNUEAw=');

@$core.Deprecated('Use planChangeCauseDescriptor instead')
const PlanChangeCause$json = {
  '1': 'PlanChangeCause',
  '2': [
    {'1': 'PLAN_CHANGE_CAUSE_UNSPECIFIED', '2': 0},
    {'1': 'PLAN_CHANGE_CAUSE_HIT', '2': 1},
    {'1': 'PLAN_CHANGE_CAUSE_MISSED', '2': 2},
    {'1': 'PLAN_CHANGE_CAUSE_STOPPED_EARLY', '2': 3},
    {'1': 'PLAN_CHANGE_CAUSE_SETS', '2': 4},
    {'1': 'PLAN_CHANGE_CAUSE_TIME_OFF', '2': 5},
    {'1': 'PLAN_CHANGE_CAUSE_RUSHED', '2': 6},
  ],
};

/// Descriptor for `PlanChangeCause`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List planChangeCauseDescriptor = $convert.base64Decode(
    'Cg9QbGFuQ2hhbmdlQ2F1c2USIQodUExBTl9DSEFOR0VfQ0FVU0VfVU5TUEVDSUZJRUQQABIZCh'
    'VQTEFOX0NIQU5HRV9DQVVTRV9ISVQQARIcChhQTEFOX0NIQU5HRV9DQVVTRV9NSVNTRUQQAhIj'
    'Ch9QTEFOX0NIQU5HRV9DQVVTRV9TVE9QUEVEX0VBUkxZEAMSGgoWUExBTl9DSEFOR0VfQ0FVU0'
    'VfU0VUUxAEEh4KGlBMQU5fQ0hBTkdFX0NBVVNFX1RJTUVfT0ZGEAUSHAoYUExBTl9DSEFOR0Vf'
    'Q0FVU0VfUlVTSEVEEAY=');

@$core.Deprecated('Use weightChangeCauseDescriptor instead')
const WeightChangeCause$json = {
  '1': 'WeightChangeCause',
  '2': [
    {'1': 'WEIGHT_CHANGE_CAUSE_UNSPECIFIED', '2': 0},
    {'1': 'WEIGHT_CHANGE_CAUSE_USER_ADJUST', '2': 1},
    {'1': 'WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP', '2': 2},
    {'1': 'WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED', '2': 3},
    {'1': 'WEIGHT_CHANGE_CAUSE_CORRECTION', '2': 4},
  ],
};

/// Descriptor for `WeightChangeCause`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List weightChangeCauseDescriptor = $convert.base64Decode(
    'ChFXZWlnaHRDaGFuZ2VDYXVzZRIjCh9XRUlHSFRfQ0hBTkdFX0NBVVNFX1VOU1BFQ0lGSUVEEA'
    'ASIwofV0VJR0hUX0NIQU5HRV9DQVVTRV9VU0VSX0FESlVTVBABEigKJFdFSUdIVF9DSEFOR0Vf'
    'Q0FVU0VfQ0FMSUJSQVRJT05fU1RFUBACEisKJ1dFSUdIVF9DSEFOR0VfQ0FVU0VfQ0FMSUJSQV'
    'RJT05fU0VUVExFRBADEiIKHldFSUdIVF9DSEFOR0VfQ0FVU0VfQ09SUkVDVElPThAE');

@$core.Deprecated('Use workoutStateDescriptor instead')
const WorkoutState$json = {
  '1': 'WorkoutState',
  '2': [
    {'1': 'WORKOUT_STATE_UNSPECIFIED', '2': 0},
    {'1': 'WORKOUT_STATE_ALL_DONE', '2': 1},
    {'1': 'WORKOUT_STATE_RESTING', '2': 3},
    {'1': 'WORKOUT_STATE_READY', '2': 5},
    {'1': 'WORKOUT_STATE_YAPPING', '2': 6},
    {'1': 'WORKOUT_STATE_LIFTING', '2': 7},
  ],
  '4': [
    {'1': 2, '2': 2},
  ],
};

/// Descriptor for `WorkoutState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List workoutStateDescriptor = $convert.base64Decode(
    'CgxXb3Jrb3V0U3RhdGUSHQoZV09SS09VVF9TVEFURV9VTlNQRUNJRklFRBAAEhoKFldPUktPVV'
    'RfU1RBVEVfQUxMX0RPTkUQARIZChVXT1JLT1VUX1NUQVRFX1JFU1RJTkcQAxIXChNXT1JLT1VU'
    'X1NUQVRFX1JFQURZEAUSGQoVV09SS09VVF9TVEFURV9ZQVBQSU5HEAYSGQoVV09SS09VVF9TVE'
    'FURV9MSUZUSU5HEAciBAgCEAI=');

@$core.Deprecated('Use rotationWarningKindDescriptor instead')
const RotationWarningKind$json = {
  '1': 'RotationWarningKind',
  '2': [
    {'1': 'ROTATION_WARNING_KIND_UNSPECIFIED', '2': 0},
    {'1': 'ROTATION_WARNING_KIND_GAP', '2': 1},
    {'1': 'ROTATION_WARNING_KIND_OVERLAP', '2': 2},
    {'1': 'ROTATION_WARNING_KIND_TOO_FEW', '2': 4},
  ],
  '4': [
    {'1': 3, '2': 3},
  ],
  '5': ['ROTATION_WARNING_KIND_LOPSIDED'],
};

/// Descriptor for `RotationWarningKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rotationWarningKindDescriptor = $convert.base64Decode(
    'ChNSb3RhdGlvbldhcm5pbmdLaW5kEiUKIVJPVEFUSU9OX1dBUk5JTkdfS0lORF9VTlNQRUNJRk'
    'lFRBAAEh0KGVJPVEFUSU9OX1dBUk5JTkdfS0lORF9HQVAQARIhCh1ST1RBVElPTl9XQVJOSU5H'
    'X0tJTkRfT1ZFUkxBUBACEiEKHVJPVEFUSU9OX1dBUk5JTkdfS0lORF9UT09fRkVXEAQiBAgDEA'
    'MqHlJPVEFUSU9OX1dBUk5JTkdfS0lORF9MT1BTSURFRA==');

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
    {'1': 'template_id', '3': 6, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'lifting_set_id', '3': 7, '4': 1, '5': 9, '10': 'liftingSetId'},
    {
      '1': 'lifting_started_at',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'liftingStartedAt'
    },
  ],
};

/// Descriptor for `Workout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDescriptor = $convert.base64Decode(
    'CgdXb3Jrb3V0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YXJ0X3'
    'RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZRIdCgpzZXNz'
    'aW9uX2lkGAUgASgJUglzZXNzaW9uSWQSHwoLdGVtcGxhdGVfaWQYBiABKAlSCnRlbXBsYXRlSW'
    'QSJAoObGlmdGluZ19zZXRfaWQYByABKAlSDGxpZnRpbmdTZXRJZBIsChJsaWZ0aW5nX3N0YXJ0'
    'ZWRfYXQYCCABKANSEGxpZnRpbmdTdGFydGVkQXQ=');

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
    {'1': 'rest_seconds', '3': 9, '4': 1, '5': 5, '10': 'restSeconds'},
    {'1': 'cancelled', '3': 11, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'calibration', '3': 15, '4': 1, '5': 8, '10': 'calibration'},
    {'1': 'skipped', '3': 16, '4': 1, '5': 8, '10': 'skipped'},
  ],
  '9': [
    {'1': 8, '2': 9},
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 13, '2': 14},
    {'1': 14, '2': 15},
  ],
  '10': [
    'exercise_group_id',
    'is_amrap',
    'instruction',
    'progression_hint',
    'rest_after_success',
    'rest_after_failure'
  ],
};

/// Descriptor for `ProposedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedSetDescriptor = $convert.base64Decode(
    'CgtQcm9wb3NlZFNldBIOCgJpZBgBIAEoCVICaWQSHQoKd29ya291dF9pZBgCIAEoCVIJd29ya2'
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIwCghleGVyY2lzZRgE'
    'IAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEh8KC3RhcmdldF9yZXBzGAUgAS'
    'gFUgp0YXJnZXRSZXBzEiMKDXRhcmdldF93ZWlnaHQYBiABKAJSDHRhcmdldFdlaWdodBIWCgZ3'
    'YXJtdXAYByABKAhSBndhcm11cBIhCgxyZXN0X3NlY29uZHMYCSABKAVSC3Jlc3RTZWNvbmRzEh'
    'wKCWNhbmNlbGxlZBgLIAEoCFIJY2FuY2VsbGVkEiAKC2NhbGlicmF0aW9uGA8gASgIUgtjYWxp'
    'YnJhdGlvbhIYCgdza2lwcGVkGBAgASgIUgdza2lwcGVkSgQICBAJSgQIChALSgQIDBANSgQIDR'
    'AOSgQIDhAPUhFleGVyY2lzZV9ncm91cF9pZFIIaXNfYW1yYXBSC2luc3RydWN0aW9uUhBwcm9n'
    'cmVzc2lvbl9oaW50UhJyZXN0X2FmdGVyX3N1Y2Nlc3NSEnJlc3RfYWZ0ZXJfZmFpbHVyZQ==');

@$core.Deprecated('Use completedSetDescriptor instead')
const CompletedSet$json = {
  '1': 'CompletedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 3, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 4, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 5, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'ended_at', '3': 7, '4': 1, '5': 3, '10': 'endedAt'},
    {'1': 'rest_until', '3': 8, '4': 1, '5': 3, '10': 'restUntil'},
    {'1': 'started_at', '3': 11, '4': 1, '5': 3, '10': 'startedAt'},
  ],
  '9': [
    {'1': 6, '2': 7},
    {'1': 9, '2': 10},
    {'1': 10, '2': 11},
  ],
  '10': ['rest_skipped', 'effort'],
};

/// Descriptor for `CompletedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completedSetDescriptor = $convert.base64Decode(
    'CgxDb21wbGV0ZWRTZXQSDgoCaWQYASABKAlSAmlkEh0KCndvcmtvdXRfaWQYAiABKAlSCXdvcm'
    'tvdXRJZBImCg9wcm9wb3NlZF9zZXRfaWQYAyABKAlSDXByb3Bvc2VkU2V0SWQSHwoLYWN0dWFs'
    'X3JlcHMYBCABKAVSCmFjdHVhbFJlcHMSIwoNYWN0dWFsX3dlaWdodBgFIAEoAlIMYWN0dWFsV2'
    'VpZ2h0EhkKCGVuZGVkX2F0GAcgASgDUgdlbmRlZEF0Eh0KCnJlc3RfdW50aWwYCCABKANSCXJl'
    'c3RVbnRpbBIdCgpzdGFydGVkX2F0GAsgASgDUglzdGFydGVkQXRKBAgGEAdKBAgJEApKBAgKEA'
    'tSDHJlc3Rfc2tpcHBlZFIGZWZmb3J0');

@$core.Deprecated('Use planReasonDescriptor instead')
const PlanReason$json = {
  '1': 'PlanReason',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.PlanReasonKind',
      '10': 'kind'
    },
    {'1': 'before', '3': 2, '4': 1, '5': 2, '10': 'before'},
    {'1': 'after', '3': 3, '4': 1, '5': 2, '10': 'after'},
    {'1': 'days_off', '3': 4, '4': 1, '5': 5, '10': 'daysOff'},
    {'1': 'workout_id', '3': 5, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 6, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'at', '3': 7, '4': 1, '5': 3, '10': 'at'},
    {'1': 'budget_minutes', '3': 8, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {
      '1': 'muscle',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscle'
    },
    {'1': 'weekly_sets', '3': 10, '4': 1, '5': 2, '10': 'weeklySets'},
    {
      '1': 'cause',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.PlanChangeCause',
      '10': 'cause'
    },
    {'1': 'reps_before', '3': 12, '4': 1, '5': 5, '10': 'repsBefore'},
    {'1': 'reps_after', '3': 13, '4': 1, '5': 5, '10': 'repsAfter'},
    {'1': 'sets_before', '3': 14, '4': 1, '5': 5, '10': 'setsBefore'},
    {'1': 'sets_after', '3': 15, '4': 1, '5': 5, '10': 'setsAfter'},
  ],
};

/// Descriptor for `PlanReason`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planReasonDescriptor = $convert.base64Decode(
    'CgpQbGFuUmVhc29uEi4KBGtpbmQYASABKA4yGi53b3Jrb3V0LnYxLlBsYW5SZWFzb25LaW5kUg'
    'RraW5kEhYKBmJlZm9yZRgCIAEoAlIGYmVmb3JlEhQKBWFmdGVyGAMgASgCUgVhZnRlchIZCghk'
    'YXlzX29mZhgEIAEoBVIHZGF5c09mZhIdCgp3b3Jrb3V0X2lkGAUgASgJUgl3b3Jrb3V0SWQSFQ'
    'oGc2V0X2lkGAYgASgJUgVzZXRJZBIOCgJhdBgHIAEoA1ICYXQSJQoOYnVkZ2V0X21pbnV0ZXMY'
    'CCABKAVSDWJ1ZGdldE1pbnV0ZXMSLwoGbXVzY2xlGAkgASgOMhcud29ya291dC52MS5NdXNjbG'
    'VHcm91cFIGbXVzY2xlEh8KC3dlZWtseV9zZXRzGAogASgCUgp3ZWVrbHlTZXRzEjEKBWNhdXNl'
    'GAsgASgOMhsud29ya291dC52MS5QbGFuQ2hhbmdlQ2F1c2VSBWNhdXNlEh8KC3JlcHNfYmVmb3'
    'JlGAwgASgFUgpyZXBzQmVmb3JlEh0KCnJlcHNfYWZ0ZXIYDSABKAVSCXJlcHNBZnRlchIfCgtz'
    'ZXRzX2JlZm9yZRgOIAEoBVIKc2V0c0JlZm9yZRIdCgpzZXRzX2FmdGVyGA8gASgFUglzZXRzQW'
    'Z0ZXI=');

@$core.Deprecated('Use exerciseDecisionDescriptor instead')
const ExerciseDecision$json = {
  '1': 'ExerciseDecision',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'sets', '3': 2, '4': 1, '5': 5, '10': 'sets'},
    {'1': 'reps', '3': 3, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'weight', '3': 4, '4': 1, '5': 2, '10': 'weight'},
    {'1': 'rest_seconds', '3': 5, '4': 1, '5': 5, '10': 'restSeconds'},
    {'1': 'warmups', '3': 6, '4': 1, '5': 8, '10': 'warmups'},
    {'1': 'rep_low', '3': 7, '4': 1, '5': 5, '10': 'repLow'},
    {'1': 'rep_high', '3': 8, '4': 1, '5': 5, '10': 'repHigh'},
    {'1': 'max', '3': 9, '4': 1, '5': 2, '10': 'max'},
    {'1': 'calibration', '3': 10, '4': 1, '5': 8, '10': 'calibration'},
    {'1': 'budget_minutes', '3': 11, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {
      '1': 'estimated_seconds',
      '3': 12,
      '4': 1,
      '5': 5,
      '10': 'estimatedSeconds'
    },
    {
      '1': 'reasons',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PlanReason',
      '10': 'reasons'
    },
  ],
};

/// Descriptor for `ExerciseDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseDecisionDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZURlY2lzaW9uEjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC52MS5FeGVyY2'
    'lzZVIIZXhlcmNpc2USEgoEc2V0cxgCIAEoBVIEc2V0cxISCgRyZXBzGAMgASgFUgRyZXBzEhYK'
    'BndlaWdodBgEIAEoAlIGd2VpZ2h0EiEKDHJlc3Rfc2Vjb25kcxgFIAEoBVILcmVzdFNlY29uZH'
    'MSGAoHd2FybXVwcxgGIAEoCFIHd2FybXVwcxIXCgdyZXBfbG93GAcgASgFUgZyZXBMb3cSGQoI'
    'cmVwX2hpZ2gYCCABKAVSB3JlcEhpZ2gSEAoDbWF4GAkgASgCUgNtYXgSIAoLY2FsaWJyYXRpb2'
    '4YCiABKAhSC2NhbGlicmF0aW9uEiUKDmJ1ZGdldF9taW51dGVzGAsgASgFUg1idWRnZXRNaW51'
    'dGVzEisKEWVzdGltYXRlZF9zZWNvbmRzGAwgASgFUhBlc3RpbWF0ZWRTZWNvbmRzEjAKB3JlYX'
    'NvbnMYDSADKAsyFi53b3Jrb3V0LnYxLlBsYW5SZWFzb25SB3JlYXNvbnM=');

@$core.Deprecated('Use weightChangeDescriptor instead')
const WeightChange$json = {
  '1': 'WeightChange',
  '2': [
    {'1': 'at', '3': 1, '4': 1, '5': 3, '10': 'at'},
    {'1': 'from_set_id', '3': 2, '4': 1, '5': 9, '10': 'fromSetId'},
    {'1': 'before', '3': 3, '4': 1, '5': 2, '10': 'before'},
    {'1': 'after', '3': 4, '4': 1, '5': 2, '10': 'after'},
    {
      '1': 'cause',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WeightChangeCause',
      '10': 'cause'
    },
  ],
};

/// Descriptor for `WeightChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List weightChangeDescriptor = $convert.base64Decode(
    'CgxXZWlnaHRDaGFuZ2USDgoCYXQYASABKANSAmF0Eh4KC2Zyb21fc2V0X2lkGAIgASgJUglmcm'
    '9tU2V0SWQSFgoGYmVmb3JlGAMgASgCUgZiZWZvcmUSFAoFYWZ0ZXIYBCABKAJSBWFmdGVyEjMK'
    'BWNhdXNlGAUgASgOMh0ud29ya291dC52MS5XZWlnaHRDaGFuZ2VDYXVzZVIFY2F1c2U=');

@$core.Deprecated('Use exerciseLogDescriptor instead')
const ExerciseLog$json = {
  '1': 'ExerciseLog',
  '2': [
    {
      '1': 'decision',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'decision'
    },
    {
      '1': 'changes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WeightChange',
      '10': 'changes'
    },
  ],
};

/// Descriptor for `ExerciseLog`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseLogDescriptor = $convert.base64Decode(
    'CgtFeGVyY2lzZUxvZxI4CghkZWNpc2lvbhgBIAEoCzIcLndvcmtvdXQudjEuRXhlcmNpc2VEZW'
    'Npc2lvblIIZGVjaXNpb24SMgoHY2hhbmdlcxgCIAMoCzIYLndvcmtvdXQudjEuV2VpZ2h0Q2hh'
    'bmdlUgdjaGFuZ2Vz');

@$core.Deprecated('Use exercisePlanDescriptor instead')
const ExercisePlan$json = {
  '1': 'ExercisePlan',
  '2': [
    {
      '1': 'decision',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'decision'
    },
    {'1': 'overridden', '3': 2, '4': 1, '5': 8, '10': 'overridden'},
    {
      '1': 'primary_muscle',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'primaryMuscle'
    },
    {
      '1': 'equipment',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.EquipmentKind',
      '10': 'equipment'
    },
    {'1': 'last_performed_at', '3': 5, '4': 1, '5': 3, '10': 'lastPerformedAt'},
  ],
};

/// Descriptor for `ExercisePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exercisePlanDescriptor = $convert.base64Decode(
    'CgxFeGVyY2lzZVBsYW4SOAoIZGVjaXNpb24YASABKAsyHC53b3Jrb3V0LnYxLkV4ZXJjaXNlRG'
    'VjaXNpb25SCGRlY2lzaW9uEh4KCm92ZXJyaWRkZW4YAiABKAhSCm92ZXJyaWRkZW4SPgoOcHJp'
    'bWFyeV9tdXNjbGUYAyABKA4yFy53b3Jrb3V0LnYxLk11c2NsZUdyb3VwUg1wcmltYXJ5TXVzY2'
    'xlEjcKCWVxdWlwbWVudBgEIAEoDjIZLndvcmtvdXQudjEuRXF1aXBtZW50S2luZFIJZXF1aXBt'
    'ZW50EioKEWxhc3RfcGVyZm9ybWVkX2F0GAUgASgDUg9sYXN0UGVyZm9ybWVkQXQ=');

@$core.Deprecated('Use startWorkoutRequestDescriptor instead')
const StartWorkoutRequest$json = {
  '1': 'StartWorkoutRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'template_id', '3': 4, '4': 1, '5': 9, '10': 'templateId'},
    {
      '1': 'exercises',
      '3': 5,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
    {'1': 'budget_minutes', '3': 7, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {
      '1': 'decisions',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'decisions'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['exercise_groups'],
};

/// Descriptor for `StartWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFdvcmtvdXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSHQoKc3RhcnRlZF9hdB'
    'gDIAEoA1IJc3RhcnRlZEF0Eh8KC3RlbXBsYXRlX2lkGAQgASgJUgp0ZW1wbGF0ZUlkEjIKCWV4'
    'ZXJjaXNlcxgFIAMoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCWV4ZXJjaXNlcxIlCg5idWRnZX'
    'RfbWludXRlcxgHIAEoBVINYnVkZ2V0TWludXRlcxI6CglkZWNpc2lvbnMYBiADKAsyHC53b3Jr'
    'b3V0LnYxLkV4ZXJjaXNlRGVjaXNpb25SCWRlY2lzaW9uc0oECAIQA1IPZXhlcmNpc2VfZ3JvdX'
    'Bz');

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
      '1': 'exercise_logs',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseLog',
      '10': 'exerciseLogs'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
    {'1': 8, '2': 9},
  ],
  '10': ['exercise_groups', 'user_messages'],
};

/// Descriptor for `StartWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutResponseDescriptor = $convert.base64Decode(
    'ChRTdGFydFdvcmtvdXRSZXNwb25zZRIOCgJpZBgBIAEoCVICaWQSLQoHd29ya291dBgCIAEoCz'
    'ITLndvcmtvdXQudjEuV29ya291dFIHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAQgAygLMhcu'
    'd29ya291dC52MS5Qcm9wb3NlZFNldFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGA'
    'UgAygLMhgud29ya291dC52MS5Db21wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSNwoLbmV4dF91'
    'cF9zZXQYBiABKAsyFy53b3Jrb3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdG'
    'Vfc25hcHNob3QYByABKAsyIC53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0'
    'ZVNuYXBzaG90EjwKDWV4ZXJjaXNlX2xvZ3MYCSADKAsyFy53b3Jrb3V0LnYxLkV4ZXJjaXNlTG'
    '9nUgxleGVyY2lzZUxvZ3NKBAgDEARKBAgIEAlSD2V4ZXJjaXNlX2dyb3Vwc1INdXNlcl9tZXNz'
    'YWdlcw==');

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
    {
      '1': 'heaviest_set_weight',
      '3': 6,
      '4': 1,
      '5': 2,
      '10': 'heaviestSetWeight'
    },
  ],
  '9': [
    {'1': 5, '2': 6},
  ],
  '10': ['best_one_rep_max'],
};

/// Descriptor for `ExerciseSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseSummaryDescriptor = $convert.base64Decode(
    'Cg9FeGVyY2lzZVN1bW1hcnkSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaX'
    'NlUghleGVyY2lzZRIdCgp0b3RhbF9zZXRzGAIgASgFUgl0b3RhbFNldHMSHQoKdG90YWxfcmVw'
    'cxgDIAEoBVIJdG90YWxSZXBzEiEKDHRvdGFsX3ZvbHVtZRgEIAEoAlILdG90YWxWb2x1bWUSLg'
    'oTaGVhdmllc3Rfc2V0X3dlaWdodBgGIAEoAlIRaGVhdmllc3RTZXRXZWlnaHRKBAgFEAZSEGJl'
    'c3Rfb25lX3JlcF9tYXg=');

@$core.Deprecated('Use workoutSummaryDescriptor instead')
const WorkoutSummary$json = {
  '1': 'WorkoutSummary',
  '2': [
    {'1': 'total_volume', '3': 1, '4': 1, '5': 2, '10': 'totalVolume'},
    {'1': 'duration_seconds', '3': 2, '4': 1, '5': 3, '10': 'durationSeconds'},
    {'1': 'resting_seconds', '3': 4, '4': 1, '5': 3, '10': 'restingSeconds'},
    {'1': 'yapping_seconds', '3': 9, '4': 1, '5': 3, '10': 'yappingSeconds'},
    {'1': 'lifting_seconds', '3': 10, '4': 1, '5': 3, '10': 'liftingSeconds'},
    {
      '1': 'exercises',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseSummary',
      '10': 'exercises'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
    {'1': 5, '2': 6},
    {'1': 6, '2': 7},
    {'1': 7, '2': 8},
  ],
  '10': ['volume_per_minute', 'work_rest_ratio'],
};

/// Descriptor for `WorkoutSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutSummaryDescriptor = $convert.base64Decode(
    'Cg5Xb3Jrb3V0U3VtbWFyeRIhCgx0b3RhbF92b2x1bWUYASABKAJSC3RvdGFsVm9sdW1lEikKEG'
    'R1cmF0aW9uX3NlY29uZHMYAiABKANSD2R1cmF0aW9uU2Vjb25kcxInCg9yZXN0aW5nX3NlY29u'
    'ZHMYBCABKANSDnJlc3RpbmdTZWNvbmRzEicKD3lhcHBpbmdfc2Vjb25kcxgJIAEoA1IOeWFwcG'
    'luZ1NlY29uZHMSJwoPbGlmdGluZ19zZWNvbmRzGAogASgDUg5saWZ0aW5nU2Vjb25kcxI5Cgll'
    'eGVyY2lzZXMYCCADKAsyGy53b3Jrb3V0LnYxLkV4ZXJjaXNlU3VtbWFyeVIJZXhlcmNpc2VzSg'
    'QIAxAESgQIBRAGSgQIBhAHSgQIBxAIUhF2b2x1bWVfcGVyX21pbnV0ZVIPd29ya19yZXN0X3Jh'
    'dGlv');

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
      '1': 'summary',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutSummary',
      '10': 'summary'
    },
    {
      '1': 'passed_warmup_ids',
      '3': 10,
      '4': 3,
      '5': 9,
      '10': 'passedWarmupIds'
    },
    {
      '1': 'exercise_logs',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseLog',
      '10': 'exerciseLogs'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 8, '2': 9},
  ],
  '10': ['exercise_groups', 'user_messages'],
};

/// Descriptor for `GetWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJHZXRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAMgAygLMhcud29ya291dC52MS5Qcm9wb3Nl'
    'ZFNldFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAQgAygLMhgud29ya291dC52MS'
    '5Db21wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSNwoLbmV4dF91cF9zZXQYBSABKAsyFy53b3Jr'
    'b3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSTgoRcGxhbl9jaGFuZ2Vfc3RhdHMYBiABKA'
    'syIi53b3Jrb3V0LnYxLldvcmtvdXRQbGFuQ2hhbmdlU3RhdHNSD3BsYW5DaGFuZ2VTdGF0cxJH'
    'Cg5zdGF0ZV9zbmFwc2hvdBgHIAEoCzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3'
    'RSDXN0YXRlU25hcHNob3QSNAoHc3VtbWFyeRgJIAEoCzIaLndvcmtvdXQudjEuV29ya291dFN1'
    'bW1hcnlSB3N1bW1hcnkSKgoRcGFzc2VkX3dhcm11cF9pZHMYCiADKAlSD3Bhc3NlZFdhcm11cE'
    'lkcxI8Cg1leGVyY2lzZV9sb2dzGAsgAygLMhcud29ya291dC52MS5FeGVyY2lzZUxvZ1IMZXhl'
    'cmNpc2VMb2dzSgQIAhADSgQICBAJUg9leGVyY2lzZV9ncm91cHNSDXVzZXJfbWVzc2FnZXM=');

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
    {'1': 'rest_until', '3': 4, '4': 1, '5': 3, '10': 'restUntil'},
    {
      '1': 'lifting_started_at',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'liftingStartedAt'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
    {'1': 5, '2': 6},
    {'1': 6, '2': 7},
  ],
  '10': ['active_started_at', 'last_rest_end', 'effort_prompt'],
};

/// Descriptor for `WorkoutStateSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutStateSnapshotDescriptor = $convert.base64Decode(
    'ChRXb3Jrb3V0U3RhdGVTbmFwc2hvdBIuCgVzdGF0ZRgBIAEoDjIYLndvcmtvdXQudjEuV29ya2'
    '91dFN0YXRlUgVzdGF0ZRI4CgtkaXNwbGF5X3NldBgCIAEoCzIXLndvcmtvdXQudjEuUHJvcG9z'
    'ZWRTZXRSCmRpc3BsYXlTZXQSHQoKcmVzdF91bnRpbBgEIAEoA1IJcmVzdFVudGlsEiwKEmxpZn'
    'Rpbmdfc3RhcnRlZF9hdBgHIAEoA1IQbGlmdGluZ1N0YXJ0ZWRBdEoECAMQBEoECAUQBkoECAYQ'
    'B1IRYWN0aXZlX3N0YXJ0ZWRfYXRSDWxhc3RfcmVzdF9lbmRSDWVmZm9ydF9wcm9tcHQ=');

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
    {'1': 'volume', '3': 6, '4': 1, '5': 2, '10': 'volume'},
    {'1': 'sets', '3': 7, '4': 1, '5': 5, '10': 'sets'},
    {'1': 'estimated_max', '3': 8, '4': 1, '5': 2, '10': 'estimatedMax'},
  ],
  '9': [
    {'1': 5, '2': 6},
  ],
  '10': ['best_one_rep_max'],
};

/// Descriptor for `ExerciseProgressPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseProgressPointDescriptor = $convert.base64Decode(
    'ChVFeGVyY2lzZVByb2dyZXNzUG9pbnQSEgoEZGF0ZRgBIAEoA1IEZGF0ZRIdCgp3b3Jrb3V0X2'
    'lkGAIgASgJUgl3b3Jrb3V0SWQSHQoKdG9wX3dlaWdodBgDIAEoAlIJdG9wV2VpZ2h0EhkKCHRv'
    'cF9yZXBzGAQgASgFUgd0b3BSZXBzEhYKBnZvbHVtZRgGIAEoAlIGdm9sdW1lEhIKBHNldHMYBy'
    'ABKAVSBHNldHMSIwoNZXN0aW1hdGVkX21heBgIIAEoAlIMZXN0aW1hdGVkTWF4SgQIBRAGUhBi'
    'ZXN0X29uZV9yZXBfbWF4');

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

@$core.Deprecated('Use workoutPlanResponseDescriptor instead')
const WorkoutPlanResponse$json = {
  '1': 'WorkoutPlanResponse',
  '2': [
    {
      '1': 'proposed_sets',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
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
  ],
};

/// Descriptor for `WorkoutPlanResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutPlanResponseDescriptor = $convert.base64Decode(
    'ChNXb3Jrb3V0UGxhblJlc3BvbnNlEjwKDXByb3Bvc2VkX3NldHMYASADKAsyFy53b3Jrb3V0Ln'
    'YxLlByb3Bvc2VkU2V0Ugxwcm9wb3NlZFNldHMSNwoLbmV4dF91cF9zZXQYAiABKAsyFy53b3Jr'
    'b3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdGVfc25hcHNob3QYAyABKAsyIC'
    '53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0ZVNuYXBzaG90');

@$core.Deprecated('Use addExercisesRequestDescriptor instead')
const AddExercisesRequest$json = {
  '1': 'AddExercisesRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercises',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
    {
      '1': 'decisions',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'decisions'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['client_working_set_ids'],
};

/// Descriptor for `AddExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addExercisesRequestDescriptor = $convert.base64Decode(
    'ChNBZGRFeGVyY2lzZXNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIyCg'
    'lleGVyY2lzZXMYAiADKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaXNlUglleGVyY2lzZXMSOgoJZGVj'
    'aXNpb25zGAQgAygLMhwud29ya291dC52MS5FeGVyY2lzZURlY2lzaW9uUglkZWNpc2lvbnNKBA'
    'gDEARSFmNsaWVudF93b3JraW5nX3NldF9pZHM=');

@$core.Deprecated('Use adjustExerciseWeightRequestDescriptor instead')
const AdjustExerciseWeightRequest$json = {
  '1': 'AdjustExerciseWeightRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'working_weight', '3': 3, '4': 1, '5': 2, '10': 'workingWeight'},
    {'1': 'target_reps', '3': 4, '4': 1, '5': 5, '10': 'targetReps'},
  ],
};

/// Descriptor for `AdjustExerciseWeightRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adjustExerciseWeightRequestDescriptor = $convert.base64Decode(
    'ChtBZGp1c3RFeGVyY2lzZVdlaWdodFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya2'
    '91dElkEjAKCGV4ZXJjaXNlGAIgASgOMhQud29ya291dC52MS5FeGVyY2lzZVIIZXhlcmNpc2US'
    'JQoOd29ya2luZ193ZWlnaHQYAyABKAJSDXdvcmtpbmdXZWlnaHQSHwoLdGFyZ2V0X3JlcHMYBC'
    'ABKAVSCnRhcmdldFJlcHM=');

@$core.Deprecated('Use removeExerciseRequestDescriptor instead')
const RemoveExerciseRequest$json = {
  '1': 'RemoveExerciseRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
  ],
};

/// Descriptor for `RemoveExerciseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeExerciseRequestDescriptor = $convert.base64Decode(
    'ChVSZW1vdmVFeGVyY2lzZVJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEj'
    'AKCGV4ZXJjaXNlGAIgASgOMhQud29ya291dC52MS5FeGVyY2lzZVIIZXhlcmNpc2U=');

@$core.Deprecated('Use reorderExercisesRequestDescriptor instead')
const ReorderExercisesRequest$json = {
  '1': 'ReorderExercisesRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercises',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
  ],
};

/// Descriptor for `ReorderExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExercisesRequestDescriptor = $convert.base64Decode(
    'ChdSZW9yZGVyRXhlcmNpc2VzUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SW'
    'QSMgoJZXhlcmNpc2VzGAIgAygOMhQud29ya291dC52MS5FeGVyY2lzZVIJZXhlcmNpc2Vz');

@$core.Deprecated('Use skipWarmupsRequestDescriptor instead')
const SkipWarmupsRequest$json = {
  '1': 'SkipWarmupsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
  ],
};

/// Descriptor for `SkipWarmupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skipWarmupsRequestDescriptor = $convert.base64Decode(
    'ChJTa2lwV2FybXVwc1JlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEjAKCG'
    'V4ZXJjaXNlGAIgASgOMhQud29ya291dC52MS5FeGVyY2lzZVIIZXhlcmNpc2U=');

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
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['effort'],
};

/// Descriptor for `CompleteSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetRequestDescriptor = $convert.base64Decode(
    'ChJDb21wbGV0ZVNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3'
    'Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZBIfCgthY3R1YWxfcmVwcxgDIAEo'
    'BVIKYWN0dWFsUmVwcxIjCg1hY3R1YWxfd2VpZ2h0GAQgASgCUgxhY3R1YWxXZWlnaHQSIQoMY2'
    '9tcGxldGVkX2F0GAUgASgDUgtjb21wbGV0ZWRBdEoECAYQB1IGZWZmb3J0');

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
  ],
  '9': [
    {'1': 4, '2': 5},
  ],
  '10': ['user_messages'],
};

/// Descriptor for `CompleteSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetResponseDescriptor = $convert.base64Decode(
    'ChNDb21wbGV0ZVNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0Ln'
    'YxLkNvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0EjcKC25leHRfdXBfc2V0GAIgASgLMhcud29y'
    'a291dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAMgASgLMi'
    'Aud29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdEoECAQQBVIN'
    'dXNlcl9tZXNzYWdlcw==');

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
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['user_messages'],
};

/// Descriptor for `DeleteCompletedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetResponseDescriptor = $convert.base64Decode(
    'ChpEZWxldGVDb21wbGV0ZWRTZXRSZXNwb25zZRI3CgtuZXh0X3VwX3NldBgBIAEoCzIXLndvcm'
    'tvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgCIAEoCzIg'
    'LndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3RKBAgDEARSDX'
    'VzZXJfbWVzc2FnZXM=');

@$core.Deprecated('Use editCompletedSetRequestDescriptor instead')
const EditCompletedSetRequest$json = {
  '1': 'EditCompletedSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'completed_set_id', '3': 2, '4': 1, '5': 9, '10': 'completedSetId'},
    {'1': 'actual_reps', '3': 3, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 4, '4': 1, '5': 2, '10': 'actualWeight'},
  ],
};

/// Descriptor for `EditCompletedSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editCompletedSetRequestDescriptor = $convert.base64Decode(
    'ChdFZGl0Q29tcGxldGVkU2V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SW'
    'QSKAoQY29tcGxldGVkX3NldF9pZBgCIAEoCVIOY29tcGxldGVkU2V0SWQSHwoLYWN0dWFsX3Jl'
    'cHMYAyABKAVSCmFjdHVhbFJlcHMSIwoNYWN0dWFsX3dlaWdodBgEIAEoAlIMYWN0dWFsV2VpZ2'
    'h0');

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
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['user_messages'],
};

/// Descriptor for `EndWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJFbmRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dEoECAIQA1INdXNlcl9tZXNzYWdlcw==');

@$core.Deprecated('Use workoutTemplateDescriptor instead')
const WorkoutTemplate$json = {
  '1': 'WorkoutTemplate',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'order', '3': 3, '4': 1, '5': 5, '10': 'order'},
    {
      '1': 'exercises',
      '3': 4,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
    {'1': 'created_at', '3': 5, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'updated_at', '3': 6, '4': 1, '5': 3, '10': 'updatedAt'},
    {'1': 'library_id', '3': 7, '4': 1, '5': 9, '10': 'libraryId'},
    {'1': 'coupled', '3': 8, '4': 1, '5': 8, '10': 'coupled'},
    {'1': 'in_rotation', '3': 9, '4': 1, '5': 8, '10': 'inRotation'},
  ],
};

/// Descriptor for `WorkoutTemplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutTemplateDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0VGVtcGxhdGUSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFA'
    'oFb3JkZXIYAyABKAVSBW9yZGVyEjIKCWV4ZXJjaXNlcxgEIAMoDjIULndvcmtvdXQudjEuRXhl'
    'cmNpc2VSCWV4ZXJjaXNlcxIdCgpjcmVhdGVkX2F0GAUgASgDUgljcmVhdGVkQXQSHQoKdXBkYX'
    'RlZF9hdBgGIAEoA1IJdXBkYXRlZEF0Eh0KCmxpYnJhcnlfaWQYByABKAlSCWxpYnJhcnlJZBIY'
    'Cgdjb3VwbGVkGAggASgIUgdjb3VwbGVkEh8KC2luX3JvdGF0aW9uGAkgASgIUgppblJvdGF0aW'
    '9u');

@$core.Deprecated('Use libraryTemplateDescriptor instead')
const LibraryTemplate$json = {
  '1': 'LibraryTemplate',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'blurb', '3': 3, '4': 1, '5': 9, '10': 'blurb'},
    {'1': 'group_key', '3': 4, '4': 1, '5': 9, '10': 'groupKey'},
    {'1': 'group_label', '3': 5, '4': 1, '5': 9, '10': 'groupLabel'},
    {
      '1': 'exercises',
      '3': 6,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
    {'1': 'is_default', '3': 7, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `LibraryTemplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List libraryTemplateDescriptor = $convert.base64Decode(
    'Cg9MaWJyYXJ5VGVtcGxhdGUSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFA'
    'oFYmx1cmIYAyABKAlSBWJsdXJiEhsKCWdyb3VwX2tleRgEIAEoCVIIZ3JvdXBLZXkSHwoLZ3Jv'
    'dXBfbGFiZWwYBSABKAlSCmdyb3VwTGFiZWwSMgoJZXhlcmNpc2VzGAYgAygOMhQud29ya291dC'
    '52MS5FeGVyY2lzZVIJZXhlcmNpc2VzEh0KCmlzX2RlZmF1bHQYByABKAhSCWlzRGVmYXVsdA==');

@$core.Deprecated('Use listTemplateLibraryRequestDescriptor instead')
const ListTemplateLibraryRequest$json = {
  '1': 'ListTemplateLibraryRequest',
};

/// Descriptor for `ListTemplateLibraryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTemplateLibraryRequestDescriptor =
    $convert.base64Decode('ChpMaXN0VGVtcGxhdGVMaWJyYXJ5UmVxdWVzdA==');

@$core.Deprecated('Use listTemplateLibraryResponseDescriptor instead')
const ListTemplateLibraryResponse$json = {
  '1': 'ListTemplateLibraryResponse',
  '2': [
    {
      '1': 'templates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.LibraryTemplate',
      '10': 'templates'
    },
  ],
};

/// Descriptor for `ListTemplateLibraryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTemplateLibraryResponseDescriptor =
    $convert.base64Decode(
        'ChtMaXN0VGVtcGxhdGVMaWJyYXJ5UmVzcG9uc2USOQoJdGVtcGxhdGVzGAEgAygLMhsud29ya2'
        '91dC52MS5MaWJyYXJ5VGVtcGxhdGVSCXRlbXBsYXRlcw==');

@$core.Deprecated('Use addLibraryTemplatesRequestDescriptor instead')
const AddLibraryTemplatesRequest$json = {
  '1': 'AddLibraryTemplatesRequest',
  '2': [
    {'1': 'library_ids', '3': 1, '4': 3, '5': 9, '10': 'libraryIds'},
    {
      '1': 'entries',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.LibraryTemplate',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `AddLibraryTemplatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addLibraryTemplatesRequestDescriptor =
    $convert.base64Decode(
        'ChpBZGRMaWJyYXJ5VGVtcGxhdGVzUmVxdWVzdBIfCgtsaWJyYXJ5X2lkcxgBIAMoCVIKbGlicm'
        'FyeUlkcxI1CgdlbnRyaWVzGAIgAygLMhsud29ya291dC52MS5MaWJyYXJ5VGVtcGxhdGVSB2Vu'
        'dHJpZXM=');

@$core.Deprecated('Use cloneTemplateRequestDescriptor instead')
const CloneTemplateRequest$json = {
  '1': 'CloneTemplateRequest',
  '2': [
    {'1': 'template_id', '3': 1, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'exercises',
      '3': 3,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
  ],
};

/// Descriptor for `CloneTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloneTemplateRequestDescriptor = $convert.base64Decode(
    'ChRDbG9uZVRlbXBsYXRlUmVxdWVzdBIfCgt0ZW1wbGF0ZV9pZBgBIAEoCVIKdGVtcGxhdGVJZB'
    'ISCgRuYW1lGAIgASgJUgRuYW1lEjIKCWV4ZXJjaXNlcxgDIAMoDjIULndvcmtvdXQudjEuRXhl'
    'cmNpc2VSCWV4ZXJjaXNlcw==');

@$core.Deprecated('Use cloneTemplateResponseDescriptor instead')
const CloneTemplateResponse$json = {
  '1': 'CloneTemplateResponse',
  '2': [
    {
      '1': 'template',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutTemplate',
      '10': 'template'
    },
  ],
};

/// Descriptor for `CloneTemplateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloneTemplateResponseDescriptor = $convert.base64Decode(
    'ChVDbG9uZVRlbXBsYXRlUmVzcG9uc2USNwoIdGVtcGxhdGUYASABKAsyGy53b3Jrb3V0LnYxLl'
    'dvcmtvdXRUZW1wbGF0ZVIIdGVtcGxhdGU=');

@$core.Deprecated('Use addLibraryTemplatesResponseDescriptor instead')
const AddLibraryTemplatesResponse$json = {
  '1': 'AddLibraryTemplatesResponse',
  '2': [
    {
      '1': 'home',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetHomeResponse',
      '10': 'home'
    },
  ],
};

/// Descriptor for `AddLibraryTemplatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addLibraryTemplatesResponseDescriptor =
    $convert.base64Decode(
        'ChtBZGRMaWJyYXJ5VGVtcGxhdGVzUmVzcG9uc2USLwoEaG9tZRgBIAEoCzIbLndvcmtvdXQudj'
        'EuR2V0SG9tZVJlc3BvbnNlUgRob21l');

@$core.Deprecated('Use muscleVolumeDescriptor instead')
const MuscleVolume$json = {
  '1': 'MuscleVolume',
  '2': [
    {
      '1': 'muscle',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscle'
    },
    {'1': 'completed_sets_7d', '3': 2, '4': 1, '5': 2, '10': 'completedSets7d'},
    {'1': 'target_low', '3': 3, '4': 1, '5': 5, '10': 'targetLow'},
    {'1': 'target_high', '3': 4, '4': 1, '5': 5, '10': 'targetHigh'},
  ],
};

/// Descriptor for `MuscleVolume`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List muscleVolumeDescriptor = $convert.base64Decode(
    'CgxNdXNjbGVWb2x1bWUSLwoGbXVzY2xlGAEgASgOMhcud29ya291dC52MS5NdXNjbGVHcm91cF'
    'IGbXVzY2xlEioKEWNvbXBsZXRlZF9zZXRzXzdkGAIgASgCUg9jb21wbGV0ZWRTZXRzN2QSHQoK'
    'dGFyZ2V0X2xvdxgDIAEoBVIJdGFyZ2V0TG93Eh8KC3RhcmdldF9oaWdoGAQgASgFUgp0YXJnZX'
    'RIaWdo');

@$core.Deprecated('Use muscleRecoveryStatusDescriptor instead')
const MuscleRecoveryStatus$json = {
  '1': 'MuscleRecoveryStatus',
  '2': [
    {'1': 'muscle_key', '3': 1, '4': 1, '5': 9, '10': 'muscleKey'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'last_trained_at', '3': 3, '4': 1, '5': 3, '10': 'lastTrainedAt'},
    {'1': 'recovered_at', '3': 4, '4': 1, '5': 3, '10': 'recoveredAt'},
    {'1': 'fraction', '3': 5, '4': 1, '5': 2, '10': 'fraction'},
    {'1': 'hours_remaining', '3': 6, '4': 1, '5': 3, '10': 'hoursRemaining'},
    {'1': 'recovered', '3': 7, '4': 1, '5': 8, '10': 'recovered'},
  ],
  '9': [
    {'1': 8, '2': 9},
  ],
  '10': ['in_next_workout'],
};

/// Descriptor for `MuscleRecoveryStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List muscleRecoveryStatusDescriptor = $convert.base64Decode(
    'ChRNdXNjbGVSZWNvdmVyeVN0YXR1cxIdCgptdXNjbGVfa2V5GAEgASgJUgltdXNjbGVLZXkSFA'
    'oFbGFiZWwYAiABKAlSBWxhYmVsEiYKD2xhc3RfdHJhaW5lZF9hdBgDIAEoA1INbGFzdFRyYWlu'
    'ZWRBdBIhCgxyZWNvdmVyZWRfYXQYBCABKANSC3JlY292ZXJlZEF0EhoKCGZyYWN0aW9uGAUgAS'
    'gCUghmcmFjdGlvbhInCg9ob3Vyc19yZW1haW5pbmcYBiABKANSDmhvdXJzUmVtYWluaW5nEhwK'
    'CXJlY292ZXJlZBgHIAEoCFIJcmVjb3ZlcmVkSgQICBAJUg9pbl9uZXh0X3dvcmtvdXQ=');

@$core.Deprecated('Use getHomeRequestDescriptor instead')
const GetHomeRequest$json = {
  '1': 'GetHomeRequest',
  '2': [
    {'1': 'budget_minutes', '3': 1, '4': 1, '5': 5, '10': 'budgetMinutes'},
  ],
};

/// Descriptor for `GetHomeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRIb21lUmVxdWVzdBIlCg5idWRnZXRfbWludXRlcxgBIAEoBVINYnVkZ2V0TWludXRlcw'
    '==');

@$core.Deprecated('Use getHomeResponseDescriptor instead')
const GetHomeResponse$json = {
  '1': 'GetHomeResponse',
  '2': [
    {
      '1': 'templates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutTemplate',
      '10': 'templates'
    },
    {'1': 'active_workout_id', '3': 3, '4': 1, '5': 9, '10': 'activeWorkoutId'},
    {
      '1': 'volume',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.MuscleVolume',
      '10': 'volume'
    },
    {
      '1': 'recovery',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.MuscleRecoveryStatus',
      '10': 'recovery'
    },
    {
      '1': 'suggested_template_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'suggestedTemplateId'
    },
    {
      '1': 'suggestion_reason',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SuggestionReason',
      '10': 'suggestionReason'
    },
    {'1': 'onboarded', '3': 9, '4': 1, '5': 8, '10': 'onboarded'},
    {
      '1': 'plans',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExercisePlan',
      '10': 'plans'
    },
    {
      '1': 'template_plans',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TemplatePlan',
      '10': 'templatePlans'
    },
    {'1': 'budget_minutes', '3': 12, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {
      '1': 'rotation_check',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RotationCheck',
      '10': 'rotationCheck'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 4, '2': 5},
    {'1': 8, '2': 9},
  ],
  '10': ['trackers', 'user_messages'],
};

/// Descriptor for `GetHomeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRIb21lUmVzcG9uc2USOQoJdGVtcGxhdGVzGAEgAygLMhsud29ya291dC52MS5Xb3Jrb3'
    'V0VGVtcGxhdGVSCXRlbXBsYXRlcxIqChFhY3RpdmVfd29ya291dF9pZBgDIAEoCVIPYWN0aXZl'
    'V29ya291dElkEjAKBnZvbHVtZRgFIAMoCzIYLndvcmtvdXQudjEuTXVzY2xlVm9sdW1lUgZ2b2'
    'x1bWUSPAoIcmVjb3ZlcnkYBiADKAsyIC53b3Jrb3V0LnYxLk11c2NsZVJlY292ZXJ5U3RhdHVz'
    'UghyZWNvdmVyeRIyChVzdWdnZXN0ZWRfdGVtcGxhdGVfaWQYByABKAlSE3N1Z2dlc3RlZFRlbX'
    'BsYXRlSWQSSQoRc3VnZ2VzdGlvbl9yZWFzb24YDSABKAsyHC53b3Jrb3V0LnYxLlN1Z2dlc3Rp'
    'b25SZWFzb25SEHN1Z2dlc3Rpb25SZWFzb24SHAoJb25ib2FyZGVkGAkgASgIUglvbmJvYXJkZW'
    'QSLgoFcGxhbnMYCiADKAsyGC53b3Jrb3V0LnYxLkV4ZXJjaXNlUGxhblIFcGxhbnMSPwoOdGVt'
    'cGxhdGVfcGxhbnMYCyADKAsyGC53b3Jrb3V0LnYxLlRlbXBsYXRlUGxhblINdGVtcGxhdGVQbG'
    'FucxIlCg5idWRnZXRfbWludXRlcxgMIAEoBVINYnVkZ2V0TWludXRlcxJACg5yb3RhdGlvbl9j'
    'aGVjaxgOIAEoCzIZLndvcmtvdXQudjEuUm90YXRpb25DaGVja1INcm90YXRpb25DaGVja0oECA'
    'IQA0oECAQQBUoECAgQCVIIdHJhY2tlcnNSDXVzZXJfbWVzc2FnZXM=');

@$core.Deprecated('Use suggestionReasonDescriptor instead')
const SuggestionReason$json = {
  '1': 'SuggestionReason',
  '2': [
    {
      '1': 'behind',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SuggestionMuscle',
      '10': 'behind'
    },
    {
      '1': 'recovering',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.RecoveringMuscle',
      '10': 'recovering'
    },
    {'1': 'fallback', '3': 3, '4': 1, '5': 8, '10': 'fallback'},
    {
      '1': 'first_lift_recovering',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RecoveringMuscle',
      '10': 'firstLiftRecovering'
    },
  ],
  '9': [
    {'1': 4, '2': 5},
  ],
  '10': ['overdue'],
};

/// Descriptor for `SuggestionReason`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestionReasonDescriptor = $convert.base64Decode(
    'ChBTdWdnZXN0aW9uUmVhc29uEjQKBmJlaGluZBgBIAMoCzIcLndvcmtvdXQudjEuU3VnZ2VzdG'
    'lvbk11c2NsZVIGYmVoaW5kEjwKCnJlY292ZXJpbmcYAiADKAsyHC53b3Jrb3V0LnYxLlJlY292'
    'ZXJpbmdNdXNjbGVSCnJlY292ZXJpbmcSGgoIZmFsbGJhY2sYAyABKAhSCGZhbGxiYWNrElAKFW'
    'ZpcnN0X2xpZnRfcmVjb3ZlcmluZxgFIAEoCzIcLndvcmtvdXQudjEuUmVjb3ZlcmluZ011c2Ns'
    'ZVITZmlyc3RMaWZ0UmVjb3ZlcmluZ0oECAQQBVIHb3ZlcmR1ZQ==');

@$core.Deprecated('Use suggestionMuscleDescriptor instead')
const SuggestionMuscle$json = {
  '1': 'SuggestionMuscle',
  '2': [
    {
      '1': 'muscle',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscle'
    },
    {'1': 'sets_7d', '3': 2, '4': 1, '5': 2, '10': 'sets7d'},
    {'1': 'target', '3': 3, '4': 1, '5': 5, '10': 'target'},
  ],
};

/// Descriptor for `SuggestionMuscle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestionMuscleDescriptor = $convert.base64Decode(
    'ChBTdWdnZXN0aW9uTXVzY2xlEi8KBm11c2NsZRgBIAEoDjIXLndvcmtvdXQudjEuTXVzY2xlR3'
    'JvdXBSBm11c2NsZRIXCgdzZXRzXzdkGAIgASgCUgZzZXRzN2QSFgoGdGFyZ2V0GAMgASgFUgZ0'
    'YXJnZXQ=');

@$core.Deprecated('Use recoveringMuscleDescriptor instead')
const RecoveringMuscle$json = {
  '1': 'RecoveringMuscle',
  '2': [
    {
      '1': 'muscle',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscle'
    },
    {'1': 'hours_remaining', '3': 2, '4': 1, '5': 5, '10': 'hoursRemaining'},
  ],
};

/// Descriptor for `RecoveringMuscle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recoveringMuscleDescriptor = $convert.base64Decode(
    'ChBSZWNvdmVyaW5nTXVzY2xlEi8KBm11c2NsZRgBIAEoDjIXLndvcmtvdXQudjEuTXVzY2xlR3'
    'JvdXBSBm11c2NsZRInCg9ob3Vyc19yZW1haW5pbmcYAiABKAVSDmhvdXJzUmVtYWluaW5n');

@$core.Deprecated('Use rotationCheckDescriptor instead')
const RotationCheck$json = {
  '1': 'RotationCheck',
  '2': [
    {
      '1': 'volume',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.MuscleVolume',
      '10': 'volume'
    },
    {
      '1': 'warnings',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.RotationWarning',
      '10': 'warnings'
    },
  ],
};

/// Descriptor for `RotationCheck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotationCheckDescriptor = $convert.base64Decode(
    'Cg1Sb3RhdGlvbkNoZWNrEjAKBnZvbHVtZRgBIAMoCzIYLndvcmtvdXQudjEuTXVzY2xlVm9sdW'
    '1lUgZ2b2x1bWUSNwoId2FybmluZ3MYAiADKAsyGy53b3Jrb3V0LnYxLlJvdGF0aW9uV2Fybmlu'
    'Z1IId2FybmluZ3M=');

@$core.Deprecated('Use rotationWarningDescriptor instead')
const RotationWarning$json = {
  '1': 'RotationWarning',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RotationWarningKind',
      '10': 'kind'
    },
    {
      '1': 'muscles',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscles'
    },
    {'1': 'template_ids', '3': 3, '4': 3, '5': 9, '10': 'templateIds'},
    {'1': 'shared', '3': 4, '4': 1, '5': 5, '10': 'shared'},
    {'1': 'of', '3': 5, '4': 1, '5': 5, '10': 'of'},
  ],
};

/// Descriptor for `RotationWarning`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotationWarningDescriptor = $convert.base64Decode(
    'Cg9Sb3RhdGlvbldhcm5pbmcSMwoEa2luZBgBIAEoDjIfLndvcmtvdXQudjEuUm90YXRpb25XYX'
    'JuaW5nS2luZFIEa2luZBIxCgdtdXNjbGVzGAIgAygOMhcud29ya291dC52MS5NdXNjbGVHcm91'
    'cFIHbXVzY2xlcxIhCgx0ZW1wbGF0ZV9pZHMYAyADKAlSC3RlbXBsYXRlSWRzEhYKBnNoYXJlZB'
    'gEIAEoBVIGc2hhcmVkEg4KAm9mGAUgASgFUgJvZg==');

@$core.Deprecated('Use templatePlanDescriptor instead')
const TemplatePlan$json = {
  '1': 'TemplatePlan',
  '2': [
    {'1': 'template_id', '3': 1, '4': 1, '5': 9, '10': 'templateId'},
    {
      '1': 'plans',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExercisePlan',
      '10': 'plans'
    },
    {
      '1': 'estimated_seconds',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'estimatedSeconds'
    },
    {'1': 'max_seconds', '3': 4, '4': 1, '5': 5, '10': 'maxSeconds'},
  ],
};

/// Descriptor for `TemplatePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List templatePlanDescriptor = $convert.base64Decode(
    'CgxUZW1wbGF0ZVBsYW4SHwoLdGVtcGxhdGVfaWQYASABKAlSCnRlbXBsYXRlSWQSLgoFcGxhbn'
    'MYAiADKAsyGC53b3Jrb3V0LnYxLkV4ZXJjaXNlUGxhblIFcGxhbnMSKwoRZXN0aW1hdGVkX3Nl'
    'Y29uZHMYAyABKAVSEGVzdGltYXRlZFNlY29uZHMSHwoLbWF4X3NlY29uZHMYBCABKAVSCm1heF'
    'NlY29uZHM=');

@$core.Deprecated('Use getExercisePlanRequestDescriptor instead')
const GetExercisePlanRequest$json = {
  '1': 'GetExercisePlanRequest',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'budget_minutes', '3': 2, '4': 1, '5': 5, '10': 'budgetMinutes'},
  ],
};

/// Descriptor for `GetExercisePlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExercisePlanRequestDescriptor = $convert.base64Decode(
    'ChZHZXRFeGVyY2lzZVBsYW5SZXF1ZXN0EjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC52MS'
    '5FeGVyY2lzZVIIZXhlcmNpc2USJQoOYnVkZ2V0X21pbnV0ZXMYAiABKAVSDWJ1ZGdldE1pbnV0'
    'ZXM=');

@$core.Deprecated('Use getExercisePlanResponseDescriptor instead')
const GetExercisePlanResponse$json = {
  '1': 'GetExercisePlanResponse',
  '2': [
    {
      '1': 'plan',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExercisePlan',
      '10': 'plan'
    },
  ],
};

/// Descriptor for `GetExercisePlanResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getExercisePlanResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRFeGVyY2lzZVBsYW5SZXNwb25zZRIsCgRwbGFuGAEgASgLMhgud29ya291dC52MS5FeG'
        'VyY2lzZVBsYW5SBHBsYW4=');

@$core.Deprecated('Use getTemplatePlanRequestDescriptor instead')
const GetTemplatePlanRequest$json = {
  '1': 'GetTemplatePlanRequest',
  '2': [
    {
      '1': 'exercises',
      '3': 1,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercises'
    },
    {'1': 'budget_minutes', '3': 2, '4': 1, '5': 5, '10': 'budgetMinutes'},
  ],
};

/// Descriptor for `GetTemplatePlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTemplatePlanRequestDescriptor = $convert.base64Decode(
    'ChZHZXRUZW1wbGF0ZVBsYW5SZXF1ZXN0EjIKCWV4ZXJjaXNlcxgBIAMoDjIULndvcmtvdXQudj'
    'EuRXhlcmNpc2VSCWV4ZXJjaXNlcxIlCg5idWRnZXRfbWludXRlcxgCIAEoBVINYnVkZ2V0TWlu'
    'dXRlcw==');

@$core.Deprecated('Use getTemplatePlanResponseDescriptor instead')
const GetTemplatePlanResponse$json = {
  '1': 'GetTemplatePlanResponse',
  '2': [
    {
      '1': 'plan',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TemplatePlan',
      '10': 'plan'
    },
  ],
};

/// Descriptor for `GetTemplatePlanResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTemplatePlanResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRUZW1wbGF0ZVBsYW5SZXNwb25zZRIsCgRwbGFuGAEgASgLMhgud29ya291dC52MS5UZW'
        '1wbGF0ZVBsYW5SBHBsYW4=');

@$core.Deprecated('Use saveTemplateRequestDescriptor instead')
const SaveTemplateRequest$json = {
  '1': 'SaveTemplateRequest',
  '2': [
    {
      '1': 'template',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutTemplate',
      '10': 'template'
    },
    {'1': 'unlink', '3': 2, '4': 1, '5': 8, '10': 'unlink'},
  ],
};

/// Descriptor for `SaveTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveTemplateRequestDescriptor = $convert.base64Decode(
    'ChNTYXZlVGVtcGxhdGVSZXF1ZXN0EjcKCHRlbXBsYXRlGAEgASgLMhsud29ya291dC52MS5Xb3'
    'Jrb3V0VGVtcGxhdGVSCHRlbXBsYXRlEhYKBnVubGluaxgCIAEoCFIGdW5saW5r');

@$core.Deprecated('Use saveTemplateResponseDescriptor instead')
const SaveTemplateResponse$json = {
  '1': 'SaveTemplateResponse',
  '2': [
    {
      '1': 'template',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutTemplate',
      '10': 'template'
    },
  ],
};

/// Descriptor for `SaveTemplateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveTemplateResponseDescriptor = $convert.base64Decode(
    'ChRTYXZlVGVtcGxhdGVSZXNwb25zZRI3Cgh0ZW1wbGF0ZRgBIAEoCzIbLndvcmtvdXQudjEuV2'
    '9ya291dFRlbXBsYXRlUgh0ZW1wbGF0ZQ==');

@$core.Deprecated('Use deleteTemplateRequestDescriptor instead')
const DeleteTemplateRequest$json = {
  '1': 'DeleteTemplateRequest',
  '2': [
    {'1': 'template_id', '3': 1, '4': 1, '5': 9, '10': 'templateId'},
  ],
};

/// Descriptor for `DeleteTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTemplateRequestDescriptor = $convert.base64Decode(
    'ChVEZWxldGVUZW1wbGF0ZVJlcXVlc3QSHwoLdGVtcGxhdGVfaWQYASABKAlSCnRlbXBsYXRlSW'
    'Q=');

@$core.Deprecated('Use deleteTemplateResponseDescriptor instead')
const DeleteTemplateResponse$json = {
  '1': 'DeleteTemplateResponse',
};

/// Descriptor for `DeleteTemplateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTemplateResponseDescriptor =
    $convert.base64Decode('ChZEZWxldGVUZW1wbGF0ZVJlc3BvbnNl');

@$core.Deprecated('Use reorderTemplatesRequestDescriptor instead')
const ReorderTemplatesRequest$json = {
  '1': 'ReorderTemplatesRequest',
  '2': [
    {'1': 'template_ids', '3': 1, '4': 3, '5': 9, '10': 'templateIds'},
  ],
};

/// Descriptor for `ReorderTemplatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderTemplatesRequestDescriptor =
    $convert.base64Decode(
        'ChdSZW9yZGVyVGVtcGxhdGVzUmVxdWVzdBIhCgx0ZW1wbGF0ZV9pZHMYASADKAlSC3RlbXBsYX'
        'RlSWRz');

@$core.Deprecated('Use reorderTemplatesResponseDescriptor instead')
const ReorderTemplatesResponse$json = {
  '1': 'ReorderTemplatesResponse',
};

/// Descriptor for `ReorderTemplatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderTemplatesResponseDescriptor =
    $convert.base64Decode('ChhSZW9yZGVyVGVtcGxhdGVzUmVzcG9uc2U=');

@$core.Deprecated('Use setOverrideRequestDescriptor instead')
const SetOverrideRequest$json = {
  '1': 'SetOverrideRequest',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'weight', '3': 2, '4': 1, '5': 2, '10': 'weight'},
    {'1': 'reps', '3': 3, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'sets', '17': true},
  ],
  '8': [
    {'1': '_sets'},
  ],
};

/// Descriptor for `SetOverrideRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setOverrideRequestDescriptor = $convert.base64Decode(
    'ChJTZXRPdmVycmlkZVJlcXVlc3QSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZX'
    'JjaXNlUghleGVyY2lzZRIWCgZ3ZWlnaHQYAiABKAJSBndlaWdodBISCgRyZXBzGAMgASgFUgRy'
    'ZXBzEhcKBHNldHMYBCABKAVIAFIEc2V0c4gBAUIHCgVfc2V0cw==');

@$core.Deprecated('Use setOverrideResponseDescriptor instead')
const SetOverrideResponse$json = {
  '1': 'SetOverrideResponse',
  '2': [
    {
      '1': 'plan',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExercisePlan',
      '10': 'plan'
    },
  ],
};

/// Descriptor for `SetOverrideResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setOverrideResponseDescriptor = $convert.base64Decode(
    'ChNTZXRPdmVycmlkZVJlc3BvbnNlEiwKBHBsYW4YASABKAsyGC53b3Jrb3V0LnYxLkV4ZXJjaX'
    'NlUGxhblIEcGxhbg==');

@$core.Deprecated('Use completeOnboardingRequestDescriptor instead')
const CompleteOnboardingRequest$json = {
  '1': 'CompleteOnboardingRequest',
  '2': [
    {
      '1': 'unit',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WeightUnit',
      '10': 'unit'
    },
    {'1': 'library_ids', '3': 5, '4': 3, '5': 9, '10': 'libraryIds'},
    {
      '1': 'strength',
      '3': 6,
      '4': 1,
      '5': 2,
      '9': 0,
      '10': 'strength',
      '17': true
    },
    {
      '1': 'library_entries',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.LibraryTemplate',
      '10': 'libraryEntries'
    },
    {
      '1': 'starting_weights',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseWeight',
      '10': 'startingWeights'
    },
  ],
  '8': [
    {'1': '_strength'},
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 4, '2': 5},
  ],
  '10': ['body_weight_kg', 'experience', 'gender'],
};

/// Descriptor for `CompleteOnboardingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeOnboardingRequestDescriptor = $convert.base64Decode(
    'ChlDb21wbGV0ZU9uYm9hcmRpbmdSZXF1ZXN0EioKBHVuaXQYAyABKA4yFi53b3Jrb3V0LnYxLl'
    'dlaWdodFVuaXRSBHVuaXQSHwoLbGlicmFyeV9pZHMYBSADKAlSCmxpYnJhcnlJZHMSHwoIc3Ry'
    'ZW5ndGgYBiABKAJIAFIIc3RyZW5ndGiIAQESRAoPbGlicmFyeV9lbnRyaWVzGAcgAygLMhsud2'
    '9ya291dC52MS5MaWJyYXJ5VGVtcGxhdGVSDmxpYnJhcnlFbnRyaWVzEkUKEHN0YXJ0aW5nX3dl'
    'aWdodHMYCCADKAsyGi53b3Jrb3V0LnYxLkV4ZXJjaXNlV2VpZ2h0Ug9zdGFydGluZ1dlaWdodH'
    'NCCwoJX3N0cmVuZ3RoSgQIARACSgQIAhADSgQIBBAFUg5ib2R5X3dlaWdodF9rZ1IKZXhwZXJp'
    'ZW5jZVIGZ2VuZGVy');

@$core.Deprecated('Use getStartingWeightsRequestDescriptor instead')
const GetStartingWeightsRequest$json = {
  '1': 'GetStartingWeightsRequest',
  '2': [
    {
      '1': 'unit',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WeightUnit',
      '10': 'unit'
    },
  ],
};

/// Descriptor for `GetStartingWeightsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStartingWeightsRequestDescriptor =
    $convert.base64Decode(
        'ChlHZXRTdGFydGluZ1dlaWdodHNSZXF1ZXN0EioKBHVuaXQYASABKA4yFi53b3Jrb3V0LnYxLl'
        'dlaWdodFVuaXRSBHVuaXQ=');

@$core.Deprecated('Use exerciseWeightDescriptor instead')
const ExerciseWeight$json = {
  '1': 'ExerciseWeight',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'weight_lb', '3': 2, '4': 1, '5': 2, '10': 'weightLb'},
  ],
};

/// Descriptor for `ExerciseWeight`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseWeightDescriptor = $convert.base64Decode(
    'Cg5FeGVyY2lzZVdlaWdodBIwCghleGVyY2lzZRgBIAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2'
    'VSCGV4ZXJjaXNlEhsKCXdlaWdodF9sYhgCIAEoAlIId2VpZ2h0TGI=');

@$core.Deprecated('Use startingWeightsStepDescriptor instead')
const StartingWeightsStep$json = {
  '1': 'StartingWeightsStep',
  '2': [
    {
      '1': 'weights',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseWeight',
      '10': 'weights'
    },
  ],
};

/// Descriptor for `StartingWeightsStep`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startingWeightsStepDescriptor = $convert.base64Decode(
    'ChNTdGFydGluZ1dlaWdodHNTdGVwEjQKB3dlaWdodHMYASADKAsyGi53b3Jrb3V0LnYxLkV4ZX'
    'JjaXNlV2VpZ2h0Ugd3ZWlnaHRz');

@$core.Deprecated('Use getStartingWeightsResponseDescriptor instead')
const GetStartingWeightsResponse$json = {
  '1': 'GetStartingWeightsResponse',
  '2': [
    {
      '1': 'steps',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.StartingWeightsStep',
      '10': 'steps'
    },
  ],
};

/// Descriptor for `GetStartingWeightsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStartingWeightsResponseDescriptor =
    $convert.base64Decode(
        'ChpHZXRTdGFydGluZ1dlaWdodHNSZXNwb25zZRI1CgVzdGVwcxgBIAMoCzIfLndvcmtvdXQudj'
        'EuU3RhcnRpbmdXZWlnaHRzU3RlcFIFc3RlcHM=');

@$core.Deprecated('Use completeOnboardingResponseDescriptor instead')
const CompleteOnboardingResponse$json = {
  '1': 'CompleteOnboardingResponse',
  '2': [
    {
      '1': 'home',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetHomeResponse',
      '10': 'home'
    },
  ],
};

/// Descriptor for `CompleteOnboardingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeOnboardingResponseDescriptor =
    $convert.base64Decode(
        'ChpDb21wbGV0ZU9uYm9hcmRpbmdSZXNwb25zZRIvCgRob21lGAEgASgLMhsud29ya291dC52MS'
        '5HZXRIb21lUmVzcG9uc2VSBGhvbWU=');

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

@$core.Deprecated('Use setWorkoutSessionRequestDescriptor instead')
const SetWorkoutSessionRequest$json = {
  '1': 'SetWorkoutSessionRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `SetWorkoutSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setWorkoutSessionRequestDescriptor =
    $convert.base64Decode(
        'ChhTZXRXb3Jrb3V0U2Vzc2lvblJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dE'
        'lkEh0KCnNlc3Npb25faWQYAiABKAlSCXNlc3Npb25JZA==');

@$core.Deprecated('Use workoutMutationDescriptor instead')
const WorkoutMutation$json = {
  '1': 'WorkoutMutation',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'client_created_at', '3': 2, '4': 1, '5': 3, '10': 'clientCreatedAt'},
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
      '1': 'add_exercises',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AddExercisesRequest',
      '9': 0,
      '10': 'addExercises'
    },
    {
      '1': 'adjust_exercise_weight',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AdjustExerciseWeightRequest',
      '9': 0,
      '10': 'adjustExerciseWeight'
    },
    {
      '1': 'remove_exercise',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RemoveExerciseRequest',
      '9': 0,
      '10': 'removeExercise'
    },
    {
      '1': 'reorder_exercises',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ReorderExercisesRequest',
      '9': 0,
      '10': 'reorderExercises'
    },
    {
      '1': 'edit_completed_set',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.EditCompletedSetRequest',
      '9': 0,
      '10': 'editCompletedSet'
    },
    {
      '1': 'start_set',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartSetRequest',
      '9': 0,
      '10': 'startSet'
    },
    {
      '1': 'skip_warmups',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SkipWarmupsRequest',
      '9': 0,
      '10': 'skipWarmups'
    },
    {
      '1': 'set_session',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SetWorkoutSessionRequest',
      '9': 0,
      '10': 'setSession'
    },
  ],
  '8': [
    {'1': 'mutation'},
  ],
  '9': [
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 15, '2': 16},
    {'1': 16, '2': 17},
    {'1': 21, '2': 22},
    {'1': 22, '2': 23},
  ],
  '10': ['skip_rest', 'cancel_proposed_set', 'rate_exercise'],
};

/// Descriptor for `WorkoutMutation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutMutationDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0TXV0YXRpb24SGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQSKgoRY2xpZW50X2'
    'NyZWF0ZWRfYXQYAiABKANSD2NsaWVudENyZWF0ZWRBdBJDCgxjb21wbGV0ZV9zZXQYCyABKAsy'
    'Hi53b3Jrb3V0LnYxLkNvbXBsZXRlU2V0UmVxdWVzdEgAUgtjb21wbGV0ZVNldBJZChRkZWxldG'
    'VfY29tcGxldGVkX3NldBgNIAEoCzIlLndvcmtvdXQudjEuRGVsZXRlQ29tcGxldGVkU2V0UmVx'
    'dWVzdEgAUhJkZWxldGVDb21wbGV0ZWRTZXQSQAoLZW5kX3dvcmtvdXQYDiABKAsyHS53b3Jrb3'
    'V0LnYxLkVuZFdvcmtvdXRSZXF1ZXN0SABSCmVuZFdvcmtvdXQSRgoNYWRkX2V4ZXJjaXNlcxgR'
    'IAEoCzIfLndvcmtvdXQudjEuQWRkRXhlcmNpc2VzUmVxdWVzdEgAUgxhZGRFeGVyY2lzZXMSXw'
    'oWYWRqdXN0X2V4ZXJjaXNlX3dlaWdodBgSIAEoCzInLndvcmtvdXQudjEuQWRqdXN0RXhlcmNp'
    'c2VXZWlnaHRSZXF1ZXN0SABSFGFkanVzdEV4ZXJjaXNlV2VpZ2h0EkwKD3JlbW92ZV9leGVyY2'
    'lzZRgTIAEoCzIhLndvcmtvdXQudjEuUmVtb3ZlRXhlcmNpc2VSZXF1ZXN0SABSDnJlbW92ZUV4'
    'ZXJjaXNlElIKEXJlb3JkZXJfZXhlcmNpc2VzGBQgASgLMiMud29ya291dC52MS5SZW9yZGVyRX'
    'hlcmNpc2VzUmVxdWVzdEgAUhByZW9yZGVyRXhlcmNpc2VzElMKEmVkaXRfY29tcGxldGVkX3Nl'
    'dBgXIAEoCzIjLndvcmtvdXQudjEuRWRpdENvbXBsZXRlZFNldFJlcXVlc3RIAFIQZWRpdENvbX'
    'BsZXRlZFNldBI6CglzdGFydF9zZXQYGCABKAsyGy53b3Jrb3V0LnYxLlN0YXJ0U2V0UmVxdWVz'
    'dEgAUghzdGFydFNldBJDCgxza2lwX3dhcm11cHMYGSABKAsyHi53b3Jrb3V0LnYxLlNraXBXYX'
    'JtdXBzUmVxdWVzdEgAUgtza2lwV2FybXVwcxJHCgtzZXRfc2Vzc2lvbhgaIAEoCzIkLndvcmtv'
    'dXQudjEuU2V0V29ya291dFNlc3Npb25SZXF1ZXN0SABSCnNldFNlc3Npb25CCgoIbXV0YXRpb2'
    '5KBAgKEAtKBAgMEA1KBAgPEBBKBAgQEBFKBAgVEBZKBAgWEBdSCXNraXBfcmVzdFITY2FuY2Vs'
    'X3Byb3Bvc2VkX3NldFINcmF0ZV9leGVyY2lzZQ==');

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
