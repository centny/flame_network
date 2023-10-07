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

import 'package:fixnum/fixnum.dart' as $fixnum;
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

class PingArg extends $pb.GeneratedMessage {
  factory PingArg({
    RequestID? id,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    return $result;
  }
  PingArg._() : super();
  factory PingArg.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PingArg.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingArg', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PingArg clone() => PingArg()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PingArg copyWith(void Function(PingArg) updates) => super.copyWith((message) => updates(message as PingArg)) as PingArg;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingArg create() => PingArg._();
  PingArg createEmptyInstance() => create();
  static $pb.PbList<PingArg> createRepeated() => $pb.PbList<PingArg>();
  @$core.pragma('dart2js:noInline')
  static PingArg getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingArg>(create);
  static PingArg? _defaultInstance;

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

class PingResult extends $pb.GeneratedMessage {
  factory PingResult({
    RequestID? id,
    $fixnum.Int64? serverTime,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (serverTime != null) {
      $result.serverTime = serverTime;
    }
    return $result;
  }
  PingResult._() : super();
  factory PingResult.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PingResult.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingResult', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..aInt64(2, _omitFieldNames ? '' : 'serverTime', protoName: 'serverTime')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PingResult clone() => PingResult()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PingResult copyWith(void Function(PingResult) updates) => super.copyWith((message) => updates(message as PingResult)) as PingResult;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingResult create() => PingResult._();
  PingResult createEmptyInstance() => create();
  static $pb.PbList<PingResult> createRepeated() => $pb.PbList<PingResult>();
  @$core.pragma('dart2js:noInline')
  static PingResult getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingResult>(create);
  static PingResult? _defaultInstance;

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

  @$pb.TagNumber(2)
  $fixnum.Int64 get serverTime => $_getI64(1);
  @$pb.TagNumber(2)
  set serverTime($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasServerTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerTime() => clearField(2);
}

class SyncDataComponent extends $pb.GeneratedMessage {
  factory SyncDataComponent({
    $core.String? factoryType,
    $core.String? cid,
    $core.String? owner,
    $core.bool? removed,
    $core.String? props,
  }) {
    final $result = create();
    if (factoryType != null) {
      $result.factoryType = factoryType;
    }
    if (cid != null) {
      $result.cid = cid;
    }
    if (owner != null) {
      $result.owner = owner;
    }
    if (removed != null) {
      $result.removed = removed;
    }
    if (props != null) {
      $result.props = props;
    }
    return $result;
  }
  SyncDataComponent._() : super();
  factory SyncDataComponent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncDataComponent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncDataComponent', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'factoryType', protoName: 'factoryType')
    ..aOS(2, _omitFieldNames ? '' : 'cid')
    ..aOS(3, _omitFieldNames ? '' : 'owner')
    ..aOB(4, _omitFieldNames ? '' : 'removed')
    ..aOS(5, _omitFieldNames ? '' : 'props')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncDataComponent clone() => SyncDataComponent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncDataComponent copyWith(void Function(SyncDataComponent) updates) => super.copyWith((message) => updates(message as SyncDataComponent)) as SyncDataComponent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncDataComponent create() => SyncDataComponent._();
  SyncDataComponent createEmptyInstance() => create();
  static $pb.PbList<SyncDataComponent> createRepeated() => $pb.PbList<SyncDataComponent>();
  @$core.pragma('dart2js:noInline')
  static SyncDataComponent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncDataComponent>(create);
  static SyncDataComponent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get factoryType => $_getSZ(0);
  @$pb.TagNumber(1)
  set factoryType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFactoryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearFactoryType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get cid => $_getSZ(1);
  @$pb.TagNumber(2)
  set cid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get owner => $_getSZ(2);
  @$pb.TagNumber(3)
  set owner($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwner() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get removed => $_getBF(3);
  @$pb.TagNumber(4)
  set removed($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRemoved() => $_has(3);
  @$pb.TagNumber(4)
  void clearRemoved() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get props => $_getSZ(4);
  @$pb.TagNumber(5)
  set props($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasProps() => $_has(4);
  @$pb.TagNumber(5)
  void clearProps() => clearField(5);
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
    $core.String? group,
    $core.Iterable<SyncDataComponent>? components,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (group != null) {
      $result.group = group;
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
    ..aOS(2, _omitFieldNames ? '' : 'group')
    ..pc<SyncDataComponent>(3, _omitFieldNames ? '' : 'components', $pb.PbFieldType.PM, subBuilder: SyncDataComponent.create)
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

  @$pb.TagNumber(2)
  $core.String get group => $_getSZ(1);
  @$pb.TagNumber(2)
  set group($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasGroup() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroup() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<SyncDataComponent> get components => $_getList(2);
}

class CallArg extends $pb.GeneratedMessage {
  factory CallArg({
    RequestID? id,
    $core.String? cid,
    $core.String? name,
    $core.String? arg,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (cid != null) {
      $result.cid = cid;
    }
    if (name != null) {
      $result.name = name;
    }
    if (arg != null) {
      $result.arg = arg;
    }
    return $result;
  }
  CallArg._() : super();
  factory CallArg.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CallArg.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CallArg', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..aOS(2, _omitFieldNames ? '' : 'cid')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'arg')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CallArg clone() => CallArg()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CallArg copyWith(void Function(CallArg) updates) => super.copyWith((message) => updates(message as CallArg)) as CallArg;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CallArg create() => CallArg._();
  CallArg createEmptyInstance() => create();
  static $pb.PbList<CallArg> createRepeated() => $pb.PbList<CallArg>();
  @$core.pragma('dart2js:noInline')
  static CallArg getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CallArg>(create);
  static CallArg? _defaultInstance;

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

  @$pb.TagNumber(2)
  $core.String get cid => $_getSZ(1);
  @$pb.TagNumber(2)
  set cid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get arg => $_getSZ(3);
  @$pb.TagNumber(4)
  set arg($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasArg() => $_has(3);
  @$pb.TagNumber(4)
  void clearArg() => clearField(4);
}

class CallResult extends $pb.GeneratedMessage {
  factory CallResult({
    RequestID? id,
    $core.String? cid,
    $core.String? name,
    $core.String? result,
    $core.String? error,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (cid != null) {
      $result.cid = cid;
    }
    if (name != null) {
      $result.name = name;
    }
    if (result != null) {
      $result.result = result;
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  CallResult._() : super();
  factory CallResult.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CallResult.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CallResult', createEmptyInstance: create)
    ..aOM<RequestID>(1, _omitFieldNames ? '' : 'id', subBuilder: RequestID.create)
    ..aOS(2, _omitFieldNames ? '' : 'cid')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'result')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CallResult clone() => CallResult()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CallResult copyWith(void Function(CallResult) updates) => super.copyWith((message) => updates(message as CallResult)) as CallResult;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CallResult create() => CallResult._();
  CallResult createEmptyInstance() => create();
  static $pb.PbList<CallResult> createRepeated() => $pb.PbList<CallResult>();
  @$core.pragma('dart2js:noInline')
  static CallResult getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CallResult>(create);
  static CallResult? _defaultInstance;

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

  @$pb.TagNumber(2)
  $core.String get cid => $_getSZ(1);
  @$pb.TagNumber(2)
  set cid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get result => $_getSZ(3);
  @$pb.TagNumber(4)
  set result($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasResult() => $_has(3);
  @$pb.TagNumber(4)
  void clearResult() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => clearField(5);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
