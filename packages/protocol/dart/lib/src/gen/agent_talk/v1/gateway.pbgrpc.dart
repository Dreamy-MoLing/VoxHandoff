// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/gateway.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'gateway.pb.dart' as $0;

export 'gateway.pb.dart';

@$pb.GrpcServiceName('agent_talk.v1.GatewayControlService')
class GatewayControlServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  GatewayControlServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseStream<$0.ConnectClientResponse> connectClient(
    $async.Stream<$0.ConnectClientRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$connectClient, request, options: options);
  }

  $grpc.ResponseStream<$0.ConnectNodeResponse> connectNode(
    $async.Stream<$0.ConnectNodeRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$connectNode, request, options: options);
  }

  // method descriptors

  static final _$connectClient =
      $grpc.ClientMethod<$0.ConnectClientRequest, $0.ConnectClientResponse>(
          '/agent_talk.v1.GatewayControlService/ConnectClient',
          ($0.ConnectClientRequest value) => value.writeToBuffer(),
          $0.ConnectClientResponse.fromBuffer);
  static final _$connectNode =
      $grpc.ClientMethod<$0.ConnectNodeRequest, $0.ConnectNodeResponse>(
          '/agent_talk.v1.GatewayControlService/ConnectNode',
          ($0.ConnectNodeRequest value) => value.writeToBuffer(),
          $0.ConnectNodeResponse.fromBuffer);
}

@$pb.GrpcServiceName('agent_talk.v1.GatewayControlService')
abstract class GatewayControlServiceBase extends $grpc.Service {
  $core.String get $name => 'agent_talk.v1.GatewayControlService';

  GatewayControlServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.ConnectClientRequest, $0.ConnectClientResponse>(
            'ConnectClient',
            connectClient,
            true,
            true,
            ($core.List<$core.int> value) =>
                $0.ConnectClientRequest.fromBuffer(value),
            ($0.ConnectClientResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ConnectNodeRequest, $0.ConnectNodeResponse>(
            'ConnectNode',
            connectNode,
            true,
            true,
            ($core.List<$core.int> value) =>
                $0.ConnectNodeRequest.fromBuffer(value),
            ($0.ConnectNodeResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ConnectClientResponse> connectClient(
      $grpc.ServiceCall call, $async.Stream<$0.ConnectClientRequest> request);

  $async.Stream<$0.ConnectNodeResponse> connectNode(
      $grpc.ServiceCall call, $async.Stream<$0.ConnectNodeRequest> request);
}

@$pb.GrpcServiceName('agent_talk.v1.PairingService')
class PairingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PairingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.BeginPairingResponse> beginPairing(
    $0.BeginPairingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$beginPairing, request, options: options);
  }

  $grpc.ResponseFuture<$0.CompletePairingResponse> completePairing(
    $0.CompletePairingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completePairing, request, options: options);
  }

  $grpc.ResponseFuture<$0.RevokeDeviceResponse> revokeDevice(
    $0.RevokeDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$revokeDevice, request, options: options);
  }

  // method descriptors

  static final _$beginPairing =
      $grpc.ClientMethod<$0.BeginPairingRequest, $0.BeginPairingResponse>(
          '/agent_talk.v1.PairingService/BeginPairing',
          ($0.BeginPairingRequest value) => value.writeToBuffer(),
          $0.BeginPairingResponse.fromBuffer);
  static final _$completePairing =
      $grpc.ClientMethod<$0.CompletePairingRequest, $0.CompletePairingResponse>(
          '/agent_talk.v1.PairingService/CompletePairing',
          ($0.CompletePairingRequest value) => value.writeToBuffer(),
          $0.CompletePairingResponse.fromBuffer);
  static final _$revokeDevice =
      $grpc.ClientMethod<$0.RevokeDeviceRequest, $0.RevokeDeviceResponse>(
          '/agent_talk.v1.PairingService/RevokeDevice',
          ($0.RevokeDeviceRequest value) => value.writeToBuffer(),
          $0.RevokeDeviceResponse.fromBuffer);
}

@$pb.GrpcServiceName('agent_talk.v1.PairingService')
abstract class PairingServiceBase extends $grpc.Service {
  $core.String get $name => 'agent_talk.v1.PairingService';

  PairingServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.BeginPairingRequest, $0.BeginPairingResponse>(
            'BeginPairing',
            beginPairing_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.BeginPairingRequest.fromBuffer(value),
            ($0.BeginPairingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CompletePairingRequest,
            $0.CompletePairingResponse>(
        'CompletePairing',
        completePairing_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CompletePairingRequest.fromBuffer(value),
        ($0.CompletePairingResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RevokeDeviceRequest, $0.RevokeDeviceResponse>(
            'RevokeDevice',
            revokeDevice_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RevokeDeviceRequest.fromBuffer(value),
            ($0.RevokeDeviceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.BeginPairingResponse> beginPairing_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BeginPairingRequest> $request) async {
    return beginPairing($call, await $request);
  }

  $async.Future<$0.BeginPairingResponse> beginPairing(
      $grpc.ServiceCall call, $0.BeginPairingRequest request);

  $async.Future<$0.CompletePairingResponse> completePairing_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CompletePairingRequest> $request) async {
    return completePairing($call, await $request);
  }

  $async.Future<$0.CompletePairingResponse> completePairing(
      $grpc.ServiceCall call, $0.CompletePairingRequest request);

  $async.Future<$0.RevokeDeviceResponse> revokeDevice_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RevokeDeviceRequest> $request) async {
    return revokeDevice($call, await $request);
  }

  $async.Future<$0.RevokeDeviceResponse> revokeDevice(
      $grpc.ServiceCall call, $0.RevokeDeviceRequest request);
}
