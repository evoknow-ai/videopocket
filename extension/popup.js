const status = document.querySelector("#status");
const retry = document.querySelector("#retry");
const errorPanel = document.querySelector("#error-panel");
const errorLog = document.querySelector("#error-log");
const progress = document.querySelector("#progress");
let progressTimer;

function renderProgress(job) {
  if (!job || job.state === "idle") return;
  progress.hidden = false;
  document.querySelector("#progress-stage").textContent = job.stage || job.state;
  document.querySelector("#progress-file").textContent = job.filename || "";
  const percent = Number.isFinite(job.percent) ? job.percent : null;
  document.querySelector("#progress-percent").textContent = percent === null ? "" : `${Math.round(percent)}%`;
  document.querySelector("#progress-bar").style.width = `${percent || 0}%`;
  status.textContent = job.state === "ready" ? "Ready — open it from Downloads" : job.state === "error" ? (job.error || "Download failed") : "Download in progress";
  if (["ready", "error"].includes(job.state)) clearInterval(progressTimer);
}
async function pollProgress(jobId) {
  clearInterval(progressTimer);
  const check = async () => {
    const result = await chrome.runtime.sendMessage({ type: "DOWNLOAD_STATUS", jobId }).catch(() => null);
    if (result?.ok) renderProgress(result.job);
  };
  await check();
  progressTimer = setInterval(check, 1000);
}
async function checkUpdate() {
  const result = await chrome.runtime.sendMessage({ type: "CHECK_UPDATE" }).catch(() => null);
  if (!result?.available) return;
  document.querySelector("#update").hidden = false;
  document.querySelector("#update-version").textContent = `Version ${result.helperVersion || result.version}`;
  document.querySelector("#update-link").href = result.helperReleaseUrl || result.releaseUrl;
  document.querySelector("#update-changelog").href = result.changelogUrl;
}

async function refreshStatus() {
  status.textContent = "Connecting to Mac Helper…";
  retry.hidden = true;
  const result = await chrome.runtime.sendMessage({ type: "STATUS" }).catch(() => ({ helper: false }));
  status.textContent = result.helper ? "● Ready to download" : "○ Mac Helper is not connected";
  status.style.color = result.helper ? "#72df9b" : "#f2c66d";
  retry.hidden = Boolean(result.helper);
}

retry.addEventListener("click", refreshStatus);
refreshStatus();
checkUpdate();
pollProgress();

document.querySelector("#downloads").addEventListener("click", async () => {
  const result = await chrome.runtime.sendMessage({ type: "OPEN_DOWNLOADS" }).catch(error => ({ ok: false, error: error.message }));
  if (!result.ok) status.textContent = result.error || "Could not open Downloads";
});

document.querySelector("#errors").addEventListener("click", async () => {
  errorPanel.hidden = false;
  errorLog.textContent = "Loading…";
  const result = await chrome.runtime.sendMessage({ type: "GET_ERRORS" }).catch(error => ({ ok: false, error: error.message }));
  errorLog.textContent = result.ok ? result.log : (result.error || "Could not read the helper log");
});

document.querySelector("#close-errors").addEventListener("click", () => { errorPanel.hidden = true; });

document.querySelector("#save").addEventListener("click", async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const [{ result } = {}] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: () => {
    const button = [...document.querySelectorAll(".videopocket-save")].find(x => { const r=x.getBoundingClientRect(); return r.bottom>0&&r.top<innerHeight; });
    if (button) { button.click(); return true; } return false;
  }});
  if (result) {
    status.textContent = "Save requested";
    return;
  }
  const supported = /(^|\.)(facebook\.com|instagram\.com|x\.com|twitter\.com|linkedin\.com|youtube\.com|youtu\.be)$/.test(new URL(tab.url).hostname);
  if (!supported) {
    status.textContent = "This website is not supported";
    return;
  }
  status.textContent = "Sending page to Mac Helper…";
  const response = await chrome.runtime.sendMessage({ type: "DOWNLOAD", media: {
    directUrl: "", pageUrl: tab.url, title: tab.title || "video"
  }}).catch(error => ({ ok: false, error: error.message }));
  status.textContent = response.ok ? "Download starting…" : response.error;
  if (response.ok) pollProgress(response.jobId);
  retry.hidden = response.ok;
});
