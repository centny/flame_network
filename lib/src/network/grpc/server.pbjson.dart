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

@$core.Deprecated('Use syncDataComponentDescriptor instead')
const SyncDataComponent$json = {
  '1': 'SyncDataComponent',
  '2': [
    {'1': 'factory', '3': 1, '4': 1, '5': 9, '10': 'factory'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'removed', '3': 3, '4': 1, '5': 8, '10': 'removed'},
    {'1': 'props', '3': 4, '4': 1, '5': 9, '10': 'props'},
  ],
};

/// Descriptor for `SyncDataComponent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDataComponentDescriptor = $convert.base64Decode(
    'ChFTeW5jRGF0YUNvbXBvbmVudBIYCgdmYWN0b3J5GAEgASgJUgdmYWN0b3J5Eg4KAmlkGAIgAS'
    'gJUgJpZBIYCgdyZW1vdmVkGAMgASgIUgdyZW1vdmVkEhQKBXByb3BzGAQgASgJUgVwcm9wcw==');

@$core.Deprecated('Use syncArgDescriptor instead')
const SyncArg$json = {
  '1': 'SyncArg',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.RequestID', '10': 'id'},
  ],
};

/// Descriptor for `SyncArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncArgDescriptor = $convert.base64Decode(
    'CgdTeW5jQXJnEhoKAmlkGAEgASgLMgouUmVxdWVzdElEUgJpZA==');

@$core.Deprecated('Use syncDataDescriptor instead')
const SyncData$json = {
  '1': 'SyncData',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.RequestID', '10': 'id'},
    {'1': 'groupd', '3': 2, '4': 1, '5': 9, '10': 'groupd'},
    {'1': 'components', '3': 3, '4': 3, '5': 11, '6': '.SyncDataComponent', '10': 'components'},
  ],
};

/// Descriptor for `SyncData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDataDescriptor = $convert.base64Decode(
    'CghTeW5jRGF0YRIaCgJpZBgBIAEoCzIKLlJlcXVlc3RJRFICaWQSFgoGZ3JvdXBkGAIgASgJUg'
    'Zncm91cGQSMgoKY29tcG9uZW50cxgDIAMoCzISLlN5bmNEYXRhQ29tcG9uZW50Ugpjb21wb25l'
    'bnRz');

@$core.Deprecated('Use pingArgDescriptor instead')
const PingArg$json = {
  '1': 'PingArg',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.RequestID', '10': 'id'},
  ],
};

/// Descriptor for `PingArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingArgDescriptor = $convert.base64Decode(
    'CgdQaW5nQXJnEhoKAmlkGAEgASgLMgouUmVxdWVzdElEUgJpZA==');

@$core.Deprecated('Use pingResultDescriptor instead')
const PingResult$json = {
  '1': 'PingResult',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 11, '6': '.RequestID', '10': 'id'},
    {'1': 'serverTime', '3': 2, '4': 1, '5': 3, '10': 'serverTime'},
  ],
};

/// Descriptor for `PingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResultDescriptor = $convert.base64Decode(
    'CgpQaW5nUmVzdWx0EhoKAmlkGAEgASgLMgouUmVxdWVzdElEUgJpZBIeCgpzZXJ2ZXJUaW1lGA'
    'IgASgDUgpzZXJ2ZXJUaW1l');

