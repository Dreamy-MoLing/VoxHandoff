import assert from "node:assert/strict";
import test from "node:test";

import {
  agentEventTypes,
  failureCategories,
  failureStages,
  isTerminalAgentEventType,
  terminalAgentEventTypes,
} from "./model.js";

test("canonical taxonomy values are unique", () => {
  assert.equal(new Set(agentEventTypes).size, agentEventTypes.length);
  assert.equal(new Set(failureStages).size, failureStages.length);
  assert.equal(new Set(failureCategories).size, failureCategories.length);
});

test("only the four request terminal events are terminal", () => {
  assert.deepEqual(
    agentEventTypes.filter(isTerminalAgentEventType),
    [...terminalAgentEventTypes],
  );
});
