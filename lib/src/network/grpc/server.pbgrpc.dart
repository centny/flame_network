//
//  Generated code. Do not modify.
//  source: server.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'server.pb.dart' as $0;

export 'server.pb.dart';

@$pb.GrpcServiceName('Server')
class ServerClient extends $grpc.Client {
  static final _$remotePing = $grpc.ClientMethod<$0.PingArg, $0.PingResult>(
      '/Server/remotePing',
      ($0.PingArg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PingResult.fromBuffer(value));
  static final _$remoteSync = $grpc.ClientMethod<$0.SyncArg, $0.SyncData>(
      '/Server/remoteSync',
      ($0.SyncArg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SyncData.fromBuffer(value));
  static final _$remoteCall = $grpc.ClientMethod<$0.CallArg, $0.CallResult>(
      '/Server/remoteCall',
      ($0.CallArg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CallResult.fromBuffer(value));

  ServerClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.PingResult> remotePing($0.PingArg request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$remotePing, request, options: options);
  }

  $grpc.ResponseStream<$0.SyncData> remoteSync($0.SyncArg request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$remoteSync, $async.Stream.fromIterable([request]), options: options);
  }

  $grpc.ResponseFuture<$0.CallResult> remoteCall($0.CallArg request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$remoteCall, request, options: options);
  }
}

@$pb.GrpcServiceName('Server')
abstract class ServerServiceBase extends $grpc.Service {
  $core.String get $name => 'Server';

  ServerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.PingArg, $0.PingResult>(
        'remotePing',
        remotePing_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PingArg.fromBuffer(value),
        ($0.PingResult value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncArg, $0.SyncData>(
        'remoteSync',
        remoteSync_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.SyncArg.fromBuffer(value),
        ($0.SyncData value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CallArg, $0.CallResult>(
        'remoteCall',
        remoteCall_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CallArg.fromBuffer(value),
        ($0.CallResult value) => value.writeToBuffer()));
  }

  $async.Future<$0.PingResult> remotePing_Pre($grpc.ServiceCall call, $async.Future<$0.PingArg> request) async {
    return remotePing(call, await request);
  }

  $async.Stream<$0.SyncData> remoteSync_Pre($grpc.ServiceCall call, $async.Future<$0.SyncArg> request) async* {
    yield* remoteSync(call, await request);
  }

  $async.Future<$0.CallResult> remoteCall_Pre($grpc.ServiceCall call, $async.Future<$0.CallArg> request) async {
    return remoteCall(call, await request);
  }

  $async.Future<$0.PingResult> remotePing($grpc.ServiceCall call, $0.PingArg request);
  $async.Stream<$0.SyncData> remoteSync($grpc.ServiceCall call, $0.SyncArg request);
  $async.Future<$0.CallResult> remoteCall($grpc.ServiceCall call, $0.CallArg request);
}
