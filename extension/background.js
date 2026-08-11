const HELPER = "http://127.0.0.1:17839";
const HELPER_TIMEOUT_MS = 3000;
const UPDATE_MANIFEST = "https://raw.githubusercontent.com/evoknow-ai/videopocket/main/update.json";
const CHANGELOG_URL = "https://github.com/evoknow-ai/videopocket/blob/main/CHANGELOG.md";

function safeName(value = "media") {
  return value.replace(/[\\/:*?"<>|\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 120) || "video";
}

async function helperFetch(path, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HELPER_TIMEOUT_MS);
  try {
    return await fetch(`${HELPER}${path}`, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function helperStatus() {
  try {
    const response = await helperFetch("/health");
    if (!response.ok) return { online: false, reason: "unavailable" };
    const details = await response.json().catch(() => ({}));
    return { online: true, version: details.version || "legacy" };
  } catch (error) {
    return {
      online: false,
      reason: error.name === "AbortError" ? "timeout" : "unavailable"
    };
  }
}

async function pairLegacyHelper() {
  const response = await helperFetch("/pair", { method: "POST" });
  if (!response.ok) throw new Error("Could not pair with the local helper.");
  const { token } = await response.json();
  if (!token) throw new Error("The local helper returned no pairing token.");
  await chrome.storage.local.set({ helperToken: token });
  return token;
}

function mediaExtension(url, kind) {
  if (kind === "video") return "mp4";
  const match = new URL(url).pathname.match(/\.([a-zA-Z0-9]{2,5})$/);
  return match && ["jpg", "jpeg", "png", "webp"].includes(match[1].toLowerCase()) ? match[1].toLowerCase() : "jpg";
}

function sourceFolder(pageUrl = "") {
  let host = "";
  try { host = new URL(pageUrl).hostname; } catch { return "other"; }
  if (host.includes("instagram.com")) return "ig";
  if (host.includes("facebook.com")) return "fb";
  if (host === "x.com" || host.includes("twitter.com")) return "x";
  if (host.includes("linkedin.com")) return "linkedin";
  return "youtube";
}

async function directDownload(url, title, kind = "video", pageUrl = "") {
  const filename = `VideoPocket/downloads/${sourceFolder(pageUrl)}/${safeName(title)}.${mediaExtension(url, kind)}`;
  return chrome.downloads.download({ url, filename, conflictAction: "uniquify", saveAs: false });
}

async function sendHelperDownload(pageUrl, title, token = "") {
  const headers = { "Content-Type": "application/json" };
  if (token) headers["X-VideoPocket-Token"] = token;
  return helperFetch("/download", {
    method: "POST",
    headers,
    body: JSON.stringify({ url: pageUrl, title })
  });
}

async function helperDownload(pageUrl, title) {
  const { helperToken = "" } = await chrome.storage.local.get("helperToken");

  // Modern helpers authorize the extension origin and need no shared secret.
  let response = await sendHelperDownload(pageUrl, title);

  // A legacy helper still expects its token. Reuse it first, then repair it
  // automatically if the helper was reinstalled and generated a new token.
  if (response.status === 401) {
    let token = helperToken;
    if (token) response = await sendHelperDownload(pageUrl, title, token);
    if (!token || response.status === 401) {
      token = await pairLegacyHelper();
      response = await sendHelperDownload(pageUrl, title, token);
    }
  }

  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || "The Mac Helper could not start this download.");
  return result;
}

async function helperAction(path, method = "GET") {
  const response = await helperFetch(path, { method });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || "The Mac Helper could not complete this action.");
  return result;
}

function versionParts(value = "0") { return value.split(".").map(part => Number.parseInt(part, 10) || 0); }
function isNewer(candidate, current) {
  const a = versionParts(candidate), b = versionParts(current);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if ((a[i] || 0) !== (b[i] || 0)) return (a[i] || 0) > (b[i] || 0);
  }
  return false;
}
async function updateStatus(helperVersion) {
  const currentExtension = chrome.runtime.getManifest().version;
  try {
    const response = await fetch(`${UPDATE_MANIFEST}?t=${Math.floor(Date.now() / 3600000)}`, { cache: "no-store" });
    if (!response.ok) throw new Error("Update check unavailable");
    const release = await response.json();
    const available = isNewer(release.version, currentExtension) || Boolean(helperVersion && isNewer(release.helperVersion || release.version, helperVersion));
    await chrome.action.setBadgeText({ text: available ? "UP" : "" });
    if (available) await chrome.action.setBadgeBackgroundColor({ color: "#d92d20" });
    return { ok: true, available, currentExtension, currentHelper: helperVersion, ...release, changelogUrl: release.changelogUrl || CHANGELOG_URL };
  } catch (error) {
    return { ok: false, available: false, currentExtension, currentHelper: helperVersion, error: error.message, changelogUrl: CHANGELOG_URL };
  }
}

async function scheduledUpdateCheck() {
  const helper = await helperStatus();
  await updateStatus(helper.version);
}
chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create("videopocket-update", { periodInMinutes: 360 });
  scheduledUpdateCheck();
});
chrome.runtime.onStartup.addListener(scheduledUpdateCheck);
chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === "videopocket-update") scheduledUpdateCheck();
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message.type === "STATUS") {
      const status = await helperStatus();
      sendResponse({ ok: true, helper: status.online, ...status });
      return;
    }
    if (message.type === "OPEN_DOWNLOADS") {
      sendResponse(await helperAction("/open-downloads", "POST"));
      return;
    }
    if (message.type === "GET_ERRORS") {
      sendResponse(await helperAction("/errors"));
      return;
    }
    if (message.type === "DOWNLOAD_STATUS") {
      sendResponse(await helperAction(`/download-status${message.jobId ? `?id=${encodeURIComponent(message.jobId)}` : ""}`));
      return;
    }
    if (message.type === "CHECK_UPDATE") {
      const helper = await helperStatus();
      sendResponse(await updateStatus(helper.version));
      return;
    }
    if (message.type !== "DOWNLOAD") return;
    const media = message.media || {};
    if (media.directUrl && /^https?:\/\//.test(media.directUrl)) {
      try {
        const id = await directDownload(media.directUrl, media.title, media.kind, media.pageUrl || sender.tab?.url);
        sendResponse({ ok: true, method: "direct", id });
        return;
      } catch {
        // Expiring URLs and referrer-restricted CDNs are retried through the helper.
      }
    }
    const status = await helperStatus();
    if (!status.online) throw new Error("Open VideoPocket Helper, then click Try again.");
    const result = await helperDownload(media.pageUrl || sender.tab?.url, media.title);
    sendResponse({ ok: true, method: "helper", ...result });
  })().catch(error => sendResponse({ ok: false, error: error.message }));
  return true;
});
