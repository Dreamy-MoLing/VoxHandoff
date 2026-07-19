import 'package:grpc/grpc.dart';

class GatewayGrpcChannelFactory {
  GatewayGrpcChannelFactory({this.connectTimeout = const Duration(seconds: 10)})
    : _allowInsecureLoopbackForTests = false {
    _validateConnectTimeout(connectTimeout);
  }

  GatewayGrpcChannelFactory.insecureLoopbackForTests({
    this.connectTimeout = const Duration(seconds: 10),
  }) : _allowInsecureLoopbackForTests = true {
    _validateConnectTimeout(connectTimeout);
  }

  final Duration connectTimeout;
  final bool _allowInsecureLoopbackForTests;

  ClientChannel create({
    required String gatewayAudience,
    List<int>? trustedRootCertificates,
  }) {
    final target = GatewayChannelTarget.parse(
      gatewayAudience,
      allowInsecureLoopbackForTests: _allowInsecureLoopbackForTests,
    );
    if (!target.secure && trustedRootCertificates != null) {
      throw const FormatException(
        'Trusted root certificates require a secure Gateway.',
      );
    }

    final ChannelCredentials credentials;
    if (target.secure) {
      final certificates = trustedRootCertificates == null
          ? null
          : List<int>.unmodifiable(trustedRootCertificates);
      if (certificates != null && certificates.isEmpty) {
        throw const FormatException(
          'The trusted root certificate cannot be empty.',
        );
      }
      credentials = ChannelCredentials.secure(certificates: certificates);
      if (certificates != null) {
        try {
          // Parse an explicitly imported CA immediately. The gRPC channel is
          // lazy, so without this check malformed trust material would fail
          // later and look like an ambiguous network outage.
          credentials.securityContext;
        } catch (_) {
          throw const FormatException(
            'The trusted root certificate is invalid.',
          );
        }
      }
    } else {
      credentials = const ChannelCredentials.insecure();
    }

    return ClientChannel(
      target.host,
      port: target.port,
      options: ChannelOptions(
        credentials: credentials,
        connectTimeout: connectTimeout,
      ),
    );
  }

  static void _validateConnectTimeout(Duration value) {
    if (value <= Duration.zero || value > const Duration(seconds: 30)) {
      throw const FormatException(
        'The Gateway connection timeout is outside its supported bound.',
      );
    }
  }
}

class GatewayChannelTarget {
  const GatewayChannelTarget._({
    required this.audience,
    required this.host,
    required this.port,
    required this.secure,
  });

  factory GatewayChannelTarget.parse(
    String value, {
    bool allowInsecureLoopbackForTests = false,
  }) {
    late final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      throw const FormatException('The Gateway audience is invalid.');
    }
    final loopback = uri.host == '127.0.0.1' || uri.host == '::1';
    final secure = uri.scheme == 'https';
    final allowedInsecure =
        uri.scheme == 'http' && loopback && allowInsecureLoopbackForTests;
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (!secure && !allowedInsecure) ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('The Gateway audience is invalid.');
    }

    final port = uri.hasPort ? uri.port : (secure ? 443 : 80);
    if (port < 1 || port > 65535) {
      throw const FormatException('The Gateway port is invalid.');
    }
    return GatewayChannelTarget._(
      audience: uri.replace(path: '').toString(),
      host: uri.host,
      port: port,
      secure: secure,
    );
  }

  final String audience;
  final String host;
  final int port;
  final bool secure;
}
