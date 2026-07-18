ALTER TABLE agent_talk.approvals
  DROP CONSTRAINT approvals_state_check;

ALTER TABLE agent_talk.approvals
  ADD CONSTRAINT approvals_state_check
  CHECK (state IN ('pending', 'approved', 'rejected', 'expired', 'cancelled'));
