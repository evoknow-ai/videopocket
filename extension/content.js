(() => {
  const BUTTON = "videopocket-save";
  const site = location.hostname;

  function postContainer(media) {
    if (media.tagName === "IMG" && site.includes("instagram.com")) return media.parentElement;
    if (site.includes("x.com") || site.includes("twitter.com")) return media.closest("article");
    if (site.includes("instagram.com")) return media.closest("article") || media.parentElement;
    if (site.includes("facebook.com")) return media.closest("[role=article]") || media.closest("div[data-pagelet]");
    return media.parentElement;
  }

  function postUrl(container) {
    const selectors = site.includes("instagram.com") ? 'a[href*="/p/"],a[href*="/reel/"]' :
      site.includes("facebook.com") ? 'a[href*="/videos/"],a[href*="/reel/"]' :
      'a[href*="/status/"]';
    return container?.querySelector(selectors)?.href || location.href;
  }

  function titleFor(container) {
    const text = container?.innerText?.replace(/Save video|VideoPocket/gi, " ").replace(/\s+/g, " ").trim();
    const author = container?.querySelector("h2,h3,[data-testid=User-Name],.update-components-actor__name")?.textContent?.trim();
    return [author, text].filter(Boolean).join(" - ").slice(0, 120) || document.title;
  }

  function directUrl(media) {
    const src = media.currentSrc || media.src || media.querySelector?.("source")?.src || "";
    return /^https?:/.test(src) && !src.includes(".m3u8") ? src : "";
  }

  function toast(text, failed = false) {
    const node = document.createElement("div");
    node.className = `videopocket-toast${failed ? " failed" : ""}`;
    node.textContent = text;
    document.documentElement.appendChild(node);
    setTimeout(() => node.remove(), 3200);
  }

  async function save(media, container, button) {
    const kind = media.tagName === "IMG" ? "image" : "video";
    button.disabled = true;
    button.textContent = "Saving…";
    const response = await chrome.runtime.sendMessage({ type: "DOWNLOAD", media: {
      directUrl: directUrl(media), pageUrl: postUrl(media.closest("article") || container), title: titleFor(media.closest("article") || container), kind
    }}).catch(error => ({ ok: false, error: error.message }));
    toast(response.ok ? (response.method === "direct" ? "Download started" : "Download queued — check VideoPocket Errors") : response.error, !response.ok);
    button.disabled = false;
    button.textContent = `Save ${kind}`;
  }

  function attach(media) {
    if (media.closest("[data-videopocket-ignore]")) return;
    if (media.tagName === "IMG") {
      const rect = media.getBoundingClientRect();
      if (!media.closest("article") || rect.width < 250 || rect.height < 250) return;
    }
    const container = postContainer(media);
    if (!container || container.querySelector(`.${BUTTON}`)) return;
    const button = document.createElement("button");
    button.className = BUTTON;
    button.type = "button";
    const kind = media.tagName === "IMG" ? "image" : "video";
    button.textContent = `Save ${kind}`;
    button.title = `Save this ${kind} with VideoPocket`;
    button.addEventListener("click", event => {
      event.preventDefault(); event.stopPropagation(); save(media, container, button);
    });
    const style = getComputedStyle(container);
    if (style.position === "static") container.style.position = "relative";
    container.appendChild(button);
  }

  let scheduled = false;
  function scan() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      document.querySelectorAll(site.includes("instagram.com") ? "video, article img" : "video").forEach(attach);
    });
  }
  new MutationObserver(scan).observe(document.documentElement, { childList: true, subtree: true });
  // React-based players, especially Facebook Reels, can replace overlays
  // without replacing the video node. Periodically restore a removed button.
  setInterval(scan, 1500);
  scan();
})();
