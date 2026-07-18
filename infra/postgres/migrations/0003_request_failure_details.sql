ALTER TABLE agent_talk.requests
  ADD COLUMN failure_stage text,
  ADD COLUMN failure_category text,
  ADD COLUMN failure_safe_message text,
  ADD COLUMN failure_retryable boolean;

ALTER TABLE agent_talk.requests
  ADD CONSTRAINT requests_failure_details_check
  CHECK (
    (
      failure_code IS NULL
      AND failure_stage IS NULL
      AND failure_category IS NULL
      AND failure_safe_message IS NULL
      AND failure_retryable IS NULL
    )
    OR
    (
      failure_code IS NOT NULL
      AND failure_stage IS NOT NULL
      AND failure_category IS NOT NULL
      AND failure_safe_message IS NOT NULL
      AND failure_retryable IS NOT NULL
    )
  );
