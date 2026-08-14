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

function setConnectionStatus(status, showMessage = false) {
  const label = connectionLabels[status];
  agentWidget.dataset.connection = status;
  connectionButton.setAttribute("aria-label", `连接状态：${label}`);
  connectionMessage.textContent = label;

  if (connectionMessageTimer !== null) {
    window.clearTimeout(connectionMessageTimer);
    connectionMessageTimer = null;
  }

  const isAbnormal = status === "connecting" || status === "disconnected";
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
    setConnectionStatus(status, true);
    setView("home");
    setTtsVisible(true);
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
});

fontSizeControl.addEventListener("input", () => {
  updateFontSize(fontSizeControl.value);
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
  }, LONG_PRESS_MS);
});

agentCore.addEventListener("pointerup", () => {
  clearPressTimer();
  if (longPressTriggered) {
    setVoiceRecording(false);
  }
});

agentCore.addEventListener("pointercancel", () => {
  clearPressTimer();
  if (longPressTriggered) {
    setVoiceRecording(false);
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

  setTtsVisible(agentWidget.dataset.ttsVisible !== "true");
});

setView("home");
setConnectionStatus("connected");
updateFontSize(fontSizeControl.value);
setTtsVisible(false);
