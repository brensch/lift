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

@$core.Deprecated('Use repsLeftDescriptor instead')
const RepsLeft$json = {
  '1': 'RepsLeft',
  '2': [
    {'1': 'REPS_LEFT_UNSPECIFIED', '2': 0},
    {'1': 'REPS_LEFT_ZERO_TO_ONE', '2': 1},
    {'1': 'REPS_LEFT_TWO_TO_FOUR', '2': 2},
    {'1': 'REPS_LEFT_FIVE_PLUS', '2': 3},
  ],
};

/// Descriptor for `RepsLeft`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List repsLeftDescriptor = $convert.base64Decode(
    'CghSZXBzTGVmdBIZChVSRVBTX0xFRlRfVU5TUEVDSUZJRUQQABIZChVSRVBTX0xFRlRfWkVST1'
    '9UT19PTkUQARIZChVSRVBTX0xFRlRfVFdPX1RPX0ZPVVIQAhIXChNSRVBTX0xFRlRfRklWRV9Q'
    'TFVTEAM=');

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
    {'1': 'PLAN_REASON_KIND_RULE', '2': 13},
    {'1': 'PLAN_REASON_KIND_DELOAD', '2': 14},
    {'1': 'PLAN_REASON_KIND_FALLBACK', '2': 15},
    {'1': 'PLAN_REASON_KIND_CYCLE_STEP', '2': 16},
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
    '5EX1JFUFNfRE9XThALEiEKHVBMQU5fUkVBU09OX0tJTkRfU0FNRV9BU19MQVNUEAwSGQoVUExB'
    'Tl9SRUFTT05fS0lORF9SVUxFEA0SGwoXUExBTl9SRUFTT05fS0lORF9ERUxPQUQQDhIdChlQTE'
    'FOX1JFQVNPTl9LSU5EX0ZBTExCQUNLEA8SHwobUExBTl9SRUFTT05fS0lORF9DWUNMRV9TVEVQ'
    'EBA=');

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

@$core.Deprecated('Use setRoleDescriptor instead')
const SetRole$json = {
  '1': 'SetRole',
  '2': [
    {'1': 'SET_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'SET_ROLE_TOP', '2': 1},
    {'1': 'SET_ROLE_BACKOFF', '2': 2},
    {'1': 'SET_ROLE_DROP', '2': 3},
    {'1': 'SET_ROLE_MINI', '2': 4},
  ],
};

/// Descriptor for `SetRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List setRoleDescriptor = $convert.base64Decode(
    'CgdTZXRSb2xlEhgKFFNFVF9ST0xFX1VOU1BFQ0lGSUVEEAASEAoMU0VUX1JPTEVfVE9QEAESFA'
    'oQU0VUX1JPTEVfQkFDS09GRhACEhEKDVNFVF9ST0xFX0RST1AQAxIRCg1TRVRfUk9MRV9NSU5J'
    'EAQ=');

@$core.Deprecated('Use measureDescriptor instead')
const Measure$json = {
  '1': 'Measure',
  '2': [
    {'1': 'MEASURE_UNSPECIFIED', '2': 0},
    {'1': 'MEASURE_SECONDS', '2': 1},
    {'1': 'MEASURE_METRES', '2': 2},
  ],
};

/// Descriptor for `Measure`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List measureDescriptor = $convert.base64Decode(
    'CgdNZWFzdXJlEhcKE01FQVNVUkVfVU5TUEVDSUZJRUQQABITCg9NRUFTVVJFX1NFQ09ORFMQAR'
    'ISCg5NRUFTVVJFX01FVFJFUxAC');

@$core.Deprecated('Use weightChangeCauseDescriptor instead')
const WeightChangeCause$json = {
  '1': 'WeightChangeCause',
  '2': [
    {'1': 'WEIGHT_CHANGE_CAUSE_UNSPECIFIED', '2': 0},
    {'1': 'WEIGHT_CHANGE_CAUSE_USER_ADJUST', '2': 1},
    {'1': 'WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP', '2': 2},
    {'1': 'WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED', '2': 3},
    {'1': 'WEIGHT_CHANGE_CAUSE_CORRECTION', '2': 4},
    {'1': 'WEIGHT_CHANGE_CAUSE_MISS', '2': 5},
  ],
};

/// Descriptor for `WeightChangeCause`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List weightChangeCauseDescriptor = $convert.base64Decode(
    'ChFXZWlnaHRDaGFuZ2VDYXVzZRIjCh9XRUlHSFRfQ0hBTkdFX0NBVVNFX1VOU1BFQ0lGSUVEEA'
    'ASIwofV0VJR0hUX0NIQU5HRV9DQVVTRV9VU0VSX0FESlVTVBABEigKJFdFSUdIVF9DSEFOR0Vf'
    'Q0FVU0VfQ0FMSUJSQVRJT05fU1RFUBACEisKJ1dFSUdIVF9DSEFOR0VfQ0FVU0VfQ0FMSUJSQV'
    'RJT05fU0VUVExFRBADEiIKHldFSUdIVF9DSEFOR0VfQ0FVU0VfQ09SUkVDVElPThAEEhwKGFdF'
    'SUdIVF9DSEFOR0VfQ0FVU0VfTUlTUxAF');

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
  ],
  '4': [
    {'1': 3, '2': 3},
    {'1': 4, '2': 4},
  ],
  '5': ['ROTATION_WARNING_KIND_LOPSIDED', 'ROTATION_WARNING_KIND_TOO_FEW'],
};

/// Descriptor for `RotationWarningKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rotationWarningKindDescriptor = $convert.base64Decode(
    'ChNSb3RhdGlvbldhcm5pbmdLaW5kEiUKIVJPVEFUSU9OX1dBUk5JTkdfS0lORF9VTlNQRUNJRk'
    'lFRBAAEh0KGVJPVEFUSU9OX1dBUk5JTkdfS0lORF9HQVAQARIhCh1ST1RBVElPTl9XQVJOSU5H'
    'X0tJTkRfT1ZFUkxBUBACIgQIAxADIgQIBBAEKh5ST1RBVElPTl9XQVJOSU5HX0tJTkRfTE9QU0'
    'lERUQqHVJPVEFUSU9OX1dBUk5JTkdfS0lORF9UT09fRkVX');

@$core.Deprecated('Use suggestionStatusDescriptor instead')
const SuggestionStatus$json = {
  '1': 'SuggestionStatus',
  '2': [
    {'1': 'SUGGESTION_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'SUGGESTION_STATUS_ACCEPTED', '2': 1},
    {'1': 'SUGGESTION_STATUS_DECLINED', '2': 2},
  ],
};

/// Descriptor for `SuggestionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List suggestionStatusDescriptor = $convert.base64Decode(
    'ChBTdWdnZXN0aW9uU3RhdHVzEiEKHVNVR0dFU1RJT05fU1RBVFVTX1VOU1BFQ0lGSUVEEAASHg'
    'oaU1VHR0VTVElPTl9TVEFUVVNfQUNDRVBURUQQARIeChpTVUdHRVNUSU9OX1NUQVRVU19ERUNM'
    'SU5FRBAC');

@$core.Deprecated('Use changeVerbDescriptor instead')
const ChangeVerb$json = {
  '1': 'ChangeVerb',
  '2': [
    {'1': 'CHANGE_VERB_UNSPECIFIED', '2': 0},
    {'1': 'CHANGE_VERB_ADD', '2': 1},
    {'1': 'CHANGE_VERB_CHANGE', '2': 2},
    {'1': 'CHANGE_VERB_REMOVE', '2': 3},
  ],
};

/// Descriptor for `ChangeVerb`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List changeVerbDescriptor = $convert.base64Decode(
    'CgpDaGFuZ2VWZXJiEhsKF0NIQU5HRV9WRVJCX1VOU1BFQ0lGSUVEEAASEwoPQ0hBTkdFX1ZFUk'
    'JfQUREEAESFgoSQ0hBTkdFX1ZFUkJfQ0hBTkdFEAISFgoSQ0hBTkdFX1ZFUkJfUkVNT1ZFEAM=');

@$core.Deprecated('Use changeSubjectDescriptor instead')
const ChangeSubject$json = {
  '1': 'ChangeSubject',
  '2': [
    {'1': 'CHANGE_SUBJECT_UNSPECIFIED', '2': 0},
    {'1': 'CHANGE_SUBJECT_WORKOUT', '2': 1},
    {'1': 'CHANGE_SUBJECT_EXERCISE', '2': 2},
    {'1': 'CHANGE_SUBJECT_SCHEME', '2': 3},
    {'1': 'CHANGE_SUBJECT_PROGRESSION', '2': 4},
    {'1': 'CHANGE_SUBJECT_CLASS', '2': 5},
  ],
};

/// Descriptor for `ChangeSubject`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List changeSubjectDescriptor = $convert.base64Decode(
    'Cg1DaGFuZ2VTdWJqZWN0Eh4KGkNIQU5HRV9TVUJKRUNUX1VOU1BFQ0lGSUVEEAASGgoWQ0hBTk'
    'dFX1NVQkpFQ1RfV09SS09VVBABEhsKF0NIQU5HRV9TVUJKRUNUX0VYRVJDSVNFEAISGQoVQ0hB'
    'TkdFX1NVQkpFQ1RfU0NIRU1FEAMSHgoaQ0hBTkdFX1NVQkpFQ1RfUFJPR1JFU1NJT04QBBIYCh'
    'RDSEFOR0VfU1VCSkVDVF9DTEFTUxAF');

@$core.Deprecated('Use simulatedEffortDescriptor instead')
const SimulatedEffort$json = {
  '1': 'SimulatedEffort',
  '2': [
    {'1': 'SIMULATED_EFFORT_UNSPECIFIED', '2': 0},
    {'1': 'SIMULATED_EFFORT_ALL_HIT', '2': 1},
    {'1': 'SIMULATED_EFFORT_LAST_SET_SHORT', '2': 2},
    {'1': 'SIMULATED_EFFORT_ALL_SHORT', '2': 3},
    {'1': 'SIMULATED_EFFORT_MISS_EVERY', '2': 4},
  ],
};

/// Descriptor for `SimulatedEffort`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List simulatedEffortDescriptor = $convert.base64Decode(
    'Cg9TaW11bGF0ZWRFZmZvcnQSIAocU0lNVUxBVEVEX0VGRk9SVF9VTlNQRUNJRklFRBAAEhwKGF'
    'NJTVVMQVRFRF9FRkZPUlRfQUxMX0hJVBABEiMKH1NJTVVMQVRFRF9FRkZPUlRfTEFTVF9TRVRf'
    'U0hPUlQQAhIeChpTSU1VTEFURURfRUZGT1JUX0FMTF9TSE9SVBADEh8KG1NJTVVMQVRFRF9FRk'
    'ZPUlRfTUlTU19FVkVSWRAE');

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
    {'1': 'motivation', '3': 9, '4': 1, '5': 9, '10': 'motivation'},
  ],
};

/// Descriptor for `Workout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDescriptor = $convert.base64Decode(
    'CgdXb3Jrb3V0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YXJ0X3'
    'RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZRIdCgpzZXNz'
    'aW9uX2lkGAUgASgJUglzZXNzaW9uSWQSHwoLdGVtcGxhdGVfaWQYBiABKAlSCnRlbXBsYXRlSW'
    'QSJAoObGlmdGluZ19zZXRfaWQYByABKAlSDGxpZnRpbmdTZXRJZBIsChJsaWZ0aW5nX3N0YXJ0'
    'ZWRfYXQYCCABKANSEGxpZnRpbmdTdGFydGVkQXQSHgoKbW90aXZhdGlvbhgJIAEoCVIKbW90aX'
    'ZhdGlvbg==');

@$core.Deprecated('Use proposedSetDescriptor instead')
const ProposedSet$json = {
  '1': 'ProposedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'workout_order', '3': 3, '4': 1, '5': 5, '10': 'workoutOrder'},
    {'1': 'exercise', '3': 17, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'target_reps', '3': 5, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'target_weight', '3': 6, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'warmup', '3': 7, '4': 1, '5': 8, '10': 'warmup'},
    {'1': 'rest_seconds', '3': 9, '4': 1, '5': 5, '10': 'restSeconds'},
    {'1': 'cancelled', '3': 11, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'calibration', '3': 15, '4': 1, '5': 8, '10': 'calibration'},
    {'1': 'skipped', '3': 16, '4': 1, '5': 8, '10': 'skipped'},
    {
      '1': 'role',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SetRole',
      '10': 'role'
    },
    {'1': 'amrap', '3': 19, '4': 1, '5': 8, '10': 'amrap'},
    {
      '1': 'target_rir',
      '3': 20,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'targetRir',
      '17': true
    },
    {
      '1': 'measure',
      '3': 21,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Measure',
      '10': 'measure'
    },
    {'1': 'per_side', '3': 22, '4': 1, '5': 8, '10': 'perSide'},
    {'1': 'tempo', '3': 23, '4': 1, '5': 9, '10': 'tempo'},
    {'1': 'group', '3': 24, '4': 1, '5': 9, '10': 'group'},
    {'1': 'every_seconds', '3': 25, '4': 1, '5': 5, '10': 'everySeconds'},
    {'1': 'fraction', '3': 26, '4': 1, '5': 2, '10': 'fraction'},
    {
      '1': 'on_miss',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.OnMiss',
      '10': 'onMiss'
    },
    {'1': 'miss_from', '3': 28, '4': 1, '5': 9, '10': 'missFrom'},
    {
      '1': 'weight_before_miss',
      '3': 29,
      '4': 1,
      '5': 2,
      '10': 'weightBeforeMiss'
    },
  ],
  '8': [
    {'1': '_target_rir'},
  ],
  '9': [
    {'1': 8, '2': 9},
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 13, '2': 14},
    {'1': 14, '2': 15},
    {'1': 4, '2': 5},
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
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIaCghleGVyY2lzZRgR'
    'IAEoCVIIZXhlcmNpc2USHwoLdGFyZ2V0X3JlcHMYBSABKAVSCnRhcmdldFJlcHMSIwoNdGFyZ2'
    'V0X3dlaWdodBgGIAEoAlIMdGFyZ2V0V2VpZ2h0EhYKBndhcm11cBgHIAEoCFIGd2FybXVwEiEK'
    'DHJlc3Rfc2Vjb25kcxgJIAEoBVILcmVzdFNlY29uZHMSHAoJY2FuY2VsbGVkGAsgASgIUgljYW'
    '5jZWxsZWQSIAoLY2FsaWJyYXRpb24YDyABKAhSC2NhbGlicmF0aW9uEhgKB3NraXBwZWQYECAB'
    'KAhSB3NraXBwZWQSJwoEcm9sZRgSIAEoDjITLndvcmtvdXQudjEuU2V0Um9sZVIEcm9sZRIUCg'
    'VhbXJhcBgTIAEoCFIFYW1yYXASIgoKdGFyZ2V0X3JpchgUIAEoBUgAUgl0YXJnZXRSaXKIAQES'
    'LQoHbWVhc3VyZRgVIAEoDjITLndvcmtvdXQudjEuTWVhc3VyZVIHbWVhc3VyZRIZCghwZXJfc2'
    'lkZRgWIAEoCFIHcGVyU2lkZRIUCgV0ZW1wbxgXIAEoCVIFdGVtcG8SFAoFZ3JvdXAYGCABKAlS'
    'BWdyb3VwEiMKDWV2ZXJ5X3NlY29uZHMYGSABKAVSDGV2ZXJ5U2Vjb25kcxIaCghmcmFjdGlvbh'
    'gaIAEoAlIIZnJhY3Rpb24SKwoHb25fbWlzcxgbIAEoCzISLndvcmtvdXQudjEuT25NaXNzUgZv'
    'bk1pc3MSGwoJbWlzc19mcm9tGBwgASgJUghtaXNzRnJvbRIsChJ3ZWlnaHRfYmVmb3JlX21pc3'
    'MYHSABKAJSEHdlaWdodEJlZm9yZU1pc3NCDQoLX3RhcmdldF9yaXJKBAgIEAlKBAgKEAtKBAgM'
    'EA1KBAgNEA5KBAgOEA9KBAgEEAVSEWV4ZXJjaXNlX2dyb3VwX2lkUghpc19hbXJhcFILaW5zdH'
    'J1Y3Rpb25SEHByb2dyZXNzaW9uX2hpbnRSEnJlc3RfYWZ0ZXJfc3VjY2Vzc1IScmVzdF9hZnRl'
    'cl9mYWlsdXJl');

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
    {
      '1': 'reps_left',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RepsLeft',
      '10': 'repsLeft'
    },
    {'1': 'jump_lb', '3': 13, '4': 1, '5': 2, '10': 'jumpLb'},
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
    'c3RVbnRpbBIdCgpzdGFydGVkX2F0GAsgASgDUglzdGFydGVkQXQSMQoJcmVwc19sZWZ0GAwgAS'
    'gOMhQud29ya291dC52MS5SZXBzTGVmdFIIcmVwc0xlZnQSFwoHanVtcF9sYhgNIAEoAlIGanVt'
    'cExiSgQIBhAHSgQICRAKSgQIChALUgxyZXN0X3NraXBwZWRSBmVmZm9ydA==');

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
    {'1': 'rule', '3': 16, '4': 1, '5': 9, '10': 'rule'},
    {'1': 'text', '3': 17, '4': 1, '5': 9, '10': 'text'},
    {'1': 'count', '3': 18, '4': 1, '5': 5, '10': 'count'},
    {'1': 'of', '3': 19, '4': 1, '5': 5, '10': 'of'},
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
    'Z0ZXISEgoEcnVsZRgQIAEoCVIEcnVsZRISCgR0ZXh0GBEgASgJUgR0ZXh0EhQKBWNvdW50GBIg'
    'ASgFUgVjb3VudBIOCgJvZhgTIAEoBVICb2Y=');

@$core.Deprecated('Use plannedSetDescriptor instead')
const PlannedSet$json = {
  '1': 'PlannedSet',
  '2': [
    {
      '1': 'role',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SetRole',
      '10': 'role'
    },
    {'1': 'reps', '3': 2, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'fraction', '3': 3, '4': 1, '5': 2, '10': 'fraction'},
    {'1': 'amrap', '3': 4, '4': 1, '5': 8, '10': 'amrap'},
    {'1': 'rir', '3': 5, '4': 1, '5': 5, '9': 0, '10': 'rir', '17': true},
    {'1': 'rest_seconds', '3': 6, '4': 1, '5': 5, '10': 'restSeconds'},
    {'1': 'every_seconds', '3': 7, '4': 1, '5': 5, '10': 'everySeconds'},
    {
      '1': 'on_miss',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.OnMiss',
      '10': 'onMiss'
    },
  ],
  '8': [
    {'1': '_rir'},
  ],
};

/// Descriptor for `PlannedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plannedSetDescriptor = $convert.base64Decode(
    'CgpQbGFubmVkU2V0EicKBHJvbGUYASABKA4yEy53b3Jrb3V0LnYxLlNldFJvbGVSBHJvbGUSEg'
    'oEcmVwcxgCIAEoBVIEcmVwcxIaCghmcmFjdGlvbhgDIAEoAlIIZnJhY3Rpb24SFAoFYW1yYXAY'
    'BCABKAhSBWFtcmFwEhUKA3JpchgFIAEoBUgAUgNyaXKIAQESIQoMcmVzdF9zZWNvbmRzGAYgAS'
    'gFUgtyZXN0U2Vjb25kcxIjCg1ldmVyeV9zZWNvbmRzGAcgASgFUgxldmVyeVNlY29uZHMSKwoH'
    'b25fbWlzcxgIIAEoCzISLndvcmtvdXQudjEuT25NaXNzUgZvbk1pc3NCBgoEX3Jpcg==');

@$core.Deprecated('Use onMissDescriptor instead')
const OnMiss$json = {
  '1': 'OnMiss',
  '2': [
    {'1': 'rest_seconds', '3': 1, '4': 1, '5': 5, '10': 'restSeconds'},
    {'1': 'fraction', '3': 2, '4': 1, '5': 2, '10': 'fraction'},
    {'1': 'stop', '3': 3, '4': 1, '5': 8, '10': 'stop'},
  ],
};

/// Descriptor for `OnMiss`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onMissDescriptor = $convert.base64Decode(
    'CgZPbk1pc3MSIQoMcmVzdF9zZWNvbmRzGAEgASgFUgtyZXN0U2Vjb25kcxIaCghmcmFjdGlvbh'
    'gCIAEoAlIIZnJhY3Rpb24SEgoEc3RvcBgDIAEoCFIEc3RvcA==');

@$core.Deprecated('Use exerciseDecisionDescriptor instead')
const ExerciseDecision$json = {
  '1': 'ExerciseDecision',
  '2': [
    {'1': 'exercise', '3': 14, '4': 1, '5': 9, '10': 'exercise'},
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
    {'1': 'progression', '3': 15, '4': 1, '5': 9, '10': 'progression'},
    {'1': 'progression_kind', '3': 16, '4': 1, '5': 9, '10': 'progressionKind'},
    {
      '1': 'scheme_sets',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PlannedSet',
      '10': 'schemeSets'
    },
    {
      '1': 'measure',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Measure',
      '10': 'measure'
    },
    {'1': 'per_side', '3': 19, '4': 1, '5': 8, '10': 'perSide'},
    {'1': 'tempo', '3': 20, '4': 1, '5': 9, '10': 'tempo'},
    {'1': 'group', '3': 21, '4': 1, '5': 9, '10': 'group'},
    {'1': 'scheme', '3': 22, '4': 1, '5': 9, '10': 'scheme'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `ExerciseDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseDecisionDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZURlY2lzaW9uEhoKCGV4ZXJjaXNlGA4gASgJUghleGVyY2lzZRISCgRzZXRzGA'
    'IgASgFUgRzZXRzEhIKBHJlcHMYAyABKAVSBHJlcHMSFgoGd2VpZ2h0GAQgASgCUgZ3ZWlnaHQS'
    'IQoMcmVzdF9zZWNvbmRzGAUgASgFUgtyZXN0U2Vjb25kcxIYCgd3YXJtdXBzGAYgASgIUgd3YX'
    'JtdXBzEhcKB3JlcF9sb3cYByABKAVSBnJlcExvdxIZCghyZXBfaGlnaBgIIAEoBVIHcmVwSGln'
    'aBIQCgNtYXgYCSABKAJSA21heBIgCgtjYWxpYnJhdGlvbhgKIAEoCFILY2FsaWJyYXRpb24SJQ'
    'oOYnVkZ2V0X21pbnV0ZXMYCyABKAVSDWJ1ZGdldE1pbnV0ZXMSKwoRZXN0aW1hdGVkX3NlY29u'
    'ZHMYDCABKAVSEGVzdGltYXRlZFNlY29uZHMSMAoHcmVhc29ucxgNIAMoCzIWLndvcmtvdXQudj'
    'EuUGxhblJlYXNvblIHcmVhc29ucxIgCgtwcm9ncmVzc2lvbhgPIAEoCVILcHJvZ3Jlc3Npb24S'
    'KQoQcHJvZ3Jlc3Npb25fa2luZBgQIAEoCVIPcHJvZ3Jlc3Npb25LaW5kEjcKC3NjaGVtZV9zZX'
    'RzGBEgAygLMhYud29ya291dC52MS5QbGFubmVkU2V0UgpzY2hlbWVTZXRzEi0KB21lYXN1cmUY'
    'EiABKA4yEy53b3Jrb3V0LnYxLk1lYXN1cmVSB21lYXN1cmUSGQoIcGVyX3NpZGUYEyABKAhSB3'
    'BlclNpZGUSFAoFdGVtcG8YFCABKAlSBXRlbXBvEhQKBWdyb3VwGBUgASgJUgVncm91cBIWCgZz'
    'Y2hlbWUYFiABKAlSBnNjaGVtZUoECAEQAg==');

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
    {'1': 'step', '3': 7, '4': 1, '5': 2, '10': 'step'},
  ],
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['secondary_muscles'],
};

/// Descriptor for `ExercisePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exercisePlanDescriptor = $convert.base64Decode(
    'CgxFeGVyY2lzZVBsYW4SOAoIZGVjaXNpb24YASABKAsyHC53b3Jrb3V0LnYxLkV4ZXJjaXNlRG'
    'VjaXNpb25SCGRlY2lzaW9uEh4KCm92ZXJyaWRkZW4YAiABKAhSCm92ZXJyaWRkZW4SPgoOcHJp'
    'bWFyeV9tdXNjbGUYAyABKA4yFy53b3Jrb3V0LnYxLk11c2NsZUdyb3VwUg1wcmltYXJ5TXVzY2'
    'xlEjcKCWVxdWlwbWVudBgEIAEoDjIZLndvcmtvdXQudjEuRXF1aXBtZW50S2luZFIJZXF1aXBt'
    'ZW50EioKEWxhc3RfcGVyZm9ybWVkX2F0GAUgASgDUg9sYXN0UGVyZm9ybWVkQXQSEgoEc3RlcB'
    'gHIAEoAlIEc3RlcEoECAYQB1IRc2Vjb25kYXJ5X211c2NsZXM=');

@$core.Deprecated('Use startWorkoutRequestDescriptor instead')
const StartWorkoutRequest$json = {
  '1': 'StartWorkoutRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'template_id', '3': 4, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'exercises', '3': 9, '4': 3, '5': 9, '10': 'exercises'},
    {'1': 'budget_minutes', '3': 7, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {'1': 'motivation', '3': 8, '4': 1, '5': 9, '10': 'motivation'},
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 5, '2': 6},
    {'1': 6, '2': 7},
  ],
  '10': ['exercise_groups', 'decisions'],
};

/// Descriptor for `StartWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFdvcmtvdXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSHQoKc3RhcnRlZF9hdB'
    'gDIAEoA1IJc3RhcnRlZEF0Eh8KC3RlbXBsYXRlX2lkGAQgASgJUgp0ZW1wbGF0ZUlkEhwKCWV4'
    'ZXJjaXNlcxgJIAMoCVIJZXhlcmNpc2VzEiUKDmJ1ZGdldF9taW51dGVzGAcgASgFUg1idWRnZX'
    'RNaW51dGVzEh4KCm1vdGl2YXRpb24YCCABKAlSCm1vdGl2YXRpb25KBAgCEANKBAgFEAZKBAgG'
    'EAdSD2V4ZXJjaXNlX2dyb3Vwc1IJZGVjaXNpb25z');

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
    {
      '1': 'exercises',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseInfo',
      '10': 'exercises'
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
    '9nUgxleGVyY2lzZUxvZ3MSNgoJZXhlcmNpc2VzGAogAygLMhgud29ya291dC52MS5FeGVyY2lz'
    'ZUluZm9SCWV4ZXJjaXNlc0oECAMQBEoECAgQCVIPZXhlcmNpc2VfZ3JvdXBzUg11c2VyX21lc3'
    'NhZ2Vz');

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
    {'1': 'exercise', '3': 8, '4': 1, '5': 9, '10': 'exercise'},
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
    {
      '1': 'estimated_max_after',
      '3': 7,
      '4': 1,
      '5': 2,
      '10': 'estimatedMaxAfter'
    },
    {'1': 'name', '3': 9, '4': 1, '5': 9, '10': 'name'},
  ],
  '9': [
    {'1': 5, '2': 6},
    {'1': 1, '2': 2},
  ],
  '10': ['best_one_rep_max'],
};

/// Descriptor for `ExerciseSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseSummaryDescriptor = $convert.base64Decode(
    'Cg9FeGVyY2lzZVN1bW1hcnkSGgoIZXhlcmNpc2UYCCABKAlSCGV4ZXJjaXNlEh0KCnRvdGFsX3'
    'NldHMYAiABKAVSCXRvdGFsU2V0cxIdCgp0b3RhbF9yZXBzGAMgASgFUgl0b3RhbFJlcHMSIQoM'
    'dG90YWxfdm9sdW1lGAQgASgCUgt0b3RhbFZvbHVtZRIuChNoZWF2aWVzdF9zZXRfd2VpZ2h0GA'
    'YgASgCUhFoZWF2aWVzdFNldFdlaWdodBIuChNlc3RpbWF0ZWRfbWF4X2FmdGVyGAcgASgCUhFl'
    'c3RpbWF0ZWRNYXhBZnRlchISCgRuYW1lGAkgASgJUgRuYW1lSgQIBRAGSgQIARACUhBiZXN0X2'
    '9uZV9yZXBfbWF4');

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
      '1': 'rung_question_set_id',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'rungQuestionSetId'
    },
    {
      '1': 'passed_warmup_ids',
      '3': 10,
      '4': 3,
      '5': 9,
      '10': 'passedWarmupIds'
    },
    {
      '1': 'first_time_set_ids',
      '3': 14,
      '4': 3,
      '5': 9,
      '10': 'firstTimeSetIds'
    },
    {
      '1': 'exercise_logs',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseLog',
      '10': 'exerciseLogs'
    },
    {
      '1': 'exercises',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseInfo',
      '10': 'exercises'
    },
    {
      '1': 'effort_question_set_id',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'effortQuestionSetId'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 6, '2': 7},
    {'1': 8, '2': 9},
    {'1': 13, '2': 14},
  ],
  '10': [
    'exercise_groups',
    'plan_change_stats',
    'user_messages',
    'rung_outcomes'
  ],
};

/// Descriptor for `GetWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJHZXRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAMgAygLMhcud29ya291dC52MS5Qcm9wb3Nl'
    'ZFNldFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAQgAygLMhgud29ya291dC52MS'
    '5Db21wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSNwoLbmV4dF91cF9zZXQYBSABKAsyFy53b3Jr'
    'b3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdGVfc25hcHNob3QYByABKAsyIC'
    '53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0ZVNuYXBzaG90EjQKB3N1bW1h'
    'cnkYCSABKAsyGi53b3Jrb3V0LnYxLldvcmtvdXRTdW1tYXJ5UgdzdW1tYXJ5Ei8KFHJ1bmdfcX'
    'Vlc3Rpb25fc2V0X2lkGAwgASgJUhFydW5nUXVlc3Rpb25TZXRJZBIqChFwYXNzZWRfd2FybXVw'
    'X2lkcxgKIAMoCVIPcGFzc2VkV2FybXVwSWRzEisKEmZpcnN0X3RpbWVfc2V0X2lkcxgOIAMoCV'
    'IPZmlyc3RUaW1lU2V0SWRzEjwKDWV4ZXJjaXNlX2xvZ3MYCyADKAsyFy53b3Jrb3V0LnYxLkV4'
    'ZXJjaXNlTG9nUgxleGVyY2lzZUxvZ3MSNgoJZXhlcmNpc2VzGA8gAygLMhgud29ya291dC52MS'
    '5FeGVyY2lzZUluZm9SCWV4ZXJjaXNlcxIzChZlZmZvcnRfcXVlc3Rpb25fc2V0X2lkGBAgASgJ'
    'UhNlZmZvcnRRdWVzdGlvblNldElkSgQIAhADSgQIBhAHSgQICBAJSgQIDRAOUg9leGVyY2lzZV'
    '9ncm91cHNSEXBsYW5fY2hhbmdlX3N0YXRzUg11c2VyX21lc3NhZ2VzUg1ydW5nX291dGNvbWVz');

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
    {'1': 'exercise', '3': 4, '4': 1, '5': 9, '10': 'exercise'},
    {
      '1': 'points',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseProgressPoint',
      '10': 'points'
    },
    {'1': 'bodyweight', '3': 3, '4': 1, '5': 8, '10': 'bodyweight'},
    {'1': 'name', '3': 5, '4': 1, '5': 9, '10': 'name'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `ExerciseProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseProgressDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZVByb2dyZXNzEhoKCGV4ZXJjaXNlGAQgASgJUghleGVyY2lzZRI5CgZwb2ludH'
    'MYAiADKAsyIS53b3Jrb3V0LnYxLkV4ZXJjaXNlUHJvZ3Jlc3NQb2ludFIGcG9pbnRzEh4KCmJv'
    'ZHl3ZWlnaHQYAyABKAhSCmJvZHl3ZWlnaHQSEgoEbmFtZRgFIAEoCVIEbmFtZUoECAEQAg==');

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

@$core.Deprecated('Use addExercisesRequestDescriptor instead')
const AddExercisesRequest$json = {
  '1': 'AddExercisesRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercises', '3': 5, '4': 3, '5': 9, '10': 'exercises'},
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 3, '2': 4},
    {'1': 2, '2': 3},
  ],
  '10': ['decisions', 'client_working_set_ids'],
};

/// Descriptor for `AddExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addExercisesRequestDescriptor = $convert.base64Decode(
    'ChNBZGRFeGVyY2lzZXNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIcCg'
    'lleGVyY2lzZXMYBSADKAlSCWV4ZXJjaXNlc0oECAQQBUoECAMQBEoECAIQA1IJZGVjaXNpb25z'
    'UhZjbGllbnRfd29ya2luZ19zZXRfaWRz');

@$core.Deprecated('Use adjustExerciseWeightRequestDescriptor instead')
const AdjustExerciseWeightRequest$json = {
  '1': 'AdjustExerciseWeightRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise', '3': 6, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'working_weight', '3': 3, '4': 1, '5': 2, '10': 'workingWeight'},
    {'1': 'target_reps', '3': 4, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'sets', '3': 5, '4': 1, '5': 5, '10': 'sets'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `AdjustExerciseWeightRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adjustExerciseWeightRequestDescriptor = $convert.base64Decode(
    'ChtBZGp1c3RFeGVyY2lzZVdlaWdodFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya2'
    '91dElkEhoKCGV4ZXJjaXNlGAYgASgJUghleGVyY2lzZRIlCg53b3JraW5nX3dlaWdodBgDIAEo'
    'AlINd29ya2luZ1dlaWdodBIfCgt0YXJnZXRfcmVwcxgEIAEoBVIKdGFyZ2V0UmVwcxISCgRzZX'
    'RzGAUgASgFUgRzZXRzSgQIAhAD');

@$core.Deprecated('Use removeExerciseRequestDescriptor instead')
const RemoveExerciseRequest$json = {
  '1': 'RemoveExerciseRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise', '3': 3, '4': 1, '5': 9, '10': 'exercise'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `RemoveExerciseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeExerciseRequestDescriptor = $convert.base64Decode(
    'ChVSZW1vdmVFeGVyY2lzZVJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEh'
    'oKCGV4ZXJjaXNlGAMgASgJUghleGVyY2lzZUoECAIQAw==');

@$core.Deprecated('Use reorderExercisesRequestDescriptor instead')
const ReorderExercisesRequest$json = {
  '1': 'ReorderExercisesRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercises', '3': 3, '4': 3, '5': 9, '10': 'exercises'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `ReorderExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExercisesRequestDescriptor =
    $convert.base64Decode(
        'ChdSZW9yZGVyRXhlcmNpc2VzUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SW'
        'QSHAoJZXhlcmNpc2VzGAMgAygJUglleGVyY2lzZXNKBAgCEAM=');

@$core.Deprecated('Use skipWarmupsRequestDescriptor instead')
const SkipWarmupsRequest$json = {
  '1': 'SkipWarmupsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise', '3': 4, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'proposed_set_id', '3': 3, '4': 1, '5': 9, '10': 'proposedSetId'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `SkipWarmupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skipWarmupsRequestDescriptor = $convert.base64Decode(
    'ChJTa2lwV2FybXVwc1JlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEhoKCG'
    'V4ZXJjaXNlGAQgASgJUghleGVyY2lzZRImCg9wcm9wb3NlZF9zZXRfaWQYAyABKAlSDXByb3Bv'
    'c2VkU2V0SWRKBAgCEAM=');

@$core.Deprecated('Use answerRungRequestDescriptor instead')
const AnswerRungRequest$json = {
  '1': 'AnswerRungRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {
      '1': 'reps_left',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RepsLeft',
      '10': 'repsLeft'
    },
    {'1': 'jump_lb', '3': 4, '4': 1, '5': 2, '10': 'jumpLb'},
  ],
};

/// Descriptor for `AnswerRungRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerRungRequestDescriptor = $convert.base64Decode(
    'ChFBbnN3ZXJSdW5nUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSJgoPcH'
    'JvcG9zZWRfc2V0X2lkGAIgASgJUg1wcm9wb3NlZFNldElkEjEKCXJlcHNfbGVmdBgDIAEoDjIU'
    'LndvcmtvdXQudjEuUmVwc0xlZnRSCHJlcHNMZWZ0EhcKB2p1bXBfbGIYBCABKAJSBmp1bXBMYg'
    '==');

@$core.Deprecated('Use answerEffortRequestDescriptor instead')
const AnswerEffortRequest$json = {
  '1': 'AnswerEffortRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {
      '1': 'reps_left',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RepsLeft',
      '10': 'repsLeft'
    },
  ],
};

/// Descriptor for `AnswerEffortRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerEffortRequestDescriptor = $convert.base64Decode(
    'ChNBbnN3ZXJFZmZvcnRSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBImCg'
    '9wcm9wb3NlZF9zZXRfaWQYAiABKAlSDXByb3Bvc2VkU2V0SWQSMQoJcmVwc19sZWZ0GAMgASgO'
    'MhQud29ya291dC52MS5SZXBzTGVmdFIIcmVwc0xlZnQ=');

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

@$core.Deprecated('Use discardWorkoutRequestDescriptor instead')
const DiscardWorkoutRequest$json = {
  '1': 'DiscardWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `DiscardWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discardWorkoutRequestDescriptor = $convert.base64Decode(
    'ChVEaXNjYXJkV29ya291dFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElk');

@$core.Deprecated('Use discardWorkoutResponseDescriptor instead')
const DiscardWorkoutResponse$json = {
  '1': 'DiscardWorkoutResponse',
};

/// Descriptor for `DiscardWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discardWorkoutResponseDescriptor =
    $convert.base64Decode('ChZEaXNjYXJkV29ya291dFJlc3BvbnNl');

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
      '1': 'template_offer',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TemplateOffer',
      '10': 'templateOffer'
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
    '91dFIHd29ya291dBJACg50ZW1wbGF0ZV9vZmZlchgDIAEoCzIZLndvcmtvdXQudjEuVGVtcGxh'
    'dGVPZmZlclINdGVtcGxhdGVPZmZlckoECAIQA1INdXNlcl9tZXNzYWdlcw==');

@$core.Deprecated('Use templateOfferDescriptor instead')
const TemplateOffer$json = {
  '1': 'TemplateOffer',
  '2': [
    {'1': 'template_id', '3': 1, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'template_name', '3': 2, '4': 1, '5': 9, '10': 'templateName'},
    {'1': 'exercises', '3': 4, '4': 3, '5': 9, '10': 'exercises'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `TemplateOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List templateOfferDescriptor = $convert.base64Decode(
    'Cg1UZW1wbGF0ZU9mZmVyEh8KC3RlbXBsYXRlX2lkGAEgASgJUgp0ZW1wbGF0ZUlkEiMKDXRlbX'
    'BsYXRlX25hbWUYAiABKAlSDHRlbXBsYXRlTmFtZRIcCglleGVyY2lzZXMYBCADKAlSCWV4ZXJj'
    'aXNlc0oECAMQBA==');

@$core.Deprecated('Use workoutTemplateDescriptor instead')
const WorkoutTemplate$json = {
  '1': 'WorkoutTemplate',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'exercises', '3': 11, '4': 3, '5': 9, '10': 'exercises'},
    {'1': 'in_rotation', '3': 9, '4': 1, '5': 8, '10': 'inRotation'},
    {
      '1': 'origin_library_id',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'originLibraryId'
    },
    {'1': 'notes', '3': 12, '4': 1, '5': 9, '10': 'notes'},
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 3, '2': 4},
    {'1': 5, '2': 6},
    {'1': 6, '2': 7},
    {'1': 7, '2': 8},
    {'1': 8, '2': 9},
  ],
  '10': ['order', 'created_at', 'updated_at', 'library_id', 'coupled'],
};

/// Descriptor for `WorkoutTemplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutTemplateDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0VGVtcGxhdGUSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHA'
    'oJZXhlcmNpc2VzGAsgAygJUglleGVyY2lzZXMSHwoLaW5fcm90YXRpb24YCSABKAhSCmluUm90'
    'YXRpb24SKgoRb3JpZ2luX2xpYnJhcnlfaWQYCiABKAlSD29yaWdpbkxpYnJhcnlJZBIUCgVub3'
    'RlcxgMIAEoCVIFbm90ZXNKBAgEEAVKBAgDEARKBAgFEAZKBAgGEAdKBAgHEAhKBAgIEAlSBW9y'
    'ZGVyUgpjcmVhdGVkX2F0Ugp1cGRhdGVkX2F0UgpsaWJyYXJ5X2lkUgdjb3VwbGVk');

@$core.Deprecated('Use libraryTemplateDescriptor instead')
const LibraryTemplate$json = {
  '1': 'LibraryTemplate',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'blurb', '3': 3, '4': 1, '5': 9, '10': 'blurb'},
    {'1': 'group_label', '3': 5, '4': 1, '5': 9, '10': 'groupLabel'},
    {'1': 'exercises', '3': 8, '4': 3, '5': 9, '10': 'exercises'},
    {'1': 'is_default', '3': 7, '4': 1, '5': 8, '10': 'isDefault'},
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 6, '2': 7},
  ],
  '10': ['group_key'],
};

/// Descriptor for `LibraryTemplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List libraryTemplateDescriptor = $convert.base64Decode(
    'Cg9MaWJyYXJ5VGVtcGxhdGUSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFA'
    'oFYmx1cmIYAyABKAlSBWJsdXJiEh8KC2dyb3VwX2xhYmVsGAUgASgJUgpncm91cExhYmVsEhwK'
    'CWV4ZXJjaXNlcxgIIAMoCVIJZXhlcmNpc2VzEh0KCmlzX2RlZmF1bHQYByABKAhSCWlzRGVmYX'
    'VsdEoECAQQBUoECAYQB1IJZ3JvdXBfa2V5');

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
    {
      '1': 'plans',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.LibraryPlan',
      '10': 'plans'
    },
  ],
};

/// Descriptor for `ListTemplateLibraryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTemplateLibraryResponseDescriptor =
    $convert.base64Decode(
        'ChtMaXN0VGVtcGxhdGVMaWJyYXJ5UmVzcG9uc2USOQoJdGVtcGxhdGVzGAEgAygLMhsud29ya2'
        '91dC52MS5MaWJyYXJ5VGVtcGxhdGVSCXRlbXBsYXRlcxItCgVwbGFucxgCIAMoCzIXLndvcmtv'
        'dXQudjEuTGlicmFyeVBsYW5SBXBsYW5z');

@$core.Deprecated('Use libraryPlanDescriptor instead')
const LibraryPlan$json = {
  '1': 'LibraryPlan',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'blurb', '3': 3, '4': 1, '5': 9, '10': 'blurb'},
    {'1': 'library_ids', '3': 4, '4': 3, '5': 9, '10': 'libraryIds'},
  ],
};

/// Descriptor for `LibraryPlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List libraryPlanDescriptor = $convert.base64Decode(
    'CgtMaWJyYXJ5UGxhbhIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIUCgVibH'
    'VyYhgDIAEoCVIFYmx1cmISHwoLbGlicmFyeV9pZHMYBCADKAlSCmxpYnJhcnlJZHM=');

@$core.Deprecated('Use applyLibraryPlanRequestDescriptor instead')
const ApplyLibraryPlanRequest$json = {
  '1': 'ApplyLibraryPlanRequest',
  '2': [
    {'1': 'plan_id', '3': 1, '4': 1, '5': 9, '10': 'planId'},
  ],
};

/// Descriptor for `ApplyLibraryPlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List applyLibraryPlanRequestDescriptor =
    $convert.base64Decode(
        'ChdBcHBseUxpYnJhcnlQbGFuUmVxdWVzdBIXCgdwbGFuX2lkGAEgASgJUgZwbGFuSWQ=');

@$core.Deprecated('Use applyLibraryPlanResponseDescriptor instead')
const ApplyLibraryPlanResponse$json = {
  '1': 'ApplyLibraryPlanResponse',
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['home'],
};

/// Descriptor for `ApplyLibraryPlanResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List applyLibraryPlanResponseDescriptor = $convert
    .base64Decode('ChhBcHBseUxpYnJhcnlQbGFuUmVzcG9uc2VKBAgBEAJSBGhvbWU=');

@$core.Deprecated('Use addLibraryTemplatesRequestDescriptor instead')
const AddLibraryTemplatesRequest$json = {
  '1': 'AddLibraryTemplatesRequest',
  '2': [
    {'1': 'library_ids', '3': 1, '4': 3, '5': 9, '10': 'libraryIds'},
    {'1': 'in_rotation', '3': 3, '4': 1, '5': 8, '10': 'inRotation'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['entries'],
};

/// Descriptor for `AddLibraryTemplatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addLibraryTemplatesRequestDescriptor =
    $convert.base64Decode(
        'ChpBZGRMaWJyYXJ5VGVtcGxhdGVzUmVxdWVzdBIfCgtsaWJyYXJ5X2lkcxgBIAMoCVIKbGlicm'
        'FyeUlkcxIfCgtpbl9yb3RhdGlvbhgDIAEoCFIKaW5Sb3RhdGlvbkoECAIQA1IHZW50cmllcw==');

@$core.Deprecated('Use addLibraryTemplatesResponseDescriptor instead')
const AddLibraryTemplatesResponse$json = {
  '1': 'AddLibraryTemplatesResponse',
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['home'],
};

/// Descriptor for `AddLibraryTemplatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addLibraryTemplatesResponseDescriptor = $convert
    .base64Decode('ChtBZGRMaWJyYXJ5VGVtcGxhdGVzUmVzcG9uc2VKBAgBEAJSBGhvbWU=');

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
    {
      '1': 'muscle',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscle'
    },
    {'1': 'hours_remaining', '3': 6, '4': 1, '5': 3, '10': 'hoursRemaining'},
    {'1': 'recovered', '3': 7, '4': 1, '5': 8, '10': 'recovered'},
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 3, '2': 4},
    {'1': 4, '2': 5},
    {'1': 5, '2': 6},
    {'1': 8, '2': 9},
  ],
  '10': [
    'muscle_key',
    'label',
    'last_trained_at',
    'recovered_at',
    'fraction',
    'in_next_workout'
  ],
};

/// Descriptor for `MuscleRecoveryStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List muscleRecoveryStatusDescriptor = $convert.base64Decode(
    'ChRNdXNjbGVSZWNvdmVyeVN0YXR1cxIvCgZtdXNjbGUYCSABKA4yFy53b3Jrb3V0LnYxLk11c2'
    'NsZUdyb3VwUgZtdXNjbGUSJwoPaG91cnNfcmVtYWluaW5nGAYgASgDUg5ob3Vyc1JlbWFpbmlu'
    'ZxIcCglyZWNvdmVyZWQYByABKAhSCXJlY292ZXJlZEoECAEQAkoECAIQA0oECAMQBEoECAQQBU'
    'oECAUQBkoECAgQCVIKbXVzY2xlX2tleVIFbGFiZWxSD2xhc3RfdHJhaW5lZF9hdFIMcmVjb3Zl'
    'cmVkX2F0UghmcmFjdGlvblIPaW5fbmV4dF93b3Jrb3V0');

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
    {
      '1': 'addable_library_ids',
      '3': 16,
      '4': 3,
      '5': 9,
      '10': 'addableLibraryIds'
    },
    {'1': 'current_plan_id', '3': 17, '4': 1, '5': 9, '10': 'currentPlanId'},
    {
      '1': 'program',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'program'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 4, '2': 5},
    {'1': 8, '2': 9},
    {'1': 15, '2': 16},
  ],
  '10': ['trackers', 'user_messages', 'ignored_muscles'],
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
    'aGVjaxgOIAEoCzIZLndvcmtvdXQudjEuUm90YXRpb25DaGVja1INcm90YXRpb25DaGVjaxIuCh'
    'NhZGRhYmxlX2xpYnJhcnlfaWRzGBAgAygJUhFhZGRhYmxlTGlicmFyeUlkcxImCg9jdXJyZW50'
    'X3BsYW5faWQYESABKAlSDWN1cnJlbnRQbGFuSWQSNAoHcHJvZ3JhbRgSIAEoCzIaLndvcmtvdX'
    'QudjEuUHJvZ3JhbVN1bW1hcnlSB3Byb2dyYW1KBAgCEANKBAgEEAVKBAgIEAlKBAgPEBBSCHRy'
    'YWNrZXJzUg11c2VyX21lc3NhZ2VzUg9pZ25vcmVkX211c2NsZXM=');

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
    {
      '1': 'additions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.RotationAddition',
      '10': 'additions'
    },
  ],
};

/// Descriptor for `RotationCheck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotationCheckDescriptor = $convert.base64Decode(
    'Cg1Sb3RhdGlvbkNoZWNrEjAKBnZvbHVtZRgBIAMoCzIYLndvcmtvdXQudjEuTXVzY2xlVm9sdW'
    '1lUgZ2b2x1bWUSNwoId2FybmluZ3MYAiADKAsyGy53b3Jrb3V0LnYxLlJvdGF0aW9uV2Fybmlu'
    'Z1IId2FybmluZ3MSOgoJYWRkaXRpb25zGAMgAygLMhwud29ya291dC52MS5Sb3RhdGlvbkFkZG'
    'l0aW9uUglhZGRpdGlvbnM=');

@$core.Deprecated('Use rotationAdditionDescriptor instead')
const RotationAddition$json = {
  '1': 'RotationAddition',
  '2': [
    {'1': 'template_id', '3': 1, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'library_id', '3': 2, '4': 1, '5': 9, '10': 'libraryId'},
    {
      '1': 'muscles',
      '3': 3,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscles'
    },
  ],
};

/// Descriptor for `RotationAddition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotationAdditionDescriptor = $convert.base64Decode(
    'ChBSb3RhdGlvbkFkZGl0aW9uEh8KC3RlbXBsYXRlX2lkGAEgASgJUgp0ZW1wbGF0ZUlkEh0KCm'
    'xpYnJhcnlfaWQYAiABKAlSCWxpYnJhcnlJZBIxCgdtdXNjbGVzGAMgAygOMhcud29ya291dC52'
    'MS5NdXNjbGVHcm91cFIHbXVzY2xlcw==');

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

@$core.Deprecated('Use getTemplatePlanRequestDescriptor instead')
const GetTemplatePlanRequest$json = {
  '1': 'GetTemplatePlanRequest',
  '2': [
    {'1': 'exercises', '3': 3, '4': 3, '5': 9, '10': 'exercises'},
    {'1': 'budget_minutes', '3': 2, '4': 1, '5': 5, '10': 'budgetMinutes'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `GetTemplatePlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTemplatePlanRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRUZW1wbGF0ZVBsYW5SZXF1ZXN0EhwKCWV4ZXJjaXNlcxgDIAMoCVIJZXhlcmNpc2VzEi'
        'UKDmJ1ZGdldF9taW51dGVzGAIgASgFUg1idWRnZXRNaW51dGVzSgQIARAC');

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
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['unlink'],
};

/// Descriptor for `SaveTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveTemplateRequestDescriptor = $convert.base64Decode(
    'ChNTYXZlVGVtcGxhdGVSZXF1ZXN0EjcKCHRlbXBsYXRlGAEgASgLMhsud29ya291dC52MS5Xb3'
    'Jrb3V0VGVtcGxhdGVSCHRlbXBsYXRlSgQIAhADUgZ1bmxpbms=');

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
    {
      '1': 'rotation_count',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'rotationCount',
      '17': true
    },
  ],
  '8': [
    {'1': '_rotation_count'},
  ],
};

/// Descriptor for `ReorderTemplatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderTemplatesRequestDescriptor = $convert.base64Decode(
    'ChdSZW9yZGVyVGVtcGxhdGVzUmVxdWVzdBIhCgx0ZW1wbGF0ZV9pZHMYASADKAlSC3RlbXBsYX'
    'RlSWRzEioKDnJvdGF0aW9uX2NvdW50GAIgASgFSABSDXJvdGF0aW9uQ291bnSIAQFCEQoPX3Jv'
    'dGF0aW9uX2NvdW50');

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
    {'1': 'exercise', '3': 5, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'weight', '3': 2, '4': 1, '5': 2, '10': 'weight'},
    {'1': 'reps', '3': 3, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '9': 0, '10': 'sets', '17': true},
  ],
  '8': [
    {'1': '_sets'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `SetOverrideRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setOverrideRequestDescriptor = $convert.base64Decode(
    'ChJTZXRPdmVycmlkZVJlcXVlc3QSGgoIZXhlcmNpc2UYBSABKAlSCGV4ZXJjaXNlEhYKBndlaW'
    'dodBgCIAEoAlIGd2VpZ2h0EhIKBHJlcHMYAyABKAVSBHJlcHMSFwoEc2V0cxgEIAEoBUgAUgRz'
    'ZXRziAEBQgcKBV9zZXRzSgQIARAC');

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
  ],
  '8': [
    {'1': '_strength'},
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 4, '2': 5},
    {'1': 7, '2': 8},
    {'1': 8, '2': 9},
  ],
  '10': [
    'body_weight_kg',
    'experience',
    'gender',
    'library_entries',
    'starting_weights'
  ],
};

/// Descriptor for `CompleteOnboardingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeOnboardingRequestDescriptor = $convert.base64Decode(
    'ChlDb21wbGV0ZU9uYm9hcmRpbmdSZXF1ZXN0EioKBHVuaXQYAyABKA4yFi53b3Jrb3V0LnYxLl'
    'dlaWdodFVuaXRSBHVuaXQSHwoLbGlicmFyeV9pZHMYBSADKAlSCmxpYnJhcnlJZHMSHwoIc3Ry'
    'ZW5ndGgYBiABKAJIAFIIc3RyZW5ndGiIAQFCCwoJX3N0cmVuZ3RoSgQIARACSgQIAhADSgQIBB'
    'AFSgQIBxAISgQICBAJUg5ib2R5X3dlaWdodF9rZ1IKZXhwZXJpZW5jZVIGZ2VuZGVyUg9saWJy'
    'YXJ5X2VudHJpZXNSEHN0YXJ0aW5nX3dlaWdodHM=');

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
    {'1': 'exercise', '3': 3, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'weight_lb', '3': 2, '4': 1, '5': 2, '10': 'weightLb'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `ExerciseWeight`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseWeightDescriptor = $convert.base64Decode(
    'Cg5FeGVyY2lzZVdlaWdodBIaCghleGVyY2lzZRgDIAEoCVIIZXhlcmNpc2USGwoJd2VpZ2h0X2'
    'xiGAIgASgCUgh3ZWlnaHRMYkoECAEQAg==');

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
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['home'],
};

/// Descriptor for `CompleteOnboardingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeOnboardingResponseDescriptor = $convert
    .base64Decode('ChpDb21wbGV0ZU9uYm9hcmRpbmdSZXNwb25zZUoECAEQAlIEaG9tZQ==');

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
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['availability'],
};

/// Descriptor for `WorkoutHeartRatePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutHeartRatePointDescriptor = $convert.base64Decode(
    'ChVXb3Jrb3V0SGVhcnRSYXRlUG9pbnQSHQoKc2FtcGxlZF9hdBgBIAEoA1IJc2FtcGxlZEF0Eh'
    'AKA2JwbRgCIAEoAlIDYnBtSgQIAxAEUgxhdmFpbGFiaWxpdHk=');

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
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['stored'],
};

/// Descriptor for `AppendWorkoutHeartRateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutHeartRateResponseDescriptor =
    $convert.base64Decode(
        'Ch5BcHBlbmRXb3Jrb3V0SGVhcnRSYXRlUmVzcG9uc2VKBAgBEAJSBnN0b3JlZA==');

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
    {
      '1': 'answer_rung',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AnswerRungRequest',
      '9': 0,
      '10': 'answerRung'
    },
    {
      '1': 'answer_effort',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AnswerEffortRequest',
      '9': 0,
      '10': 'answerEffort'
    },
  ],
  '8': [
    {'1': 'mutation'},
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 15, '2': 16},
    {'1': 16, '2': 17},
    {'1': 21, '2': 22},
    {'1': 22, '2': 23},
  ],
  '10': [
    'event_id',
    'client_created_at',
    'skip_rest',
    'cancel_proposed_set',
    'rate_exercise'
  ],
};

/// Descriptor for `WorkoutMutation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutMutationDescriptor = $convert.base64Decode(
    'Cg9Xb3Jrb3V0TXV0YXRpb24SQwoMY29tcGxldGVfc2V0GAsgASgLMh4ud29ya291dC52MS5Db2'
    '1wbGV0ZVNldFJlcXVlc3RIAFILY29tcGxldGVTZXQSWQoUZGVsZXRlX2NvbXBsZXRlZF9zZXQY'
    'DSABKAsyJS53b3Jrb3V0LnYxLkRlbGV0ZUNvbXBsZXRlZFNldFJlcXVlc3RIAFISZGVsZXRlQ2'
    '9tcGxldGVkU2V0EkAKC2VuZF93b3Jrb3V0GA4gASgLMh0ud29ya291dC52MS5FbmRXb3Jrb3V0'
    'UmVxdWVzdEgAUgplbmRXb3Jrb3V0EkYKDWFkZF9leGVyY2lzZXMYESABKAsyHy53b3Jrb3V0Ln'
    'YxLkFkZEV4ZXJjaXNlc1JlcXVlc3RIAFIMYWRkRXhlcmNpc2VzEl8KFmFkanVzdF9leGVyY2lz'
    'ZV93ZWlnaHQYEiABKAsyJy53b3Jrb3V0LnYxLkFkanVzdEV4ZXJjaXNlV2VpZ2h0UmVxdWVzdE'
    'gAUhRhZGp1c3RFeGVyY2lzZVdlaWdodBJMCg9yZW1vdmVfZXhlcmNpc2UYEyABKAsyIS53b3Jr'
    'b3V0LnYxLlJlbW92ZUV4ZXJjaXNlUmVxdWVzdEgAUg5yZW1vdmVFeGVyY2lzZRJSChFyZW9yZG'
    'VyX2V4ZXJjaXNlcxgUIAEoCzIjLndvcmtvdXQudjEuUmVvcmRlckV4ZXJjaXNlc1JlcXVlc3RI'
    'AFIQcmVvcmRlckV4ZXJjaXNlcxJTChJlZGl0X2NvbXBsZXRlZF9zZXQYFyABKAsyIy53b3Jrb3'
    'V0LnYxLkVkaXRDb21wbGV0ZWRTZXRSZXF1ZXN0SABSEGVkaXRDb21wbGV0ZWRTZXQSOgoJc3Rh'
    'cnRfc2V0GBggASgLMhsud29ya291dC52MS5TdGFydFNldFJlcXVlc3RIAFIIc3RhcnRTZXQSQw'
    'oMc2tpcF93YXJtdXBzGBkgASgLMh4ud29ya291dC52MS5Ta2lwV2FybXVwc1JlcXVlc3RIAFIL'
    'c2tpcFdhcm11cHMSRwoLc2V0X3Nlc3Npb24YGiABKAsyJC53b3Jrb3V0LnYxLlNldFdvcmtvdX'
    'RTZXNzaW9uUmVxdWVzdEgAUgpzZXRTZXNzaW9uEkAKC2Fuc3dlcl9ydW5nGBsgASgLMh0ud29y'
    'a291dC52MS5BbnN3ZXJSdW5nUmVxdWVzdEgAUgphbnN3ZXJSdW5nEkYKDWFuc3dlcl9lZmZvcn'
    'QYHCABKAsyHy53b3Jrb3V0LnYxLkFuc3dlckVmZm9ydFJlcXVlc3RIAFIMYW5zd2VyRWZmb3J0'
    'QgoKCG11dGF0aW9uSgQIARACSgQIAhADSgQIChALSgQIDBANSgQIDxAQSgQIEBARSgQIFRAWSg'
    'QIFhAXUghldmVudF9pZFIRY2xpZW50X2NyZWF0ZWRfYXRSCXNraXBfcmVzdFITY2FuY2VsX3By'
    'b3Bvc2VkX3NldFINcmF0ZV9leGVyY2lzZQ==');

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
    {
      '1': 'workout_state',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetWorkoutResponse',
      '10': 'workoutState'
    },
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['applied_event_ids'],
};

/// Descriptor for `AppendWorkoutMutationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutMutationsResponseDescriptor =
    $convert.base64Decode(
        'Ch5BcHBlbmRXb3Jrb3V0TXV0YXRpb25zUmVzcG9uc2USQwoNd29ya291dF9zdGF0ZRgCIAEoCz'
        'IeLndvcmtvdXQudjEuR2V0V29ya291dFJlc3BvbnNlUgx3b3Jrb3V0U3RhdGVKBAgBEAJSEWFw'
        'cGxpZWRfZXZlbnRfaWRz');

@$core.Deprecated('Use programSummaryDescriptor instead')
const ProgramSummary$json = {
  '1': 'ProgramSummary',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'author', '3': 3, '4': 1, '5': 9, '10': 'author'},
    {'1': 'note', '3': 4, '4': 1, '5': 9, '10': 'note'},
    {'1': 'set_at', '3': 5, '4': 1, '5': 3, '10': 'setAt'},
    {'1': 'builtin_rules', '3': 6, '4': 1, '5': 8, '10': 'builtinRules'},
  ],
};

/// Descriptor for `ProgramSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List programSummaryDescriptor = $convert.base64Decode(
    'Cg5Qcm9ncmFtU3VtbWFyeRIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIWCg'
    'ZhdXRob3IYAyABKAlSBmF1dGhvchISCgRub3RlGAQgASgJUgRub3RlEhUKBnNldF9hdBgFIAEo'
    'A1IFc2V0QXQSIwoNYnVpbHRpbl9ydWxlcxgGIAEoCFIMYnVpbHRpblJ1bGVz');

@$core.Deprecated('Use getProgramRequestDescriptor instead')
const GetProgramRequest$json = {
  '1': 'GetProgramRequest',
};

/// Descriptor for `GetProgramRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgramRequestDescriptor =
    $convert.base64Decode('ChFHZXRQcm9ncmFtUmVxdWVzdA==');

@$core.Deprecated('Use getProgramResponseDescriptor instead')
const GetProgramResponse$json = {
  '1': 'GetProgramResponse',
  '2': [
    {
      '1': 'summary',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'summary'
    },
    {'1': 'program_json', '3': 2, '4': 1, '5': 9, '10': 'programJson'},
    {
      '1': 'history',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'history'
    },
    {'1': 'guide', '3': 4, '4': 1, '5': 9, '10': 'guide'},
  ],
};

/// Descriptor for `GetProgramResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgramResponseDescriptor = $convert.base64Decode(
    'ChJHZXRQcm9ncmFtUmVzcG9uc2USNAoHc3VtbWFyeRgBIAEoCzIaLndvcmtvdXQudjEuUHJvZ3'
    'JhbVN1bW1hcnlSB3N1bW1hcnkSIQoMcHJvZ3JhbV9qc29uGAIgASgJUgtwcm9ncmFtSnNvbhI0'
    'CgdoaXN0b3J5GAMgAygLMhoud29ya291dC52MS5Qcm9ncmFtU3VtbWFyeVIHaGlzdG9yeRIUCg'
    'VndWlkZRgEIAEoCVIFZ3VpZGU=');

@$core.Deprecated('Use suggestedChangeDescriptor instead')
const SuggestedChange$json = {
  '1': 'SuggestedChange',
  '2': [
    {
      '1': 'verb',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ChangeVerb',
      '10': 'verb'
    },
    {
      '1': 'subject',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ChangeSubject',
      '10': 'subject'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `SuggestedChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestedChangeDescriptor = $convert.base64Decode(
    'Cg9TdWdnZXN0ZWRDaGFuZ2USKgoEdmVyYhgBIAEoDjIWLndvcmtvdXQudjEuQ2hhbmdlVmVyYl'
    'IEdmVyYhIzCgdzdWJqZWN0GAIgASgOMhkud29ya291dC52MS5DaGFuZ2VTdWJqZWN0UgdzdWJq'
    'ZWN0EhIKBG5hbWUYAyABKAlSBG5hbWU=');

@$core.Deprecated('Use suggestionDescriptor instead')
const Suggestion$json = {
  '1': 'Suggestion',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'from', '3': 2, '4': 1, '5': 9, '10': 'from'},
    {'1': 'from_name', '3': 3, '4': 1, '5': 9, '10': 'fromName'},
    {'1': 'kind', '3': 4, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
    {'1': 'suggested_at', '3': 7, '4': 1, '5': 3, '10': 'suggestedAt'},
    {
      '1': 'status',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SuggestionStatus',
      '10': 'status'
    },
    {'1': 'answered_at', '3': 9, '4': 1, '5': 3, '10': 'answeredAt'},
    {
      '1': 'changes',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SuggestedChange',
      '10': 'changes'
    },
    {'1': 'problem', '3': 11, '4': 1, '5': 9, '10': 'problem'},
    {'1': 'exercises', '3': 12, '4': 3, '5': 9, '10': 'exercises'},
  ],
};

/// Descriptor for `Suggestion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestionDescriptor = $convert.base64Decode(
    'CgpTdWdnZXN0aW9uEg4KAmlkGAEgASgJUgJpZBISCgRmcm9tGAIgASgJUgRmcm9tEhsKCWZyb2'
    '1fbmFtZRgDIAEoCVIIZnJvbU5hbWUSEgoEa2luZBgEIAEoCVIEa2luZBIUCgV0aXRsZRgFIAEo'
    'CVIFdGl0bGUSEgoEbm90ZRgGIAEoCVIEbm90ZRIhCgxzdWdnZXN0ZWRfYXQYByABKANSC3N1Z2'
    'dlc3RlZEF0EjQKBnN0YXR1cxgIIAEoDjIcLndvcmtvdXQudjEuU3VnZ2VzdGlvblN0YXR1c1IG'
    'c3RhdHVzEh8KC2Fuc3dlcmVkX2F0GAkgASgDUgphbnN3ZXJlZEF0EjUKB2NoYW5nZXMYCiADKA'
    'syGy53b3Jrb3V0LnYxLlN1Z2dlc3RlZENoYW5nZVIHY2hhbmdlcxIYCgdwcm9ibGVtGAsgASgJ'
    'Ugdwcm9ibGVtEhwKCWV4ZXJjaXNlcxgMIAMoCVIJZXhlcmNpc2Vz');

@$core.Deprecated('Use explainSuggestionRequestDescriptor instead')
const ExplainSuggestionRequest$json = {
  '1': 'ExplainSuggestionRequest',
  '2': [
    {'1': 'suggestion_id', '3': 1, '4': 1, '5': 9, '10': 'suggestionId'},
  ],
};

/// Descriptor for `ExplainSuggestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List explainSuggestionRequestDescriptor =
    $convert.base64Decode(
        'ChhFeHBsYWluU3VnZ2VzdGlvblJlcXVlc3QSIwoNc3VnZ2VzdGlvbl9pZBgBIAEoCVIMc3VnZ2'
        'VzdGlvbklk');

@$core.Deprecated('Use explainSuggestionResponseDescriptor instead')
const ExplainSuggestionResponse$json = {
  '1': 'ExplainSuggestionResponse',
  '2': [
    {
      '1': 'suggestion',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Suggestion',
      '10': 'suggestion'
    },
    {'1': 'rotation_before', '3': 2, '4': 3, '5': 9, '10': 'rotationBefore'},
    {'1': 'rotation_after', '3': 3, '4': 3, '5': 9, '10': 'rotationAfter'},
    {
      '1': 'workouts',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutChange',
      '10': 'workouts'
    },
    {
      '1': 'lifts',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.LiftRuleChange',
      '10': 'lifts'
    },
    {
      '1': 'numbers',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.NumberChange',
      '10': 'numbers'
    },
  ],
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['forecasts'],
};

/// Descriptor for `ExplainSuggestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List explainSuggestionResponseDescriptor = $convert.base64Decode(
    'ChlFeHBsYWluU3VnZ2VzdGlvblJlc3BvbnNlEjYKCnN1Z2dlc3Rpb24YASABKAsyFi53b3Jrb3'
    'V0LnYxLlN1Z2dlc3Rpb25SCnN1Z2dlc3Rpb24SJwoPcm90YXRpb25fYmVmb3JlGAIgAygJUg5y'
    'b3RhdGlvbkJlZm9yZRIlCg5yb3RhdGlvbl9hZnRlchgDIAMoCVINcm90YXRpb25BZnRlchI1Cg'
    'h3b3Jrb3V0cxgEIAMoCzIZLndvcmtvdXQudjEuV29ya291dENoYW5nZVIId29ya291dHMSMAoF'
    'bGlmdHMYBSADKAsyGi53b3Jrb3V0LnYxLkxpZnRSdWxlQ2hhbmdlUgVsaWZ0cxIyCgdudW1iZX'
    'JzGAcgAygLMhgud29ya291dC52MS5OdW1iZXJDaGFuZ2VSB251bWJlcnNKBAgGEAdSCWZvcmVj'
    'YXN0cw==');

@$core.Deprecated('Use workoutChangeDescriptor instead')
const WorkoutChange$json = {
  '1': 'WorkoutChange',
  '2': [
    {
      '1': 'verb',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ChangeVerb',
      '10': 'verb'
    },
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'exercises', '3': 3, '4': 3, '5': 9, '10': 'exercises'},
  ],
};

/// Descriptor for `WorkoutChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutChangeDescriptor = $convert.base64Decode(
    'Cg1Xb3Jrb3V0Q2hhbmdlEioKBHZlcmIYASABKA4yFi53b3Jrb3V0LnYxLkNoYW5nZVZlcmJSBH'
    'ZlcmISEgoEbmFtZRgCIAEoCVIEbmFtZRIcCglleGVyY2lzZXMYAyADKAlSCWV4ZXJjaXNlcw==');

@$core.Deprecated('Use ruleSummaryDescriptor instead')
const RuleSummary$json = {
  '1': 'RuleSummary',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'sets', '3': 2, '4': 1, '5': 5, '10': 'sets'},
    {'1': 'reps', '3': 3, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'rep_low', '3': 4, '4': 1, '5': 5, '10': 'repLow'},
    {'1': 'rep_high', '3': 5, '4': 1, '5': 5, '10': 'repHigh'},
    {'1': 'increment_lb', '3': 6, '4': 1, '5': 2, '10': 'incrementLb'},
    {
      '1': 'deload_after_fails',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'deloadAfterFails'
    },
    {'1': 'deload_factor', '3': 8, '4': 1, '5': 2, '10': 'deloadFactor'},
    {'1': 'rep_step', '3': 9, '4': 1, '5': 5, '10': 'repStep'},
    {'1': 'weight_lb', '3': 10, '4': 1, '5': 2, '10': 'weightLb'},
    {'1': 'cycle_steps', '3': 11, '4': 1, '5': 5, '10': 'cycleSteps'},
    {'1': 'note', '3': 12, '4': 1, '5': 9, '10': 'note'},
    {'1': 'scheme', '3': 13, '4': 1, '5': 9, '10': 'scheme'},
  ],
};

/// Descriptor for `RuleSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ruleSummaryDescriptor = $convert.base64Decode(
    'CgtSdWxlU3VtbWFyeRISCgRraW5kGAEgASgJUgRraW5kEhIKBHNldHMYAiABKAVSBHNldHMSEg'
    'oEcmVwcxgDIAEoBVIEcmVwcxIXCgdyZXBfbG93GAQgASgFUgZyZXBMb3cSGQoIcmVwX2hpZ2gY'
    'BSABKAVSB3JlcEhpZ2gSIQoMaW5jcmVtZW50X2xiGAYgASgCUgtpbmNyZW1lbnRMYhIsChJkZW'
    'xvYWRfYWZ0ZXJfZmFpbHMYByABKAVSEGRlbG9hZEFmdGVyRmFpbHMSIwoNZGVsb2FkX2ZhY3Rv'
    'chgIIAEoAlIMZGVsb2FkRmFjdG9yEhkKCHJlcF9zdGVwGAkgASgFUgdyZXBTdGVwEhsKCXdlaW'
    'dodF9sYhgKIAEoAlIId2VpZ2h0TGISHwoLY3ljbGVfc3RlcHMYCyABKAVSCmN5Y2xlU3RlcHMS'
    'EgoEbm90ZRgMIAEoCVIEbm90ZRIWCgZzY2hlbWUYDSABKAlSBnNjaGVtZQ==');

@$core.Deprecated('Use liftRuleChangeDescriptor instead')
const LiftRuleChange$json = {
  '1': 'LiftRuleChange',
  '2': [
    {'1': 'exercise', '3': 1, '4': 1, '5': 9, '10': 'exercise'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'before',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RuleSummary',
      '10': 'before'
    },
    {
      '1': 'after',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RuleSummary',
      '10': 'after'
    },
  ],
};

/// Descriptor for `LiftRuleChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List liftRuleChangeDescriptor = $convert.base64Decode(
    'Cg5MaWZ0UnVsZUNoYW5nZRIaCghleGVyY2lzZRgBIAEoCVIIZXhlcmNpc2USEgoEbmFtZRgCIA'
    'EoCVIEbmFtZRIvCgZiZWZvcmUYAyABKAsyFy53b3Jrb3V0LnYxLlJ1bGVTdW1tYXJ5UgZiZWZv'
    'cmUSLQoFYWZ0ZXIYBCABKAsyFy53b3Jrb3V0LnYxLlJ1bGVTdW1tYXJ5UgVhZnRlcg==');

@$core.Deprecated('Use numberChangeDescriptor instead')
const NumberChange$json = {
  '1': 'NumberChange',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'before', '3': 2, '4': 1, '5': 1, '10': 'before'},
    {'1': 'after', '3': 3, '4': 1, '5': 1, '10': 'after'},
  ],
};

/// Descriptor for `NumberChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List numberChangeDescriptor = $convert.base64Decode(
    'CgxOdW1iZXJDaGFuZ2USEgoEcGF0aBgBIAEoCVIEcGF0aBIWCgZiZWZvcmUYAiABKAFSBmJlZm'
    '9yZRIUCgVhZnRlchgDIAEoAVIFYWZ0ZXI=');

@$core.Deprecated('Use getSuggestionsRequestDescriptor instead')
const GetSuggestionsRequest$json = {
  '1': 'GetSuggestionsRequest',
};

/// Descriptor for `GetSuggestionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSuggestionsRequestDescriptor =
    $convert.base64Decode('ChVHZXRTdWdnZXN0aW9uc1JlcXVlc3Q=');

@$core.Deprecated('Use getSuggestionsResponseDescriptor instead')
const GetSuggestionsResponse$json = {
  '1': 'GetSuggestionsResponse',
  '2': [
    {
      '1': 'suggestions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.Suggestion',
      '10': 'suggestions'
    },
    {'1': 'pending', '3': 2, '4': 1, '5': 5, '10': 'pending'},
  ],
};

/// Descriptor for `GetSuggestionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSuggestionsResponseDescriptor = $convert.base64Decode(
    'ChZHZXRTdWdnZXN0aW9uc1Jlc3BvbnNlEjgKC3N1Z2dlc3Rpb25zGAEgAygLMhYud29ya291dC'
    '52MS5TdWdnZXN0aW9uUgtzdWdnZXN0aW9ucxIYCgdwZW5kaW5nGAIgASgFUgdwZW5kaW5n');

@$core.Deprecated('Use answerSuggestionRequestDescriptor instead')
const AnswerSuggestionRequest$json = {
  '1': 'AnswerSuggestionRequest',
  '2': [
    {'1': 'suggestion_id', '3': 1, '4': 1, '5': 9, '10': 'suggestionId'},
    {'1': 'accept', '3': 2, '4': 1, '5': 8, '10': 'accept'},
  ],
};

/// Descriptor for `AnswerSuggestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerSuggestionRequestDescriptor =
    $convert.base64Decode(
        'ChdBbnN3ZXJTdWdnZXN0aW9uUmVxdWVzdBIjCg1zdWdnZXN0aW9uX2lkGAEgASgJUgxzdWdnZX'
        'N0aW9uSWQSFgoGYWNjZXB0GAIgASgIUgZhY2NlcHQ=');

@$core.Deprecated('Use answerSuggestionResponseDescriptor instead')
const AnswerSuggestionResponse$json = {
  '1': 'AnswerSuggestionResponse',
  '2': [
    {'1': 'problem', '3': 1, '4': 1, '5': 9, '10': 'problem'},
  ],
};

/// Descriptor for `AnswerSuggestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerSuggestionResponseDescriptor =
    $convert.base64Decode(
        'ChhBbnN3ZXJTdWdnZXN0aW9uUmVzcG9uc2USGAoHcHJvYmxlbRgBIAEoCVIHcHJvYmxlbQ==');

@$core.Deprecated('Use getProgramVersionRequestDescriptor instead')
const GetProgramVersionRequest$json = {
  '1': 'GetProgramVersionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetProgramVersionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgramVersionRequestDescriptor = $convert
    .base64Decode('ChhHZXRQcm9ncmFtVmVyc2lvblJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use getProgramVersionResponseDescriptor instead')
const GetProgramVersionResponse$json = {
  '1': 'GetProgramVersionResponse',
  '2': [
    {
      '1': 'summary',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'summary'
    },
    {'1': 'program_json', '3': 2, '4': 1, '5': 9, '10': 'programJson'},
  ],
};

/// Descriptor for `GetProgramVersionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgramVersionResponseDescriptor = $convert.base64Decode(
    'ChlHZXRQcm9ncmFtVmVyc2lvblJlc3BvbnNlEjQKB3N1bW1hcnkYASABKAsyGi53b3Jrb3V0Ln'
    'YxLlByb2dyYW1TdW1tYXJ5UgdzdW1tYXJ5EiEKDHByb2dyYW1fanNvbhgCIAEoCVILcHJvZ3Jh'
    'bUpzb24=');

@$core.Deprecated('Use programProblemDescriptor instead')
const ProgramProblem$json = {
  '1': 'ProgramProblem',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'error', '3': 3, '4': 1, '5': 8, '10': 'error'},
  ],
};

/// Descriptor for `ProgramProblem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List programProblemDescriptor = $convert.base64Decode(
    'Cg5Qcm9ncmFtUHJvYmxlbRISCgRwYXRoGAEgASgJUgRwYXRoEhgKB21lc3NhZ2UYAiABKAlSB2'
    '1lc3NhZ2USFAoFZXJyb3IYAyABKAhSBWVycm9y');

@$core.Deprecated('Use validateProgramRequestDescriptor instead')
const ValidateProgramRequest$json = {
  '1': 'ValidateProgramRequest',
  '2': [
    {'1': 'program_json', '3': 1, '4': 1, '5': 9, '10': 'programJson'},
  ],
};

/// Descriptor for `ValidateProgramRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateProgramRequestDescriptor =
    $convert.base64Decode(
        'ChZWYWxpZGF0ZVByb2dyYW1SZXF1ZXN0EiEKDHByb2dyYW1fanNvbhgBIAEoCVILcHJvZ3JhbU'
        'pzb24=');

@$core.Deprecated('Use validateProgramResponseDescriptor instead')
const ValidateProgramResponse$json = {
  '1': 'ValidateProgramResponse',
  '2': [
    {
      '1': 'problems',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgramProblem',
      '10': 'problems'
    },
  ],
};

/// Descriptor for `ValidateProgramResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateProgramResponseDescriptor =
    $convert.base64Decode(
        'ChdWYWxpZGF0ZVByb2dyYW1SZXNwb25zZRI2Cghwcm9ibGVtcxgBIAMoCzIaLndvcmtvdXQudj'
        'EuUHJvZ3JhbVByb2JsZW1SCHByb2JsZW1z');

@$core.Deprecated('Use setProgramRequestDescriptor instead')
const SetProgramRequest$json = {
  '1': 'SetProgramRequest',
  '2': [
    {'1': 'program_json', '3': 1, '4': 1, '5': 9, '10': 'programJson'},
    {'1': 'note', '3': 2, '4': 1, '5': 9, '10': 'note'},
    {'1': 'author', '3': 3, '4': 1, '5': 9, '10': 'author'},
  ],
};

/// Descriptor for `SetProgramRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setProgramRequestDescriptor = $convert.base64Decode(
    'ChFTZXRQcm9ncmFtUmVxdWVzdBIhCgxwcm9ncmFtX2pzb24YASABKAlSC3Byb2dyYW1Kc29uEh'
    'IKBG5vdGUYAiABKAlSBG5vdGUSFgoGYXV0aG9yGAMgASgJUgZhdXRob3I=');

@$core.Deprecated('Use setProgramResponseDescriptor instead')
const SetProgramResponse$json = {
  '1': 'SetProgramResponse',
  '2': [
    {
      '1': 'problems',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgramProblem',
      '10': 'problems'
    },
    {
      '1': 'summary',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `SetProgramResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setProgramResponseDescriptor = $convert.base64Decode(
    'ChJTZXRQcm9ncmFtUmVzcG9uc2USNgoIcHJvYmxlbXMYASADKAsyGi53b3Jrb3V0LnYxLlByb2'
    'dyYW1Qcm9ibGVtUghwcm9ibGVtcxI0CgdzdW1tYXJ5GAIgASgLMhoud29ya291dC52MS5Qcm9n'
    'cmFtU3VtbWFyeVIHc3VtbWFyeQ==');

@$core.Deprecated('Use resetProgramRequestDescriptor instead')
const ResetProgramRequest$json = {
  '1': 'ResetProgramRequest',
  '2': [
    {'1': 'to', '3': 1, '4': 1, '5': 9, '10': 'to'},
  ],
};

/// Descriptor for `ResetProgramRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resetProgramRequestDescriptor = $convert
    .base64Decode('ChNSZXNldFByb2dyYW1SZXF1ZXN0Eg4KAnRvGAEgASgJUgJ0bw==');

@$core.Deprecated('Use resetProgramResponseDescriptor instead')
const ResetProgramResponse$json = {
  '1': 'ResetProgramResponse',
  '2': [
    {
      '1': 'summary',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProgramSummary',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `ResetProgramResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resetProgramResponseDescriptor = $convert.base64Decode(
    'ChRSZXNldFByb2dyYW1SZXNwb25zZRI0CgdzdW1tYXJ5GAEgASgLMhoud29ya291dC52MS5Qcm'
    '9ncmFtU3VtbWFyeVIHc3VtbWFyeQ==');

@$core.Deprecated('Use simulateProgramRequestDescriptor instead')
const SimulateProgramRequest$json = {
  '1': 'SimulateProgramRequest',
  '2': [
    {'1': 'program_json', '3': 1, '4': 1, '5': 9, '10': 'programJson'},
    {'1': 'sessions', '3': 2, '4': 1, '5': 5, '10': 'sessions'},
    {'1': 'every_days', '3': 3, '4': 1, '5': 5, '10': 'everyDays'},
    {
      '1': 'effort',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SimulatedEffort',
      '10': 'effort'
    },
    {'1': 'miss_every', '3': 5, '4': 1, '5': 5, '10': 'missEvery'},
    {'1': 'template_id', '3': 6, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'budget_minutes', '3': 7, '4': 1, '5': 5, '10': 'budgetMinutes'},
    {'1': 'history', '3': 8, '4': 1, '5': 5, '10': 'history'},
    {'1': 'exercises', '3': 9, '4': 3, '5': 9, '10': 'exercises'},
  ],
};

/// Descriptor for `SimulateProgramRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulateProgramRequestDescriptor = $convert.base64Decode(
    'ChZTaW11bGF0ZVByb2dyYW1SZXF1ZXN0EiEKDHByb2dyYW1fanNvbhgBIAEoCVILcHJvZ3JhbU'
    'pzb24SGgoIc2Vzc2lvbnMYAiABKAVSCHNlc3Npb25zEh0KCmV2ZXJ5X2RheXMYAyABKAVSCWV2'
    'ZXJ5RGF5cxIzCgZlZmZvcnQYBCABKA4yGy53b3Jrb3V0LnYxLlNpbXVsYXRlZEVmZm9ydFIGZW'
    'Zmb3J0Eh0KCm1pc3NfZXZlcnkYBSABKAVSCW1pc3NFdmVyeRIfCgt0ZW1wbGF0ZV9pZBgGIAEo'
    'CVIKdGVtcGxhdGVJZBIlCg5idWRnZXRfbWludXRlcxgHIAEoBVINYnVkZ2V0TWludXRlcxIYCg'
    'doaXN0b3J5GAggASgFUgdoaXN0b3J5EhwKCWV4ZXJjaXNlcxgJIAMoCVIJZXhlcmNpc2Vz');

@$core.Deprecated('Use simulatedLiftDescriptor instead')
const SimulatedLift$json = {
  '1': 'SimulatedLift',
  '2': [
    {'1': 'exercise', '3': 1, '4': 1, '5': 9, '10': 'exercise'},
    {
      '1': 'decision',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'decision'
    },
    {
      '1': 'recorded',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseDecision',
      '10': 'recorded'
    },
    {'1': 'done_weight', '3': 4, '4': 1, '5': 2, '10': 'doneWeight'},
    {'1': 'done_reps', '3': 5, '4': 1, '5': 5, '10': 'doneReps'},
    {'1': 'hit', '3': 6, '4': 1, '5': 8, '10': 'hit'},
  ],
};

/// Descriptor for `SimulatedLift`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulatedLiftDescriptor = $convert.base64Decode(
    'Cg1TaW11bGF0ZWRMaWZ0EhoKCGV4ZXJjaXNlGAEgASgJUghleGVyY2lzZRI4CghkZWNpc2lvbh'
    'gCIAEoCzIcLndvcmtvdXQudjEuRXhlcmNpc2VEZWNpc2lvblIIZGVjaXNpb24SOAoIcmVjb3Jk'
    'ZWQYAyABKAsyHC53b3Jrb3V0LnYxLkV4ZXJjaXNlRGVjaXNpb25SCHJlY29yZGVkEh8KC2Rvbm'
    'Vfd2VpZ2h0GAQgASgCUgpkb25lV2VpZ2h0EhsKCWRvbmVfcmVwcxgFIAEoBVIIZG9uZVJlcHMS'
    'EAoDaGl0GAYgASgIUgNoaXQ=');

@$core.Deprecated('Use simulatedWorkoutDescriptor instead')
const SimulatedWorkout$json = {
  '1': 'SimulatedWorkout',
  '2': [
    {'1': 'at', '3': 1, '4': 1, '5': 3, '10': 'at'},
    {'1': 'template_id', '3': 2, '4': 1, '5': 9, '10': 'templateId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'past', '3': 4, '4': 1, '5': 8, '10': 'past'},
    {
      '1': 'lifts',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SimulatedLift',
      '10': 'lifts'
    },
  ],
};

/// Descriptor for `SimulatedWorkout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulatedWorkoutDescriptor = $convert.base64Decode(
    'ChBTaW11bGF0ZWRXb3Jrb3V0Eg4KAmF0GAEgASgDUgJhdBIfCgt0ZW1wbGF0ZV9pZBgCIAEoCV'
    'IKdGVtcGxhdGVJZBISCgRuYW1lGAMgASgJUgRuYW1lEhIKBHBhc3QYBCABKAhSBHBhc3QSLwoF'
    'bGlmdHMYBSADKAsyGS53b3Jrb3V0LnYxLlNpbXVsYXRlZExpZnRSBWxpZnRz');

@$core.Deprecated('Use simulateProgramResponseDescriptor instead')
const SimulateProgramResponse$json = {
  '1': 'SimulateProgramResponse',
  '2': [
    {
      '1': 'problems',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgramProblem',
      '10': 'problems'
    },
    {
      '1': 'workouts',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SimulatedWorkout',
      '10': 'workouts'
    },
  ],
};

/// Descriptor for `SimulateProgramResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulateProgramResponseDescriptor = $convert.base64Decode(
    'ChdTaW11bGF0ZVByb2dyYW1SZXNwb25zZRI2Cghwcm9ibGVtcxgBIAMoCzIaLndvcmtvdXQudj'
    'EuUHJvZ3JhbVByb2JsZW1SCHByb2JsZW1zEjgKCHdvcmtvdXRzGAIgAygLMhwud29ya291dC52'
    'MS5TaW11bGF0ZWRXb3Jrb3V0Ugh3b3Jrb3V0cw==');

@$core.Deprecated('Use exerciseInfoDescriptor instead')
const ExerciseInfo$json = {
  '1': 'ExerciseInfo',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'short_name', '3': 3, '4': 1, '5': 9, '10': 'shortName'},
    {
      '1': 'equipment',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.EquipmentKind',
      '10': 'equipment'
    },
    {
      '1': 'muscles',
      '3': 5,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscles'
    },
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
    {'1': 'class_name', '3': 7, '4': 1, '5': 9, '10': 'className'},
    {'1': 'progression', '3': 8, '4': 1, '5': 9, '10': 'progression'},
  ],
};

/// Descriptor for `ExerciseInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseInfoDescriptor = $convert.base64Decode(
    'CgxFeGVyY2lzZUluZm8SEAoDa2V5GAEgASgJUgNrZXkSEgoEbmFtZRgCIAEoCVIEbmFtZRIdCg'
    'pzaG9ydF9uYW1lGAMgASgJUglzaG9ydE5hbWUSNwoJZXF1aXBtZW50GAQgASgOMhkud29ya291'
    'dC52MS5FcXVpcG1lbnRLaW5kUgllcXVpcG1lbnQSMQoHbXVzY2xlcxgFIAMoDjIXLndvcmtvdX'
    'QudjEuTXVzY2xlR3JvdXBSB211c2NsZXMSIAoLZGVzY3JpcHRpb24YBiABKAlSC2Rlc2NyaXB0'
    'aW9uEh0KCmNsYXNzX25hbWUYByABKAlSCWNsYXNzTmFtZRIgCgtwcm9ncmVzc2lvbhgIIAEoCV'
    'ILcHJvZ3Jlc3Npb24=');

@$core.Deprecated('Use plateProfileDescriptor instead')
const PlateProfile$json = {
  '1': 'PlateProfile',
  '2': [
    {'1': 'bar', '3': 1, '4': 1, '5': 2, '10': 'bar'},
    {'1': 'plates', '3': 2, '4': 3, '5': 2, '10': 'plates'},
  ],
};

/// Descriptor for `PlateProfile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plateProfileDescriptor = $convert.base64Decode(
    'CgxQbGF0ZVByb2ZpbGUSEAoDYmFyGAEgASgCUgNiYXISFgoGcGxhdGVzGAIgAygCUgZwbGF0ZX'
    'M=');

@$core.Deprecated('Use listExercisesRequestDescriptor instead')
const ListExercisesRequest$json = {
  '1': 'ListExercisesRequest',
};

/// Descriptor for `ListExercisesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listExercisesRequestDescriptor =
    $convert.base64Decode('ChRMaXN0RXhlcmNpc2VzUmVxdWVzdA==');

@$core.Deprecated('Use listExercisesResponseDescriptor instead')
const ListExercisesResponse$json = {
  '1': 'ListExercisesResponse',
  '2': [
    {
      '1': 'exercises',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseInfo',
      '10': 'exercises'
    },
    {
      '1': 'lb',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.PlateProfile',
      '10': 'lb'
    },
    {
      '1': 'kg',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.PlateProfile',
      '10': 'kg'
    },
  ],
};

/// Descriptor for `ListExercisesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listExercisesResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0RXhlcmNpc2VzUmVzcG9uc2USNgoJZXhlcmNpc2VzGAEgAygLMhgud29ya291dC52MS'
    '5FeGVyY2lzZUluZm9SCWV4ZXJjaXNlcxIoCgJsYhgCIAEoCzIYLndvcmtvdXQudjEuUGxhdGVQ'
    'cm9maWxlUgJsYhIoCgJrZxgDIAEoCzIYLndvcmtvdXQudjEuUGxhdGVQcm9maWxlUgJrZw==');

@$core.Deprecated('Use getUserRequestDescriptor instead')
const GetUserRequest$json = {
  '1': 'GetUserRequest',
  '9': [
    {'1': 1, '2': 2},
  ],
  '10': ['user_id'],
};

/// Descriptor for `GetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserRequestDescriptor =
    $convert.base64Decode('Cg5HZXRVc2VyUmVxdWVzdEoECAEQAlIHdXNlcl9pZA==');

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
