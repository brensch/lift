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

@$core.Deprecated('Use genderDescriptor instead')
const Gender$json = {
  '1': 'Gender',
  '2': [
    {'1': 'GENDER_UNSPECIFIED', '2': 0},
    {'1': 'GENDER_FEMALE', '2': 1},
    {'1': 'GENDER_MALE', '2': 2},
  ],
};

/// Descriptor for `Gender`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List genderDescriptor = $convert.base64Decode(
    'CgZHZW5kZXISFgoSR0VOREVSX1VOU1BFQ0lGSUVEEAASEQoNR0VOREVSX0ZFTUFMRRABEg8KC0'
    'dFTkRFUl9NQUxFEAI=');

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
  ],
};

/// Descriptor for `Workout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDescriptor = $convert.base64Decode(
    'CgdXb3Jrb3V0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YXJ0X3'
    'RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZRIdCgpzZXNz'
    'aW9uX2lkGAUgASgJUglzZXNzaW9uSWQSHwoLdGVtcGxhdGVfaWQYBiABKAlSCnRlbXBsYXRlSW'
    'Q=');

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
  ],
  '9': [
    {'1': 8, '2': 9},
    {'1': 12, '2': 13},
    {'1': 13, '2': 14},
    {'1': 14, '2': 15},
  ],
  '10': ['exercise_group_id', 'is_amrap', 'instruction', 'progression_hint'],
};

/// Descriptor for `ProposedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedSetDescriptor = $convert.base64Decode(
    'CgtQcm9wb3NlZFNldBIOCgJpZBgBIAEoCVICaWQSHQoKd29ya291dF9pZBgCIAEoCVIJd29ya2'
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIwCghleGVyY2lzZRgE'
    'IAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEh8KC3RhcmdldF9yZXBzGAUgAS'
    'gFUgp0YXJnZXRSZXBzEiMKDXRhcmdldF93ZWlnaHQYBiABKAJSDHRhcmdldFdlaWdodBIWCgZ3'
    'YXJtdXAYByABKAhSBndhcm11cBIsChJyZXN0X2FmdGVyX3N1Y2Nlc3MYCSABKAVSEHJlc3RBZn'
    'RlclN1Y2Nlc3MSLAoScmVzdF9hZnRlcl9mYWlsdXJlGAogASgFUhByZXN0QWZ0ZXJGYWlsdXJl'
    'EhwKCWNhbmNlbGxlZBgLIAEoCFIJY2FuY2VsbGVkSgQICBAJSgQIDBANSgQIDRAOSgQIDhAPUh'
    'FleGVyY2lzZV9ncm91cF9pZFIIaXNfYW1yYXBSC2luc3RydWN0aW9uUhBwcm9ncmVzc2lvbl9o'
    'aW50');

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
    {'1': 10, '2': 11},
    {'1': 13, '2': 14},
  ],
  '10': ['exercise_group_id', 'metadata_json'],
};

/// Descriptor for `UserMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userMessageDescriptor = $convert.base64Decode(
    'CgtVc2VyTWVzc2FnZRIfCgttZXNzYWdlX2tleRgBIAEoCVIKbWVzc2FnZUtleRIvCgRraW5kGA'
    'IgASgOMhsud29ya291dC52MS5Vc2VyTWVzc2FnZUtpbmRSBGtpbmQSOAoHc3VyZmFjZRgDIAEo'
    'DjIeLndvcmtvdXQudjEuVXNlck1lc3NhZ2VTdXJmYWNlUgdzdXJmYWNlEhQKBXRpdGxlGAQgAS'
    'gJUgV0aXRsZRISCgRib2R5GAUgASgJUgRib2R5EiAKC2Rpc21pc3NpYmxlGAYgASgIUgtkaXNt'
    'aXNzaWJsZRIdCgpjcmVhdGVkX2F0GAcgASgDUgljcmVhdGVkQXQSHQoKdXBkYXRlZF9hdBgIIA'
    'EoA1IJdXBkYXRlZEF0Eh0KCndvcmtvdXRfaWQYCSABKAlSCXdvcmtvdXRJZBIwCghleGVyY2lz'
    'ZRgLIAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEhkKCHNsb3Rfa2V5GAwgAS'
    'gJUgdzbG90S2V5EjgKB2RldGFpbHMYDiABKAsyHi53b3Jrb3V0LnYxLlVzZXJNZXNzYWdlRGV0'
    'YWlsc1IHZGV0YWlscxIqChFzb3VyY2Vfd29ya291dF9pZBgPIAEoCVIPc291cmNlV29ya291dE'
    'lkSgQIChALSgQIDRAOUhFleGVyY2lzZV9ncm91cF9pZFINbWV0YWRhdGFfanNvbg==');

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
    'ZXJjaXNlcxgFIAMoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCWV4ZXJjaXNlc0oECAIQA1IPZX'
    'hlcmNpc2VfZ3JvdXBz');

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
      '1': 'user_messages',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['exercise_groups'],
};

/// Descriptor for `StartWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutResponseDescriptor = $convert.base64Decode(
    'ChRTdGFydFdvcmtvdXRSZXNwb25zZRIOCgJpZBgBIAEoCVICaWQSLQoHd29ya291dBgCIAEoCz'
    'ITLndvcmtvdXQudjEuV29ya291dFIHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAQgAygLMhcu'
    'd29ya291dC52MS5Qcm9wb3NlZFNldFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGA'
    'UgAygLMhgud29ya291dC52MS5Db21wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSNwoLbmV4dF91'
    'cF9zZXQYBiABKAsyFy53b3Jrb3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdG'
    'Vfc25hcHNob3QYByABKAsyIC53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0'
    'ZVNuYXBzaG90EjwKDXVzZXJfbWVzc2FnZXMYCCADKAsyFy53b3Jrb3V0LnYxLlVzZXJNZXNzYW'
    'dlUgx1c2VyTWVzc2FnZXNKBAgDEARSD2V4ZXJjaXNlX2dyb3Vwcw==');

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
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['exercise_groups'],
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
    'RSDXN0YXRlU25hcHNob3QSPAoNdXNlcl9tZXNzYWdlcxgIIAMoCzIXLndvcmtvdXQudjEuVXNl'
    'ck1lc3NhZ2VSDHVzZXJNZXNzYWdlcxI0CgdzdW1tYXJ5GAkgASgLMhoud29ya291dC52MS5Xb3'
    'Jrb3V0U3VtbWFyeVIHc3VtbWFyeUoECAIQA1IPZXhlcmNpc2VfZ3JvdXBz');

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
      '1': 'client_working_set_ids',
      '3': 3,
      '4': 3,
      '5': 9,
      '10': 'clientWorkingSetIds'
    },
  ],
};

/// Descriptor for `AddExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addExercisesRequestDescriptor = $convert.base64Decode(
    'ChNBZGRFeGVyY2lzZXNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIyCg'
    'lleGVyY2lzZXMYAiADKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaXNlUglleGVyY2lzZXMSMwoWY2xp'
    'ZW50X3dvcmtpbmdfc2V0X2lkcxgDIAMoCVITY2xpZW50V29ya2luZ1NldElkcw==');

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
  ],
};

/// Descriptor for `AdjustExerciseWeightRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adjustExerciseWeightRequestDescriptor =
    $convert.base64Decode(
        'ChtBZGp1c3RFeGVyY2lzZVdlaWdodFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya2'
        '91dElkEjAKCGV4ZXJjaXNlGAIgASgOMhQud29ya291dC52MS5FeGVyY2lzZVIIZXhlcmNpc2US'
        'JQoOd29ya2luZ193ZWlnaHQYAyABKAJSDXdvcmtpbmdXZWlnaHQ=');

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
  ],
};

/// Descriptor for `WorkoutTemplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutTemplateDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0VGVtcGxhdGUSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFA'
    'oFb3JkZXIYAyABKAVSBW9yZGVyEjIKCWV4ZXJjaXNlcxgEIAMoDjIULndvcmtvdXQudjEuRXhl'
    'cmNpc2VSCWV4ZXJjaXNlcxIdCgpjcmVhdGVkX2F0GAUgASgDUgljcmVhdGVkQXQSHQoKdXBkYX'
    'RlZF9hdBgGIAEoA1IJdXBkYXRlZEF0');

@$core.Deprecated('Use exerciseTrackerDescriptor instead')
const ExerciseTracker$json = {
  '1': 'ExerciseTracker',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'working_weight', '3': 2, '4': 1, '5': 2, '10': 'workingWeight'},
    {'1': 'sets', '3': 3, '4': 1, '5': 5, '10': 'sets'},
    {'1': 'target_reps', '3': 4, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'rep_range_low', '3': 5, '4': 1, '5': 5, '10': 'repRangeLow'},
    {'1': 'rep_range_high', '3': 6, '4': 1, '5': 5, '10': 'repRangeHigh'},
    {'1': 'rest_seconds', '3': 7, '4': 1, '5': 5, '10': 'restSeconds'},
    {
      '1': 'rest_seconds_failure',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'restSecondsFailure'
    },
    {'1': 'include_warmup', '3': 9, '4': 1, '5': 8, '10': 'includeWarmup'},
    {
      '1': 'last_performed_at',
      '3': 10,
      '4': 1,
      '5': 3,
      '10': 'lastPerformedAt'
    },
    {'1': 'weight_history', '3': 11, '4': 3, '5': 2, '10': 'weightHistory'},
    {'1': 'overridden', '3': 12, '4': 1, '5': 8, '10': 'overridden'},
    {
      '1': 'primary_muscle',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'primaryMuscle'
    },
    {
      '1': 'category',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ExerciseCategory',
      '10': 'category'
    },
    {
      '1': 'equipment',
      '3': 15,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.EquipmentKind',
      '10': 'equipment'
    },
  ],
};

/// Descriptor for `ExerciseTracker`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseTrackerDescriptor = $convert.base64Decode(
    'Cg9FeGVyY2lzZVRyYWNrZXISMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZXJjaX'
    'NlUghleGVyY2lzZRIlCg53b3JraW5nX3dlaWdodBgCIAEoAlINd29ya2luZ1dlaWdodBISCgRz'
    'ZXRzGAMgASgFUgRzZXRzEh8KC3RhcmdldF9yZXBzGAQgASgFUgp0YXJnZXRSZXBzEiIKDXJlcF'
    '9yYW5nZV9sb3cYBSABKAVSC3JlcFJhbmdlTG93EiQKDnJlcF9yYW5nZV9oaWdoGAYgASgFUgxy'
    'ZXBSYW5nZUhpZ2gSIQoMcmVzdF9zZWNvbmRzGAcgASgFUgtyZXN0U2Vjb25kcxIwChRyZXN0X3'
    'NlY29uZHNfZmFpbHVyZRgIIAEoBVIScmVzdFNlY29uZHNGYWlsdXJlEiUKDmluY2x1ZGVfd2Fy'
    'bXVwGAkgASgIUg1pbmNsdWRlV2FybXVwEioKEWxhc3RfcGVyZm9ybWVkX2F0GAogASgDUg9sYX'
    'N0UGVyZm9ybWVkQXQSJQoOd2VpZ2h0X2hpc3RvcnkYCyADKAJSDXdlaWdodEhpc3RvcnkSHgoK'
    'b3ZlcnJpZGRlbhgMIAEoCFIKb3ZlcnJpZGRlbhI+Cg5wcmltYXJ5X211c2NsZRgNIAEoDjIXLn'
    'dvcmtvdXQudjEuTXVzY2xlR3JvdXBSDXByaW1hcnlNdXNjbGUSOAoIY2F0ZWdvcnkYDiABKA4y'
    'HC53b3Jrb3V0LnYxLkV4ZXJjaXNlQ2F0ZWdvcnlSCGNhdGVnb3J5EjcKCWVxdWlwbWVudBgPIA'
    'EoDjIZLndvcmtvdXQudjEuRXF1aXBtZW50S2luZFIJZXF1aXBtZW50');

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
};

/// Descriptor for `GetHomeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeRequestDescriptor =
    $convert.base64Decode('Cg5HZXRIb21lUmVxdWVzdA==');

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
    {
      '1': 'trackers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTracker',
      '10': 'trackers'
    },
    {'1': 'active_workout_id', '3': 3, '4': 1, '5': 9, '10': 'activeWorkoutId'},
    {
      '1': 'user_messages',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserMessage',
      '10': 'userMessages'
    },
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
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'suggestionReason'
    },
    {'1': 'onboarded', '3': 9, '4': 1, '5': 8, '10': 'onboarded'},
  ],
};

/// Descriptor for `GetHomeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHomeResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRIb21lUmVzcG9uc2USOQoJdGVtcGxhdGVzGAEgAygLMhsud29ya291dC52MS5Xb3Jrb3'
    'V0VGVtcGxhdGVSCXRlbXBsYXRlcxI3Cgh0cmFja2VycxgCIAMoCzIbLndvcmtvdXQudjEuRXhl'
    'cmNpc2VUcmFja2VyUgh0cmFja2VycxIqChFhY3RpdmVfd29ya291dF9pZBgDIAEoCVIPYWN0aX'
    'ZlV29ya291dElkEjwKDXVzZXJfbWVzc2FnZXMYBCADKAsyFy53b3Jrb3V0LnYxLlVzZXJNZXNz'
    'YWdlUgx1c2VyTWVzc2FnZXMSMAoGdm9sdW1lGAUgAygLMhgud29ya291dC52MS5NdXNjbGVWb2'
    'x1bWVSBnZvbHVtZRI8CghyZWNvdmVyeRgGIAMoCzIgLndvcmtvdXQudjEuTXVzY2xlUmVjb3Zl'
    'cnlTdGF0dXNSCHJlY292ZXJ5EjIKFXN1Z2dlc3RlZF90ZW1wbGF0ZV9pZBgHIAEoCVITc3VnZ2'
    'VzdGVkVGVtcGxhdGVJZBIrChFzdWdnZXN0aW9uX3JlYXNvbhgIIAEoCVIQc3VnZ2VzdGlvblJl'
    'YXNvbhIcCglvbmJvYXJkZWQYCSABKAhSCW9uYm9hcmRlZA==');

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
  ],
};

/// Descriptor for `SaveTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveTemplateRequestDescriptor = $convert.base64Decode(
    'ChNTYXZlVGVtcGxhdGVSZXF1ZXN0EjcKCHRlbXBsYXRlGAEgASgLMhsud29ya291dC52MS5Xb3'
    'Jrb3V0VGVtcGxhdGVSCHRlbXBsYXRl');

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

@$core.Deprecated('Use setExerciseTrackerRequestDescriptor instead')
const SetExerciseTrackerRequest$json = {
  '1': 'SetExerciseTrackerRequest',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'working_weight', '3': 2, '4': 1, '5': 2, '10': 'workingWeight'},
    {'1': 'override_sets', '3': 3, '4': 1, '5': 5, '10': 'overrideSets'},
    {'1': 'override_rep_low', '3': 4, '4': 1, '5': 5, '10': 'overrideRepLow'},
    {'1': 'override_rep_high', '3': 5, '4': 1, '5': 5, '10': 'overrideRepHigh'},
  ],
};

/// Descriptor for `SetExerciseTrackerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setExerciseTrackerRequestDescriptor = $convert.base64Decode(
    'ChlTZXRFeGVyY2lzZVRyYWNrZXJSZXF1ZXN0EjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC'
    '52MS5FeGVyY2lzZVIIZXhlcmNpc2USJQoOd29ya2luZ193ZWlnaHQYAiABKAJSDXdvcmtpbmdX'
    'ZWlnaHQSIwoNb3ZlcnJpZGVfc2V0cxgDIAEoBVIMb3ZlcnJpZGVTZXRzEigKEG92ZXJyaWRlX3'
    'JlcF9sb3cYBCABKAVSDm92ZXJyaWRlUmVwTG93EioKEW92ZXJyaWRlX3JlcF9oaWdoGAUgASgF'
    'Ug9vdmVycmlkZVJlcEhpZ2g=');

@$core.Deprecated('Use setExerciseTrackerResponseDescriptor instead')
const SetExerciseTrackerResponse$json = {
  '1': 'SetExerciseTrackerResponse',
  '2': [
    {
      '1': 'tracker',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseTracker',
      '10': 'tracker'
    },
  ],
};

/// Descriptor for `SetExerciseTrackerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setExerciseTrackerResponseDescriptor =
    $convert.base64Decode(
        'ChpTZXRFeGVyY2lzZVRyYWNrZXJSZXNwb25zZRI1Cgd0cmFja2VyGAEgASgLMhsud29ya291dC'
        '52MS5FeGVyY2lzZVRyYWNrZXJSB3RyYWNrZXI=');

@$core.Deprecated('Use completeOnboardingRequestDescriptor instead')
const CompleteOnboardingRequest$json = {
  '1': 'CompleteOnboardingRequest',
  '2': [
    {'1': 'body_weight_kg', '3': 1, '4': 1, '5': 2, '10': 'bodyWeightKg'},
    {
      '1': 'experience',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ExperienceLevel',
      '10': 'experience'
    },
    {
      '1': 'unit',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WeightUnit',
      '10': 'unit'
    },
    {
      '1': 'gender',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Gender',
      '10': 'gender'
    },
  ],
};

/// Descriptor for `CompleteOnboardingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeOnboardingRequestDescriptor = $convert.base64Decode(
    'ChlDb21wbGV0ZU9uYm9hcmRpbmdSZXF1ZXN0EiQKDmJvZHlfd2VpZ2h0X2tnGAEgASgCUgxib2'
    'R5V2VpZ2h0S2cSOwoKZXhwZXJpZW5jZRgCIAEoDjIbLndvcmtvdXQudjEuRXhwZXJpZW5jZUxl'
    'dmVsUgpleHBlcmllbmNlEioKBHVuaXQYAyABKA4yFi53b3Jrb3V0LnYxLldlaWdodFVuaXRSBH'
    'VuaXQSKgoGZ2VuZGVyGAQgASgOMhIud29ya291dC52MS5HZW5kZXJSBmdlbmRlcg==');

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
  ],
  '8': [
    {'1': 'mutation'},
  ],
  '9': [
    {'1': 15, '2': 16},
    {'1': 16, '2': 17},
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
    'dWVzdEgAUgplbmRXb3Jrb3V0EkYKDWFkZF9leGVyY2lzZXMYESABKAsyHy53b3Jrb3V0LnYxLk'
    'FkZEV4ZXJjaXNlc1JlcXVlc3RIAFIMYWRkRXhlcmNpc2VzEl8KFmFkanVzdF9leGVyY2lzZV93'
    'ZWlnaHQYEiABKAsyJy53b3Jrb3V0LnYxLkFkanVzdEV4ZXJjaXNlV2VpZ2h0UmVxdWVzdEgAUh'
    'RhZGp1c3RFeGVyY2lzZVdlaWdodBJMCg9yZW1vdmVfZXhlcmNpc2UYEyABKAsyIS53b3Jrb3V0'
    'LnYxLlJlbW92ZUV4ZXJjaXNlUmVxdWVzdEgAUg5yZW1vdmVFeGVyY2lzZRJSChFyZW9yZGVyX2'
    'V4ZXJjaXNlcxgUIAEoCzIjLndvcmtvdXQudjEuUmVvcmRlckV4ZXJjaXNlc1JlcXVlc3RIAFIQ'
    'cmVvcmRlckV4ZXJjaXNlc0IKCghtdXRhdGlvbkoECA8QEEoECBAQEQ==');

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
