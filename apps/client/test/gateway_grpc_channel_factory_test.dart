import 'dart:io';

import 'package:agent_talk_client/infrastructure/gateway/gateway_grpc_channel_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayGrpcChannelFactory', () {
    test(
      'uses TLS, system trust, hostname verification, and finite timeout',
      () async {
        final channel = GatewayGrpcChannelFactory().create(
          gatewayAudience: 'https://gateway.example:8443',
        );
        addTearDown(channel.shutdown);

        expect(channel.host, 'gateway.example');
        expect(channel.port, 8443);
        expect(channel.options.credentials.isSecure, isTrue);
        expect(channel.options.credentials.onBadCertificate, isNull);
        expect(channel.options.connectTimeout, const Duration(seconds: 10));
      },
    );

    test(
      'accepts an explicitly imported CA without a bad-certificate hook',
      () async {
        final certificate = await File(
          'test/fixtures/agent_talk_test_ca.pem',
        ).readAsBytes();
        final channel = GatewayGrpcChannelFactory().create(
          gatewayAudience: 'https://gateway.example',
          trustedRootCertificates: certificate,
        );
        addTearDown(channel.shutdown);

        expect(channel.options.credentials.isSecure, isTrue);
        expect(channel.options.credentials.onBadCertificate, isNull);
        expect(channel.options.credentials.securityContext, isNotNull);
      },
    );

    test('rejects malformed imported trust material before connecting', () {
      expect(
        () => GatewayGrpcChannelFactory().create(
          gatewayAudience: 'https://gateway.example',
          trustedRootCertificates: [1, 2, 3],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects cleartext, authority confusion, paths, and unbounded timeout',
      () {
        for (final audience in [
          'http://gateway.example',
          'http://localhost:8642',
          'https://user@gateway.example',
          'https://gateway.example/rpc',
          'https://gateway.example?target=other',
          'https://gateway.example#other',
        ]) {
          expect(
            () => GatewayGrpcChannelFactory().create(gatewayAudience: audience),
            throwsA(isA<FormatException>()),
            reason: audience,
          );
        }
        expect(
          () => GatewayGrpcChannelFactory(
            connectTimeout: const Duration(minutes: 1),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'permits cleartext only through the literal loopback test factory',
      () async {
        final factory = GatewayGrpcChannelFactory.insecureLoopbackForTests();
        final ipv4 = factory.create(gatewayAudience: 'http://127.0.0.1:8642');
        final ipv6 = factory.create(gatewayAudience: 'http://[::1]:8642');
        addTearDown(ipv4.shutdown);
        addTearDown(ipv6.shutdown);

        expect(ipv4.options.credentials.isSecure, isFalse);
        expect(ipv6.options.credentials.isSecure, isFalse);
        expect(
          () => factory.create(gatewayAudience: 'http://localhost:8642'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => factory.create(
            gatewayAudience: 'http://127.0.0.1:8642',
            trustedRootCertificates: [1],
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('GatewayChannelTarget', () {
    test('normalizes only the empty root path', () {
      final target = GatewayChannelTarget.parse('https://Gateway.Example:443/');

      expect(target.audience, 'https://gateway.example');
      expect(target.host, 'gateway.example');
      expect(target.port, 443);
      expect(target.secure, isTrue);
    });
  });
}
