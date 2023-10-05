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
  static final _$callPing = $grpc.ClientMethod<$0.PingArg, $0.PingResult>(
      '/Server/CallPing',
      ($0.PingArg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PingResult.fromBuffer(value));
  static final _$callMonitorSync = $grpc.ClientMethod<$0.SyncArg, $0.SyncData>(
      '/Server/CallMonitorSync',
      ($0.SyncArg value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SyncData.fromBuffer(value));

  ServerClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.PingResult> callPing($0.PingArg request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$callPing, request, options: options);
  }

  $grpc.ResponseStream<$0.SyncData> callMonitorSync($0.SyncArg request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$callMonitorSync, $async.Stream.fromIterable([request]), options: options);
  }
}

@$pb.GrpcServiceName('Server')
abstract class ServerServiceBase extends $grpc.Service {
  $core.String get $name => 'Server';

  ServerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.PingArg, $0.PingResult>(
        'CallPing',
        callPing_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PingArg.fromBuffer(value),
        ($0.PingResult value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncArg, $0.SyncData>(
        'CallMonitorSync',
        callMonitorSync_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.SyncArg.fromBuffer(value),
        ($0.SyncData value) => value.writeToBuffer()));
  }

  $async.Future<$0.PingResult> callPing_Pre($grpc.ServiceCall call, $async.Future<$0.PingArg> request) async {
    return callPing(call, await request);
  }

  $async.Stream<$0.SyncData> callMonitorSync_Pre($grpc.ServiceCall call, $async.Future<$0.SyncArg> request) async* {
    yield* callMonitorSync(call, await request);
  }

  $async.Future<$0.PingResult> callPing($grpc.ServiceCall call, $0.PingArg request);
  $async.Stream<$0.SyncData> callMonitorSync($grpc.ServiceCall call, $0.SyncArg request);
}
