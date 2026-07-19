import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uncertain acceptance cannot be silently resubmitted or overwritten',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(clientSessionProvider.notifier);

      controller.editDraft('confirmed command');
      controller.confirmDraft();
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.confirmed,
      );
      expect(
        () => controller.beginSubmission('request-1'),
        throwsStateError,
        reason: 'an unpaired client cannot submit',
      );

      controller.setConnectionPhase(GatewayConnectionPhase.connected);
      controller.beginSubmission('request-1');
      controller.markAcceptanceUncertain('request-1');

      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.uncertain,
      );
      expect(() => controller.beginSubmission('request-1'), throwsStateError);
      expect(() => controller.editDraft('replacement'), throwsStateError);
    },
  );

  test('acceptance must match the pre-generated request identity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(clientSessionProvider.notifier);
    controller.setConnectionPhase(GatewayConnectionPhase.connected);
    controller.editDraft('confirmed command');
    controller.confirmDraft();
    controller.beginSubmission('request-1');

    expect(() => controller.markAccepted('request-2'), throwsStateError);
    controller.markAccepted('request-1');
    expect(
      container.read(clientSessionProvider).draftPhase,
      DraftPhase.accepted,
    );
  });
}
