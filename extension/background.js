const HELPER = "http://127.0.0.1:17839";

function safeName(value = "video") {
  return value.replace(/[\\/:*?"<>|\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 120) || "video";
}

async function helperStatus() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 900);
  try {
    const response = await fetch(`${HELPER}/health`, { signal: controller.signal });
    if (!response.ok) return false;
    await pairHelper();
    return true;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

async function pairHelper() {
  const response = await fetch(`${HELPER}/pair`, { method: "POST" });
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

async function helperDownload(pageUrl, title) {
  let { helperToken = "" } = await chrome.storage.local.get("helperToken");
  if (!helperToken) helperToken = await pairHelper();
  const send = token => fetch(`${HELPER}/download`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-VideoPocket-Token": token },
    body: JSON.stringify({ url: pageUrl, title })
  });
  let response = await send(helperToken);
  if (response.status === 401) response = await send(await pairHelper());
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || "Local helper rejected the download.");
  return result;
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message.type === "STATUS") {
      sendResponse({ ok: true, helper: await helperStatus() });
      return;
    }
    if (message.type !== "DOWNLOAD") return;
    const media = message.media || {};
    if (media.directUrl && /^https?:\/\//.test(media.directUrl)) {
      try {
        const id = await directDownload(media.directUrl, media.title);
        sendResponse({ ok: true, method: "direct", id });
        return;
      } catch (error) {
        // Expiring URLs and referrer-restricted CDNs are retried through the helper.
      }
    }
    if (!(await helperStatus())) throw new Error("The VideoPocket helper is not running.");
    const result = await helperDownload(media.pageUrl || sender.tab?.url, media.title);
    sendResponse({ ok: true, method: "helper", ...result });
  })().catch(error => sendResponse({ ok: false, error: error.message }));
  return true;
});
