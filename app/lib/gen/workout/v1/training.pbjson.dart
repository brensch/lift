// This is a generated file - do not edit.
//
// Generated from workout/v1/training.proto.

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

@$core.Deprecated('Use setRoleDescriptor instead')
const SetRole$json = {
  '1': 'SetRole',
  '2': [
    {'1': 'SET_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'SET_ROLE_WORKING', '2': 1},
    {'1': 'SET_ROLE_WARMUP', '2': 2},
  ],
};

/// Descriptor for `SetRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List setRoleDescriptor = $convert.base64Decode(
    'CgdTZXRSb2xlEhgKFFNFVF9ST0xFX1VOU1BFQ0lGSUVEEAASFAoQU0VUX1JPTEVfV09SS0lORx'
    'ABEhMKD1NFVF9ST0xFX1dBUk1VUBAC');

@$core.Deprecated('Use measureDescriptor instead')
const Measure$json = {
  '1': 'Measure',
  '2': [
    {'1': 'weight', '3': 1, '4': 1, '5': 1, '10': 'weight'},
    {'1': 'reps', '3': 2, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'duration_s', '3': 3, '4': 1, '5': 5, '10': 'durationS'},
    {'1': 'distance_m', '3': 4, '4': 1, '5': 1, '10': 'distanceM'},
  ],
};

/// Descriptor for `Measure`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List measureDescriptor = $convert.base64Decode(
    'CgdNZWFzdXJlEhYKBndlaWdodBgBIAEoAVIGd2VpZ2h0EhIKBHJlcHMYAiABKAVSBHJlcHMSHQ'
    'oKZHVyYXRpb25fcxgDIAEoBVIJZHVyYXRpb25TEh0KCmRpc3RhbmNlX20YBCABKAFSCWRpc3Rh'
    'bmNlTQ==');

@$core.Deprecated('Use setViewDescriptor instead')
const SetView$json = {
  '1': 'SetView',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'block_id', '3': 2, '4': 1, '5': 9, '10': 'blockId'},
    {'1': 'order', '3': 3, '4': 1, '5': 5, '10': 'order'},
    {
      '1': 'exercise',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {
      '1': 'role',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SetRole',
      '10': 'role'
    },
    {
      '1': 'proposed',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'proposed'
    },
    {
      '1': 'target',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'target'
    },
    {
      '1': 'entry',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'entry'
    },
    {'1': 'has_entry', '3': 9, '4': 1, '5': 8, '10': 'hasEntry'},
    {'1': 'skipped', '3': 10, '4': 1, '5': 8, '10': 'skipped'},
    {'1': 'is_amrap', '3': 11, '4': 1, '5': 8, '10': 'isAmrap'},
    {'1': 'instruction', '3': 12, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'counts_toward_program',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'countsTowardProgram'
    },
    {'1': 'slot_key', '3': 14, '4': 1, '5': 9, '10': 'slotKey'},
  ],
};

/// Descriptor for `SetView`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setViewDescriptor = $convert.base64Decode(
    'CgdTZXRWaWV3Eg4KAmlkGAEgASgJUgJpZBIZCghibG9ja19pZBgCIAEoCVIHYmxvY2tJZBIUCg'
    'VvcmRlchgDIAEoBVIFb3JkZXISMAoIZXhlcmNpc2UYBCABKA4yFC53b3Jrb3V0LnYxLkV4ZXJj'
    'aXNlUghleGVyY2lzZRInCgRyb2xlGAUgASgOMhMud29ya291dC52MS5TZXRSb2xlUgRyb2xlEi'
    '8KCHByb3Bvc2VkGAYgASgLMhMud29ya291dC52MS5NZWFzdXJlUghwcm9wb3NlZBIrCgZ0YXJn'
    'ZXQYByABKAsyEy53b3Jrb3V0LnYxLk1lYXN1cmVSBnRhcmdldBIpCgVlbnRyeRgIIAEoCzITLn'
    'dvcmtvdXQudjEuTWVhc3VyZVIFZW50cnkSGwoJaGFzX2VudHJ5GAkgASgIUghoYXNFbnRyeRIY'
    'Cgdza2lwcGVkGAogASgIUgdza2lwcGVkEhkKCGlzX2FtcmFwGAsgASgIUgdpc0FtcmFwEiAKC2'
    'luc3RydWN0aW9uGAwgASgJUgtpbnN0cnVjdGlvbhIyChVjb3VudHNfdG93YXJkX3Byb2dyYW0Y'
    'DSABKAhSE2NvdW50c1Rvd2FyZFByb2dyYW0SGQoIc2xvdF9rZXkYDiABKAlSB3Nsb3RLZXk=');

@$core.Deprecated('Use blockViewDescriptor instead')
const BlockView$json = {
  '1': 'BlockView',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'order', '3': 2, '4': 1, '5': 5, '10': 'order'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'interleave_warmups',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'rest_config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {
      '1': 'sets',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SetView',
      '10': 'sets'
    },
  ],
};

/// Descriptor for `BlockView`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockViewDescriptor = $convert.base64Decode(
    'CglCbG9ja1ZpZXcSDgoCaWQYASABKAlSAmlkEhQKBW9yZGVyGAIgASgFUgVvcmRlchISCgRuYW'
    '1lGAMgASgJUgRuYW1lEi0KEmludGVybGVhdmVfd2FybXVwcxgEIAEoCFIRaW50ZXJsZWF2ZVdh'
    'cm11cHMSNwoLcmVzdF9jb25maWcYBSABKAsyFi53b3Jrb3V0LnYxLlJlc3RDb25maWdSCnJlc3'
    'RDb25maWcSJwoEc2V0cxgGIAMoCzITLndvcmtvdXQudjEuU2V0Vmlld1IEc2V0cw==');

@$core.Deprecated('Use workoutViewDescriptor instead')
const WorkoutView$json = {
  '1': 'WorkoutView',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 3, '10': 'endTime'},
    {'1': 'session_id', '3': 5, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'blocks',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.BlockView',
      '10': 'blocks'
    },
    {'1': 'active_set_id', '3': 7, '4': 1, '5': 9, '10': 'activeSetId'},
    {'1': 'active_started_at', '3': 8, '4': 1, '5': 3, '10': 'activeStartedAt'},
    {'1': 'from_program', '3': 9, '4': 1, '5': 8, '10': 'fromProgram'},
    {'1': 'closed', '3': 10, '4': 1, '5': 8, '10': 'closed'},
  ],
};

/// Descriptor for `WorkoutView`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutViewDescriptor = $convert.base64Decode(
    'CgtXb3Jrb3V0VmlldxIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIdCgpzdG'
    'FydF90aW1lGAMgASgDUglzdGFydFRpbWUSGQoIZW5kX3RpbWUYBCABKANSB2VuZFRpbWUSHQoK'
    'c2Vzc2lvbl9pZBgFIAEoCVIJc2Vzc2lvbklkEi0KBmJsb2NrcxgGIAMoCzIVLndvcmtvdXQudj'
    'EuQmxvY2tWaWV3UgZibG9ja3MSIgoNYWN0aXZlX3NldF9pZBgHIAEoCVILYWN0aXZlU2V0SWQS'
    'KgoRYWN0aXZlX3N0YXJ0ZWRfYXQYCCABKANSD2FjdGl2ZVN0YXJ0ZWRBdBIhCgxmcm9tX3Byb2'
    'dyYW0YCSABKAhSC2Zyb21Qcm9ncmFtEhYKBmNsb3NlZBgKIAEoCFIGY2xvc2Vk');

@$core.Deprecated('Use blockPlanDescriptor instead')
const BlockPlan$json = {
  '1': 'BlockPlan',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'interleave_warmups',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'rest_config',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
    {
      '1': 'sets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SetPlan',
      '10': 'sets'
    },
  ],
};

/// Descriptor for `BlockPlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockPlanDescriptor = $convert.base64Decode(
    'CglCbG9ja1BsYW4SEgoEbmFtZRgBIAEoCVIEbmFtZRItChJpbnRlcmxlYXZlX3dhcm11cHMYAi'
    'ABKAhSEWludGVybGVhdmVXYXJtdXBzEjcKC3Jlc3RfY29uZmlnGAMgASgLMhYud29ya291dC52'
    'MS5SZXN0Q29uZmlnUgpyZXN0Q29uZmlnEicKBHNldHMYBCADKAsyEy53b3Jrb3V0LnYxLlNldF'
    'BsYW5SBHNldHM=');

@$core.Deprecated('Use setPlanDescriptor instead')
const SetPlan$json = {
  '1': 'SetPlan',
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
      '1': 'role',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.SetRole',
      '10': 'role'
    },
    {
      '1': 'target',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'target'
    },
    {'1': 'is_amrap', '3': 4, '4': 1, '5': 8, '10': 'isAmrap'},
    {'1': 'instruction', '3': 5, '4': 1, '5': 9, '10': 'instruction'},
    {
      '1': 'counts_toward_program',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'countsTowardProgram'
    },
    {'1': 'slot_key', '3': 7, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'client_id', '3': 8, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `SetPlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPlanDescriptor = $convert.base64Decode(
    'CgdTZXRQbGFuEjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC52MS5FeGVyY2lzZVIIZXhlcm'
    'Npc2USJwoEcm9sZRgCIAEoDjITLndvcmtvdXQudjEuU2V0Um9sZVIEcm9sZRIrCgZ0YXJnZXQY'
    'AyABKAsyEy53b3Jrb3V0LnYxLk1lYXN1cmVSBnRhcmdldBIZCghpc19hbXJhcBgEIAEoCFIHaX'
    'NBbXJhcBIgCgtpbnN0cnVjdGlvbhgFIAEoCVILaW5zdHJ1Y3Rpb24SMgoVY291bnRzX3Rvd2Fy'
    'ZF9wcm9ncmFtGAYgASgIUhNjb3VudHNUb3dhcmRQcm9ncmFtEhkKCHNsb3Rfa2V5GAcgASgJUg'
    'dzbG90S2V5EhsKCWNsaWVudF9pZBgIIAEoCVIIY2xpZW50SWQ=');

@$core.Deprecated('Use editTargetDescriptor instead')
const EditTarget$json = {
  '1': 'EditTarget',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {
      '1': 'target',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'target'
    },
  ],
};

/// Descriptor for `EditTarget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editTargetDescriptor = $convert.base64Decode(
    'CgpFZGl0VGFyZ2V0EhUKBnNldF9pZBgBIAEoCVIFc2V0SWQSKwoGdGFyZ2V0GAIgASgLMhMud2'
    '9ya291dC52MS5NZWFzdXJlUgZ0YXJnZXQ=');

@$core.Deprecated('Use addSetOpDescriptor instead')
const AddSetOp$json = {
  '1': 'AddSetOp',
  '2': [
    {'1': 'block_id', '3': 1, '4': 1, '5': 9, '10': 'blockId'},
    {
      '1': 'set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SetPlan',
      '10': 'set'
    },
  ],
};

/// Descriptor for `AddSetOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addSetOpDescriptor = $convert.base64Decode(
    'CghBZGRTZXRPcBIZCghibG9ja19pZBgBIAEoCVIHYmxvY2tJZBIlCgNzZXQYAiABKAsyEy53b3'
    'Jrb3V0LnYxLlNldFBsYW5SA3NldA==');

@$core.Deprecated('Use removeSetOpDescriptor instead')
const RemoveSetOp$json = {
  '1': 'RemoveSetOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
  ],
};

/// Descriptor for `RemoveSetOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeSetOpDescriptor =
    $convert.base64Decode('CgtSZW1vdmVTZXRPcBIVCgZzZXRfaWQYASABKAlSBXNldElk');

@$core.Deprecated('Use skipSetOpDescriptor instead')
const SkipSetOp$json = {
  '1': 'SkipSetOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'skipped', '3': 2, '4': 1, '5': 8, '10': 'skipped'},
  ],
};

/// Descriptor for `SkipSetOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skipSetOpDescriptor = $convert.base64Decode(
    'CglTa2lwU2V0T3ASFQoGc2V0X2lkGAEgASgJUgVzZXRJZBIYCgdza2lwcGVkGAIgASgIUgdza2'
    'lwcGVk');

@$core.Deprecated('Use startSetOpDescriptor instead')
const StartSetOp$json = {
  '1': 'StartSetOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
  ],
};

/// Descriptor for `StartSetOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetOpDescriptor = $convert.base64Decode(
    'CgpTdGFydFNldE9wEhUKBnNldF9pZBgBIAEoCVIFc2V0SWQSDgoCYXQYAiABKANSAmF0');

@$core.Deprecated('Use logSetOpDescriptor instead')
const LogSetOp$json = {
  '1': 'LogSetOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {
      '1': 'result',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'result'
    },
    {'1': 'performed_at', '3': 3, '4': 1, '5': 3, '10': 'performedAt'},
  ],
};

/// Descriptor for `LogSetOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logSetOpDescriptor = $convert.base64Decode(
    'CghMb2dTZXRPcBIVCgZzZXRfaWQYASABKAlSBXNldElkEisKBnJlc3VsdBgCIAEoCzITLndvcm'
    'tvdXQudjEuTWVhc3VyZVIGcmVzdWx0EiEKDHBlcmZvcm1lZF9hdBgDIAEoA1ILcGVyZm9ybWVk'
    'QXQ=');

@$core.Deprecated('Use correctEntryOpDescriptor instead')
const CorrectEntryOp$json = {
  '1': 'CorrectEntryOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {
      '1': 'result',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Measure',
      '10': 'result'
    },
    {'1': 'performed_at', '3': 3, '4': 1, '5': 3, '10': 'performedAt'},
  ],
};

/// Descriptor for `CorrectEntryOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List correctEntryOpDescriptor = $convert.base64Decode(
    'Cg5Db3JyZWN0RW50cnlPcBIVCgZzZXRfaWQYASABKAlSBXNldElkEisKBnJlc3VsdBgCIAEoCz'
    'ITLndvcmtvdXQudjEuTWVhc3VyZVIGcmVzdWx0EiEKDHBlcmZvcm1lZF9hdBgDIAEoA1ILcGVy'
    'Zm9ybWVkQXQ=');

@$core.Deprecated('Use deleteEntryOpDescriptor instead')
const DeleteEntryOp$json = {
  '1': 'DeleteEntryOp',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
  ],
};

/// Descriptor for `DeleteEntryOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteEntryOpDescriptor = $convert
    .base64Decode('Cg1EZWxldGVFbnRyeU9wEhUKBnNldF9pZBgBIAEoCVIFc2V0SWQ=');

@$core.Deprecated('Use reorderBlocksOpDescriptor instead')
const ReorderBlocksOp$json = {
  '1': 'ReorderBlocksOp',
  '2': [
    {'1': 'block_ids', '3': 1, '4': 3, '5': 9, '10': 'blockIds'},
  ],
};

/// Descriptor for `ReorderBlocksOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderBlocksOpDescriptor = $convert.base64Decode(
    'Cg9SZW9yZGVyQmxvY2tzT3ASGwoJYmxvY2tfaWRzGAEgAygJUghibG9ja0lkcw==');

@$core.Deprecated('Use addBlockOpDescriptor instead')
const AddBlockOp$json = {
  '1': 'AddBlockOp',
  '2': [
    {
      '1': 'block',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.BlockPlan',
      '10': 'block'
    },
  ],
};

/// Descriptor for `AddBlockOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addBlockOpDescriptor = $convert.base64Decode(
    'CgpBZGRCbG9ja09wEisKBWJsb2NrGAEgASgLMhUud29ya291dC52MS5CbG9ja1BsYW5SBWJsb2'
    'Nr');

@$core.Deprecated('Use workoutOpDescriptor instead')
const WorkoutOp$json = {
  '1': 'WorkoutOp',
  '2': [
    {
      '1': 'edit_target',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.EditTarget',
      '9': 0,
      '10': 'editTarget'
    },
    {
      '1': 'add_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AddSetOp',
      '9': 0,
      '10': 'addSet'
    },
    {
      '1': 'remove_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RemoveSetOp',
      '9': 0,
      '10': 'removeSet'
    },
    {
      '1': 'skip_set',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SkipSetOp',
      '9': 0,
      '10': 'skipSet'
    },
    {
      '1': 'start_set',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartSetOp',
      '9': 0,
      '10': 'startSet'
    },
    {
      '1': 'log_set',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.LogSetOp',
      '9': 0,
      '10': 'logSet'
    },
    {
      '1': 'correct_entry',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CorrectEntryOp',
      '9': 0,
      '10': 'correctEntry'
    },
    {
      '1': 'delete_entry',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.DeleteEntryOp',
      '9': 0,
      '10': 'deleteEntry'
    },
    {
      '1': 'reorder_blocks',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ReorderBlocksOp',
      '9': 0,
      '10': 'reorderBlocks'
    },
    {
      '1': 'add_block',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AddBlockOp',
      '9': 0,
      '10': 'addBlock'
    },
  ],
  '8': [
    {'1': 'op'},
  ],
};

/// Descriptor for `WorkoutOp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutOpDescriptor = $convert.base64Decode(
    'CglXb3Jrb3V0T3ASOQoLZWRpdF90YXJnZXQYASABKAsyFi53b3Jrb3V0LnYxLkVkaXRUYXJnZX'
    'RIAFIKZWRpdFRhcmdldBIvCgdhZGRfc2V0GAIgASgLMhQud29ya291dC52MS5BZGRTZXRPcEgA'
    'UgZhZGRTZXQSOAoKcmVtb3ZlX3NldBgDIAEoCzIXLndvcmtvdXQudjEuUmVtb3ZlU2V0T3BIAF'
    'IJcmVtb3ZlU2V0EjIKCHNraXBfc2V0GAQgASgLMhUud29ya291dC52MS5Ta2lwU2V0T3BIAFIH'
    'c2tpcFNldBI1CglzdGFydF9zZXQYBSABKAsyFi53b3Jrb3V0LnYxLlN0YXJ0U2V0T3BIAFIIc3'
    'RhcnRTZXQSLwoHbG9nX3NldBgGIAEoCzIULndvcmtvdXQudjEuTG9nU2V0T3BIAFIGbG9nU2V0'
    'EkEKDWNvcnJlY3RfZW50cnkYByABKAsyGi53b3Jrb3V0LnYxLkNvcnJlY3RFbnRyeU9wSABSDG'
    'NvcnJlY3RFbnRyeRI+CgxkZWxldGVfZW50cnkYCCABKAsyGS53b3Jrb3V0LnYxLkRlbGV0ZUVu'
    'dHJ5T3BIAFILZGVsZXRlRW50cnkSRAoOcmVvcmRlcl9ibG9ja3MYCSABKAsyGy53b3Jrb3V0Ln'
    'YxLlJlb3JkZXJCbG9ja3NPcEgAUg1yZW9yZGVyQmxvY2tzEjUKCWFkZF9ibG9jaxgKIAEoCzIW'
    'LndvcmtvdXQudjEuQWRkQmxvY2tPcEgAUghhZGRCbG9ja0IECgJvcA==');

@$core.Deprecated('Use createWorkoutRequestDescriptor instead')
const CreateWorkoutRequest$json = {
  '1': 'CreateWorkoutRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'blocks',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.BlockPlan',
      '10': 'blocks'
    },
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'from_program', '3': 4, '4': 1, '5': 8, '10': 'fromProgram'},
  ],
};

/// Descriptor for `CreateWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createWorkoutRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVXb3Jrb3V0UmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEi0KBmJsb2NrcxgCIA'
    'MoCzIVLndvcmtvdXQudjEuQmxvY2tQbGFuUgZibG9ja3MSHQoKc3RhcnRlZF9hdBgDIAEoA1IJ'
    'c3RhcnRlZEF0EiEKDGZyb21fcHJvZ3JhbRgEIAEoCFILZnJvbVByb2dyYW0=');

@$core.Deprecated('Use mutateWorkoutRequestDescriptor instead')
const MutateWorkoutRequest$json = {
  '1': 'MutateWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'ops',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutOp',
      '10': 'ops'
    },
  ],
};

/// Descriptor for `MutateWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mutateWorkoutRequestDescriptor = $convert.base64Decode(
    'ChRNdXRhdGVXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSJw'
    'oDb3BzGAIgAygLMhUud29ya291dC52MS5Xb3Jrb3V0T3BSA29wcw==');

@$core.Deprecated('Use getWorkoutV2RequestDescriptor instead')
const GetWorkoutV2Request$json = {
  '1': 'GetWorkoutV2Request',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `GetWorkoutV2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutV2RequestDescriptor = $convert.base64Decode(
    'ChNHZXRXb3Jrb3V0VjJSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZA==');

@$core.Deprecated('Use closeWorkoutRequestDescriptor instead')
const CloseWorkoutRequest$json = {
  '1': 'CloseWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'ended_at', '3': 2, '4': 1, '5': 3, '10': 'endedAt'},
  ],
};

/// Descriptor for `CloseWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNDbG9zZVdvcmtvdXRSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIZCg'
    'hlbmRlZF9hdBgCIAEoA1IHZW5kZWRBdA==');

@$core.Deprecated('Use closeWorkoutResponseDescriptor instead')
const CloseWorkoutResponse$json = {
  '1': 'CloseWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutView',
      '10': 'workout'
    },
    {
      '1': 'changes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgressionChange',
      '10': 'changes'
    },
  ],
};

/// Descriptor for `CloseWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeWorkoutResponseDescriptor = $convert.base64Decode(
    'ChRDbG9zZVdvcmtvdXRSZXNwb25zZRIxCgd3b3Jrb3V0GAEgASgLMhcud29ya291dC52MS5Xb3'
    'Jrb3V0Vmlld1IHd29ya291dBI3CgdjaGFuZ2VzGAIgAygLMh0ud29ya291dC52MS5Qcm9ncmVz'
    'c2lvbkNoYW5nZVIHY2hhbmdlcw==');

@$core.Deprecated('Use progressionChangeDescriptor instead')
const ProgressionChange$json = {
  '1': 'ProgressionChange',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'slot_key', '3': 2, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'from_weight', '3': 4, '4': 1, '5': 1, '10': 'fromWeight'},
    {'1': 'to_weight', '3': 5, '4': 1, '5': 1, '10': 'toWeight'},
    {'1': 'headline', '3': 6, '4': 1, '5': 9, '10': 'headline'},
  ],
};

/// Descriptor for `ProgressionChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List progressionChangeDescriptor = $convert.base64Decode(
    'ChFQcm9ncmVzc2lvbkNoYW5nZRIwCghleGVyY2lzZRgBIAEoDjIULndvcmtvdXQudjEuRXhlcm'
    'Npc2VSCGV4ZXJjaXNlEhkKCHNsb3Rfa2V5GAIgASgJUgdzbG90S2V5EhYKBnJlYXNvbhgDIAEo'
    'CVIGcmVhc29uEh8KC2Zyb21fd2VpZ2h0GAQgASgBUgpmcm9tV2VpZ2h0EhsKCXRvX3dlaWdodB'
    'gFIAEoAVIIdG9XZWlnaHQSGgoIaGVhZGxpbmUYBiABKAlSCGhlYWRsaW5l');

@$core.Deprecated('Use getProgressionHistoryRequestDescriptor instead')
const GetProgressionHistoryRequest$json = {
  '1': 'GetProgressionHistoryRequest',
  '2': [
    {'1': 'slot_key', '3': 1, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `GetProgressionHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgressionHistoryRequestDescriptor =
    $convert.base64Decode(
        'ChxHZXRQcm9ncmVzc2lvbkhpc3RvcnlSZXF1ZXN0EhkKCHNsb3Rfa2V5GAEgASgJUgdzbG90S2'
        'V5EhQKBWxpbWl0GAIgASgFUgVsaW1pdA==');

@$core.Deprecated('Use progressionHistoryEntryDescriptor instead')
const ProgressionHistoryEntry$json = {
  '1': 'ProgressionHistoryEntry',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
    {
      '1': 'exercise',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'slot_key', '3': 4, '4': 1, '5': 9, '10': 'slotKey'},
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'from_weight', '3': 6, '4': 1, '5': 1, '10': 'fromWeight'},
    {'1': 'to_weight', '3': 7, '4': 1, '5': 1, '10': 'toWeight'},
  ],
};

/// Descriptor for `ProgressionHistoryEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List progressionHistoryEntryDescriptor = $convert.base64Decode(
    'ChdQcm9ncmVzc2lvbkhpc3RvcnlFbnRyeRIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SW'
    'QSDgoCYXQYAiABKANSAmF0EjAKCGV4ZXJjaXNlGAMgASgOMhQud29ya291dC52MS5FeGVyY2lz'
    'ZVIIZXhlcmNpc2USGQoIc2xvdF9rZXkYBCABKAlSB3Nsb3RLZXkSFgoGcmVhc29uGAUgASgJUg'
    'ZyZWFzb24SHwoLZnJvbV93ZWlnaHQYBiABKAFSCmZyb21XZWlnaHQSGwoJdG9fd2VpZ2h0GAcg'
    'ASgBUgh0b1dlaWdodA==');

@$core.Deprecated('Use getProgressionHistoryResponseDescriptor instead')
const GetProgressionHistoryResponse$json = {
  '1': 'GetProgressionHistoryResponse',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProgressionHistoryEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `GetProgressionHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProgressionHistoryResponseDescriptor =
    $convert.base64Decode(
        'Ch1HZXRQcm9ncmVzc2lvbkhpc3RvcnlSZXNwb25zZRI9CgdlbnRyaWVzGAEgAygLMiMud29ya2'
        '91dC52MS5Qcm9ncmVzc2lvbkhpc3RvcnlFbnRyeVIHZW50cmllcw==');
