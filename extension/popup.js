const status = document.querySelector("#status");
const retry = document.querySelector("#retry");

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
  status.textContent = response.ok ? "Added to downloads" : response.error;
  retry.hidden = response.ok;
});
