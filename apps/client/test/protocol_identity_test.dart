import 'package:agent_talk_client/application/protocol_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client compiles against the generated protocol package', () {
    final version = clientProtocolVersion();
    expect(version.major, 1);
    expect(version.minor, 1);
  });
}
