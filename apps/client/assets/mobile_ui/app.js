const shell = document.querySelector("#app-shell");
const homeView = document.querySelector("#home-view");
const settingsView = document.querySelector("#settings-view");
const connectionView = document.querySelector("#connection-view");
const agentWidget = document.querySelector("#agent-widget");
const agentCore = document.querySelector("#agent-core");
const ttsPanel = document.querySelector("#tts-panel");
const connectionButton = document.querySelector("#connection-button");
const connectionMessage = document.querySelector("#connection-message");
const settingsButton = document.querySelector("#settings-button");
const settingsBackButton = document.querySelector("#settings-back-button");
const connectionBackButton = document.querySelector("#connection-back-button");
const connectionOptions = document.querySelectorAll(".connection-option");
const themeToggle = document.querySelector("#theme-toggle");
const themeValue = document.querySelector("#theme-value");
const fontSizeControl = document.querySelector("#font-size-control");
const fontValue = document.querySelector("#font-value");
const backgroundButton = document.querySelector("#background-button");
const backgroundInput = document.querySelector("#background-input");
const backgroundValue = document.querySelector("#background-value");

const LONG_PRESS_MS = 540;
let pressTimer = null;
let longPressTriggered = false;
let ignoreNextClick = false;
let speakingTimer = null;
let connectionMessageTimer = null;

function postBridge(event, payload = {}) {
  if (!window.AgentTalk?.postMessage) {
    return;
  }
  window.AgentTalk.postMessage(JSON.stringify({ event, ...payload }));
}

const connectionLabels = {
  connected: "已连接",
  connecting: "连接中",
  disconnected: "未连接",
};

// 这里只演示图形状态，不连接真实语音、Agent 或项目服务。
function setView(view) {
  const isHome = view === "home";
  const isSettings = view === "settings";
  const isConnection = view === "connection";
  shell.dataset.view = view;
  homeView.hidden = !isHome;
  settingsView.hidden = !isSettings;
  connectionView.hidden = !isConnection;

  if (!isHome) {
    setControlsExpanded(false);
    setTtsVisible(false);
  } else {
    setControlsExpanded(false);
    setTtsVisible(false);
  }
  postBridge("viewChanged", { view });
}

function setTtsVisible(visible) {
  agentWidget.dataset.ttsVisible = String(visible);
  agentWidget.dataset.expanded = String(visible);
  ttsPanel.hidden = !visible;
  ttsPanel.setAttribute("aria-hidden", String(!visible));
  agentCore.setAttribute("aria-expanded", String(visible));
  agentCore.setAttribute(
    "aria-label",
    visible ? "Agent 核心，短按隐藏文字，长按进行语音录入" : "Agent 核心，短按显示文字，长按进行语音录入",
  );
}

function setControlsExpanded(expanded) {
  agentWidget.dataset.expanded = String(expanded);
  agentCore.setAttribute("aria-expanded", String(expanded));
}

function setVoiceRecording(recording) {
  if (speakingTimer !== null) {
    window.clearTimeout(speakingTimer);
    speakingTimer = null;
  }

  if (recording) {
    const keepTextVisible = agentWidget.dataset.ttsVisible === "true";
    setControlsExpanded(false);
    if (!keepTextVisible) {
      setTtsVisible(false);
    }
    agentCore.dataset.state = "listening";
    agentCore.setAttribute("aria-label", "正在语音录入，松开结束");
    return;
  }

  if (agentCore.dataset.state !== "listening") {
    return;
  }

  agentCore.dataset.state = "speaking";
  agentCore.setAttribute("aria-label", "正在播放语音输出");
  setTtsVisible(true);
  speakingTimer = window.setTimeout(() => {
    agentCore.dataset.state = "ready";
    agentCore.setAttribute("aria-label", "Agent 核心，短按隐藏文字，长按进行语音录入");
    speakingTimer = null;
  }, 1800);
}

function clearPressTimer() {
  if (pressTimer !== null) {
    window.clearTimeout(pressTimer);
    pressTimer = null;
  }
}

function setConnectionStatus(status, showMessage = false, labelOverride = null) {
  const label = labelOverride ?? connectionLabels[status] ?? "未连接";
  const visualStatus = status === "connected" ? "connected" : status === "connecting" ? "connecting" : "disconnected";
  agentWidget.dataset.connection = visualStatus;
  connectionButton.setAttribute("aria-label", `连接状态：${label}`);
  connectionMessage.textContent = label;

  if (connectionMessageTimer !== null) {
    window.clearTimeout(connectionMessageTimer);
    connectionMessageTimer = null;
  }

  const isAbnormal = visualStatus !== "connected";
  const shouldShowMessage = showMessage || isAbnormal;
  agentWidget.dataset.connectionMessage = String(shouldShowMessage);

  if (showMessage && status === "connected") {
    connectionMessageTimer = window.setTimeout(() => {
      agentWidget.dataset.connectionMessage = "false";
      connectionMessageTimer = null;
    }, 3000);
  }
}

function updateFontSize(value) {
  const size = Number(value);
  shell.style.setProperty("--conversation-font-size", `${size}px`);
  fontValue.textContent = size <= 19 ? "小号" : size >= 25 ? "大号" : "标准";
}

function setCoreState(state) {
  if (state === "recording") {
    setVoiceRecording(true);
    return;
  }
  if (agentCore.dataset.state === "listening") {
    setVoiceRecording(false);
  }
  agentCore.dataset.state = state === "ready" ? "ready" : state;
}

function setConversation(messages) {
  ttsText.replaceChildren();
  if (!Array.isArray(messages) || messages.length === 0) {
    const empty = document.createElement("div");
    empty.className = "conversation-row conversation-row--assistant";
    const bubble = document.createElement("span");
    bubble.className = "conversation-bubble conversation-bubble--quiet";
    bubble.textContent = "我已准备好，随时可以开始。";
    empty.append(bubble);
    ttsText.append(empty);
    return;
  }

  for (const message of messages) {
    const row = document.createElement("div");
    row.className = `conversation-row conversation-row--${message.role === "user" ? "user" : "assistant"}`;
    const bubble = document.createElement("span");
    bubble.className = `conversation-bubble${message.quiet ? " conversation-bubble--quiet" : ""}`;
    bubble.textContent = message.text ?? "";
    row.append(bubble);
    const actions = Array.isArray(message.actions)
      ? message.actions
      : message.action
        ? [message.action]
        : [];
    for (const actionData of actions) {
      const action = document.createElement("button");
      action.type = "button";
      action.className = "conversation-action";
      action.dataset.action = actionData.type;
      action.dataset.eventId = actionData.eventId;
      action.textContent = actionData.label;
      action.disabled = actionData.enabled === false;
      row.append(action);
    }
    ttsText.append(row);
  }
}

settingsButton.addEventListener("click", () => {
  setView("settings");
});

settingsBackButton.addEventListener("click", () => {
  setView("home");
});

connectionBackButton.addEventListener("click", () => {
  setView("home");
});

connectionButton.addEventListener("click", () => {
  setView("connection");
});

connectionOptions.forEach((option) => {
  option.addEventListener("click", () => {
    const status = option.dataset.status;
    setView("home");
    postBridge("connectionAction", { status });
  });
});

themeToggle.addEventListener("click", () => {
  const nextTheme = shell.dataset.theme === "light" ? "dark" : "light";
  shell.dataset.theme = nextTheme;
  themeToggle.setAttribute("aria-pressed", String(nextTheme === "light"));
  themeToggle.setAttribute(
    "aria-label",
    nextTheme === "light" ? "切换暗色主题视觉样式" : "切换亮色主题视觉样式",
  );
  themeValue.textContent = nextTheme === "light" ? "亮色" : "深色";
  postBridge("themeChanged", { theme: nextTheme });
});

fontSizeControl.addEventListener("input", () => {
  updateFontSize(fontSizeControl.value);
  postBridge("fontSizeChanged", { value: Number(fontSizeControl.value) });
});

backgroundButton.addEventListener("click", () => {
  backgroundInput.click();
});

backgroundInput.addEventListener("change", () => {
  const [file] = backgroundInput.files ?? [];
  if (!file) {
    return;
  }

  const backgroundUrl = URL.createObjectURL(file);
  shell.style.setProperty("--custom-background", `url("${backgroundUrl}")`);
  shell.dataset.customBackground = "true";
  backgroundValue.textContent = "自定义";
  postBridge("backgroundChanged", { custom: true });
});

agentCore.addEventListener("pointerdown", (event) => {
  if (event.pointerType === "mouse" && event.button !== 0) {
    return;
  }

  clearPressTimer();
  longPressTriggered = false;
  ignoreNextClick = false;
  agentCore.setPointerCapture?.(event.pointerId);

  pressTimer = window.setTimeout(() => {
    longPressTriggered = true;
    ignoreNextClick = true;
    setVoiceRecording(true);
    postBridge("voiceStart");
  }, LONG_PRESS_MS);
});

agentCore.addEventListener("pointerup", () => {
  clearPressTimer();
  if (longPressTriggered) {
    setVoiceRecording(false);
    postBridge("voiceStop");
  }
});

agentCore.addEventListener("pointercancel", () => {
  clearPressTimer();
  if (longPressTriggered) {
    setVoiceRecording(false);
    postBridge("voiceCancel");
  }
  longPressTriggered = false;
  ignoreNextClick = false;
});

agentCore.addEventListener("click", (event) => {
  if (ignoreNextClick || longPressTriggered) {
    ignoreNextClick = false;
    longPressTriggered = false;
    event.preventDefault();
    return;
  }

  const visible = agentWidget.dataset.ttsVisible !== "true";
  setTtsVisible(visible);
  postBridge("toggleText", { visible });
});

ttsText.addEventListener("click", (event) => {
  const action = event.target.closest("button[data-action]");
  if (!action || action.disabled) {
    return;
  }
  postBridge("conversationAction", {
    action: action.dataset.action,
    eventId: action.dataset.eventId,
  });
});

window.AgentTalkHost = {
  applyState(next) {
    if (next.theme && shell.dataset.theme !== next.theme) {
      shell.dataset.theme = next.theme;
      themeToggle.setAttribute("aria-pressed", String(next.theme === "light"));
      themeValue.textContent = next.theme === "light" ? "亮色" : "深色";
    }
    if (next.connection) {
      setConnectionStatus(next.connection, next.connectionMessage === true, next.connectionLabel ?? null);
    }
    if (typeof next.ttsVisible === "boolean" && agentWidget.dataset.ttsVisible !== String(next.ttsVisible)) {
      setTtsVisible(next.ttsVisible);
    }
    if (next.coreState) {
      setCoreState(next.coreState);
    }
    if (next.fontSize) {
      fontSizeControl.value = String(next.fontSize);
      updateFontSize(next.fontSize);
    }
    if (typeof next.customBackground === "boolean") {
      shell.dataset.customBackground = String(next.customBackground);
      backgroundValue.textContent = next.customBackground ? "自定义" : "星空";
    }
  },
  setConversation,
};

setView("home");
setConnectionStatus("connected");
updateFontSize(fontSizeControl.value);
setTtsVisible(false);
