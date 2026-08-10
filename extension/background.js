const HELPER = "http://127.0.0.1:17839";
const HELPER_TIMEOUT_MS = 3000;

function safeName(value = "video") {
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

async function directDownload(url, title) {
  const filename = `VideoPocket/${safeName(title)}.mp4`;
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

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message.type === "STATUS") {
      const status = await helperStatus();
      sendResponse({ ok: true, helper: status.online, ...status });
      return;
    }
    if (message.type !== "DOWNLOAD") return;
    const media = message.media || {};
    if (media.directUrl && /^https?:\/\//.test(media.directUrl)) {
      try {
        const id = await directDownload(media.directUrl, media.title);
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
