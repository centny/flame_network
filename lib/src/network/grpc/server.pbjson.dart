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

@$core.Deprecated('Use syncComponentDescriptor instead')
const SyncComponent$json = {
  '1': 'SyncComponent',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'uuid', '3': 2, '4': 1, '5': 9, '10': 'uuid'},
    {'1': 'removed', '3': 3, '4': 1, '5': 8, '10': 'removed'},
    {'1': 'position', '3': 4, '4': 3, '5': 1, '10': 'position'},
    {'1': 'size', '3': 5, '4': 3, '5': 1, '10': 'size'},
    {'1': 'scale', '3': 6, '4': 3, '5': 1, '10': 'scale'},
    {'1': 'angle', '3': 7, '4': 1, '5': 1, '10': 'angle'},
  ],
};

/// Descriptor for `SyncComponent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncComponentDescriptor = $convert.base64Decode(
    'Cg1TeW5jQ29tcG9uZW50EhIKBHR5cGUYASABKAlSBHR5cGUSEgoEdXVpZBgCIAEoCVIEdXVpZB'
    'IYCgdyZW1vdmVkGAMgASgIUgdyZW1vdmVkEhoKCHBvc2l0aW9uGAQgAygBUghwb3NpdGlvbhIS'
    'CgRzaXplGAUgAygBUgRzaXplEhQKBXNjYWxlGAYgAygBUgVzY2FsZRIUCgVhbmdsZRgHIAEoAV'
    'IFYW5nbGU=');

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
    {'1': 'components', '3': 3, '4': 3, '5': 11, '6': '.SyncComponent', '10': 'components'},
  ],
};

/// Descriptor for `SyncData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncDataDescriptor = $convert.base64Decode(
    'CghTeW5jRGF0YRIaCgJpZBgBIAEoCzIKLlJlcXVlc3RJRFICaWQSLgoKY29tcG9uZW50cxgDIA'
    'MoCzIOLlN5bmNDb21wb25lbnRSCmNvbXBvbmVudHM=');

