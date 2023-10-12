//
//  Generated code. Do not modify.
//  source: server.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use requestIDDescriptor instead')
const RequestID$json = {
  '1': 'RequestID',
  '2': [
    {'1': 'uuid', '3': 1, '4': 1, '5': 9, '10': 'uuid'},
  ],
};

/// Descriptor for `RequestID`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestIDDescriptor = $convert.base64Decode(
    'CglSZXF1ZXN0SUQSEgoEdXVpZBgBIAEoCVIEdXVpZA==');

@$core.Deprecated('Use pingArgDescriptor instead')
const PingArg$json = {
  '1': 'PingArg',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
  ],
};

/// Descriptor for `PingArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingArgDescriptor = $convert.base64Decode(
    'CgdQaW5nQXJnEh8KAmlkGAEgASgLMg8uZ3JwYy5SZXF1ZXN0SURSAmlk');

@$core.Deprecated('Use pingResultDescriptor instead')
const PingResult$json = {
  '1': 'PingResult',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
    {'1': 'serverTime', '3': 2, '4': 1, '5': 3, '10': 'serverTime'},
  ],
};

/// Descriptor for `PingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResultDescriptor = $convert.base64Decode(
    'CgpQaW5nUmVzdWx0Eh8KAmlkGAEgASgLMg8uZ3JwYy5SZXF1ZXN0SURSAmlkEh4KCnNlcnZlcl'
    'RpbWUYAiABKANSCnNlcnZlclRpbWU=');

@$core.Deprecated('Use syncDataComponentDescriptor instead')
const SyncDataComponent$json = {
  '1': 'SyncDataComponent',
  '2': [
    {'1': 'factoryType', '3': 1, '4': 1, '5': 9, '10': 'factoryType'},
    {'1': 'cid', '3': 2, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'owner', '3': 3, '4': 1, '5': 9, '10': 'owner'},
    {'1': 'removed', '3': 4, '4': 1, '5': 8, '10': 'removed'},
    {'1': 'props', '3': 5, '4': 1, '5': 9, '10': 'props'},
  ],
};

/// Descriptor for `SyncDataComponent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDataComponentDescriptor = $convert.base64Decode(
    'ChFTeW5jRGF0YUNvbXBvbmVudBIgCgtmYWN0b3J5VHlwZRgBIAEoCVILZmFjdG9yeVR5cGUSEA'
    'oDY2lkGAIgASgJUgNjaWQSFAoFb3duZXIYAyABKAlSBW93bmVyEhgKB3JlbW92ZWQYBCABKAhS'
    'B3JlbW92ZWQSFAoFcHJvcHMYBSABKAlSBXByb3Bz');

@$core.Deprecated('Use syncArgDescriptor instead')
const SyncArg$json = {
  '1': 'SyncArg',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
  ],
};

/// Descriptor for `SyncArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncArgDescriptor = $convert.base64Decode(
    'CgdTeW5jQXJnEh8KAmlkGAEgASgLMg8uZ3JwYy5SZXF1ZXN0SURSAmlk');

@$core.Deprecated('Use syncDataDescriptor instead')
const SyncData$json = {
  '1': 'SyncData',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
    {'1': 'group', '3': 2, '4': 1, '5': 9, '10': 'group'},
    {'1': 'whole', '3': 3, '4': 1, '5': 8, '10': 'whole'},
    {'1': 'components', '3': 4, '4': 3, '5': 11, '6': '.grpc.SyncDataComponent', '10': 'components'},
  ],
};

/// Descriptor for `SyncData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDataDescriptor = $convert.base64Decode(
    'CghTeW5jRGF0YRIfCgJpZBgBIAEoCzIPLmdycGMuUmVxdWVzdElEUgJpZBIUCgVncm91cBgCIA'
    'EoCVIFZ3JvdXASFAoFd2hvbGUYAyABKAhSBXdob2xlEjcKCmNvbXBvbmVudHMYBCADKAsyFy5n'
    'cnBjLlN5bmNEYXRhQ29tcG9uZW50Ugpjb21wb25lbnRz');

@$core.Deprecated('Use callArgDescriptor instead')
const CallArg$json = {
  '1': 'CallArg',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
    {'1': 'cid', '3': 2, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'arg', '3': 4, '4': 1, '5': 9, '10': 'arg'},
  ],
};

/// Descriptor for `CallArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List callArgDescriptor = $convert.base64Decode(
    'CgdDYWxsQXJnEh8KAmlkGAEgASgLMg8uZ3JwYy5SZXF1ZXN0SURSAmlkEhAKA2NpZBgCIAEoCV'
    'IDY2lkEhIKBG5hbWUYAyABKAlSBG5hbWUSEAoDYXJnGAQgASgJUgNhcmc=');

@$core.Deprecated('Use callResultDescriptor instead')
const CallResult$json = {
  '1': 'CallResult',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.grpc.RequestID', '10': 'id'},
    {'1': 'cid', '3': 2, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'result', '3': 4, '4': 1, '5': 9, '10': 'result'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `CallResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List callResultDescriptor = $convert.base64Decode(
    'CgpDYWxsUmVzdWx0Eh8KAmlkGAEgASgLMg8uZ3JwYy5SZXF1ZXN0SURSAmlkEhAKA2NpZBgCIA'
    'EoCVIDY2lkEhIKBG5hbWUYAyABKAlSBG5hbWUSFgoGcmVzdWx0GAQgASgJUgZyZXN1bHQSFAoF'
    'ZXJyb3IYBSABKAlSBWVycm9y');

