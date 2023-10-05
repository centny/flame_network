//
//  Generated code. Do not modify.
//  source: server.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class RequestID extends $pb.GeneratedMessage {
  factory RequestID({
    $core.String? uuid,
  }) {
    final $result = create();
    if (uuid != null) {
      $result.uuid = uuid;
    }
    return $result;
  }
  RequestID._() : super();
  factory RequestID.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RequestID.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RequestID', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uuid')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RequestID clone() => RequestID()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RequestID copyWith(void Function(RequestID) updates) => super.copyWith((message) => updates(message as RequestID)) as RequestID;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestID create() => RequestID._();
  RequestID createEmptyInstance() => create();
  static $pb.PbList<RequestID> createRepeated() => $pb.PbList<RequestID>();
  @$core.pragma('dart2js:noInline')
  static RequestID getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RequestID>(create);
  static RequestID? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uuid => $_getSZ(0);
  @$pb.TagNumber(1)
  set uuid($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUuid() => $_has(0);
  @$pb.TagNumber(1)
  void clearUuid() => clearField(1);
}

class SyncComponent extends $pb.GeneratedMessage {
  factory SyncComponent({
    $core.String? type,
    $core.String? uuid,
    $core.bool? removed,
    $core.Iterable<$core.double>? position,
    $core.Iterable<$core.double>? size,
    $core.Iterable<$core.double>? scale,
    $core.double? angle,
  }) {
    final $result = create();
    if (type != null) {
      $result.type = type;
    }
    if (uuid != null) {
      $result.uuid = uuid;
    }
    if (removed != null) {
      $result.removed = removed;
    }
    if (position != null) {
      $result.position.addAll(position);
    }
    if (size != null) {
      $result.size.addAll(size);
    }
    if (scale != null) {
      $result.scale.addAll(scale);
    }
    if (angle != null) {
      $result.angle = angle;
    }
    return $result;
  }
  SyncComponent._() : super();
  factory SyncComponent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncComponent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncComponent', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'uuid')
    ..aOB(3, _omitFieldNames ? '' : 'removed')
    ..p<$core.double>(4, _omitFieldNames ? '' : 'position', $pb.PbFieldType.KD)
    ..p<$core.double>(5, _omitFieldNames ? '' : 'size', $pb.PbFieldType.KD)
    ..p<$core.double>(6, _omitFieldNames ? '' : 'scale', $pb.PbFieldType.KD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'angle', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncComponent clone() => SyncComponent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncComponent copyWith(void Function(SyncComponent) updates) => super.copyWith((message) => updates(message as SyncComponent)) as SyncComponent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncComponent create() => SyncComponent._();
  SyncComponent createEmptyInstance() => create();
  static $pb.PbList<SyncComponent> createRepeated() => $pb.PbList<SyncComponent>();
  @$core.pragma('dart2js:noInline')
  static SyncComponent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncComponent>(create);
  static SyncComponent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get uuid => $_getSZ(1);
  @$pb.TagNumber(2)
  set uuid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUuid() => $_has(1);
  @$pb.TagNumber(2)
  void clearUuid() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get removed => $_getBF(2);
  @$pb.TagNumber(3)
  set removed($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRemoved() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoved() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.double> get position => $_getList(3);

  @$pb.TagNumber(5)
  $core.List<$core.double> get size => $_getList(4);

  @$pb.TagNumber(6)
  $core.List<$core.double> get scale => $_getList(5);

  @$pb.TagNumber(7)
  $core.double get angle => $_getN(6);
  @$pb.TagNumber(7)
  set angle($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasAngle() => $_has(6);
  @$pb.TagNumber(7)
  void clearAngle() => clearField(7);
}

class SyncArg extends $pb.GeneratedMessage {
  factory SyncArg({
    RequestID? id,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    return $result;
  }
  SyncArg._() : super();
  factory SyncArg.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncArg.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncArg', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncArg clone() => SyncArg()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncArg copyWith(void Function(SyncArg) updates) => super.copyWith((message) => updates(message as SyncArg)) as SyncArg;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncArg create() => SyncArg._();
  SyncArg createEmptyInstance() => create();
  static $pb.PbList<SyncArg> createRepeated() => $pb.PbList<SyncArg>();
  @$core.pragma('dart2js:noInline')
  static SyncArg getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncArg>(create);
  static SyncArg? _defaultInstance;

  @$pb.TagNumber(1)
  RequestID get id => $_getN(0);
  @$pb.TagNumber(1)
  set id(RequestID v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);
  @$pb.TagNumber(1)
  RequestID ensureId() => $_ensure(0);
}

class SyncData extends $pb.GeneratedMessage {
  factory SyncData({
    RequestID? id,
    $core.Iterable<SyncComponent>? components,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (components != null) {
      $result.components.addAll(components);
    }
    return $result;
  }
  SyncData._() : super();
  factory SyncData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncData', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..pc<SyncComponent>(3, _omitFieldNames ? '' : 'components', $pb.PbFieldType.PM, subBuilder: SyncComponent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncData clone() => SyncData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncData copyWith(void Function(SyncData) updates) => super.copyWith((message) => updates(message as SyncData)) as SyncData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncData create() => SyncData._();
  SyncData createEmptyInstance() => create();
  static $pb.PbList<SyncData> createRepeated() => $pb.PbList<SyncData>();
  @$core.pragma('dart2js:noInline')
  static SyncData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncData>(create);
  static SyncData? _defaultInstance;

  @$pb.TagNumber(1)
  RequestID get id => $_getN(0);
  @$pb.TagNumber(1)
  set id(RequestID v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);
  @$pb.TagNumber(1)
  RequestID ensureId() => $_ensure(0);

  @$pb.TagNumber(3)
  $core.List<SyncComponent> get components => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
