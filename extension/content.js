(() => {
  const BUTTON = "videopocket-save";
  const site = location.hostname;

  function postContainer(video) {
    if (site.includes("x.com") || site.includes("twitter.com")) return video.closest("article");
    if (site.includes("instagram.com")) return video.closest("article") || video.parentElement;
    if (site.includes("linkedin.com")) return video.closest(".feed-shared-update-v2") || video.closest("article");
    if (site.includes("facebook.com")) return video.closest("[role=article]") || video.closest("div[data-pagelet]");
    if (site.includes("youtube.com")) return video.closest("#player") || video.parentElement;
    return video.parentElement;
  }

  function postUrl(container) {
    const selectors = site.includes("instagram.com") ? 'a[href*="/p/"],a[href*="/reel/"]' :
      site.includes("linkedin.com") ? 'a[href*="/feed/update/"]' :
      site.includes("facebook.com") ? 'a[href*="/videos/"],a[href*="/reel/"]' :
      site.includes("youtube.com") ? 'a[href*="watch?v="]' : 'a[href*="/status/"]';
    return container?.querySelector(selectors)?.href || location.href;
  }

  function titleFor(container) {
    const text = container?.innerText?.replace(/Save video|VideoPocket/gi, " ").replace(/\s+/g, " ").trim();
    const author = container?.querySelector("h2,h3,[data-testid=User-Name],.update-components-actor__name")?.textContent?.trim();
    return [author, text].filter(Boolean).join(" - ").slice(0, 120) || document.title;
  }

  function directUrl(video) {
    const src = video.currentSrc || video.src || video.querySelector("source")?.src || "";
    return /^https?:/.test(src) && !src.includes(".m3u8") ? src : "";
  }

  function toast(text, failed = false) {
    const node = document.createElement("div");
    node.className = `videopocket-toast${failed ? " failed" : ""}`;
    node.textContent = text;
    document.documentElement.appendChild(node);
    setTimeout(() => node.remove(), 3200);
  }

  async function save(video, container, button) {
    button.disabled = true;
    button.textContent = "Saving…";
    const response = await chrome.runtime.sendMessage({ type: "DOWNLOAD", media: {
      directUrl: directUrl(video), pageUrl: postUrl(container), title: titleFor(container)
    }}).catch(error => ({ ok: false, error: error.message }));
    toast(response.ok ? (response.method === "direct" ? "Download started" : "Added to local downloader") : response.error, !response.ok);
    button.disabled = false;
    button.textContent = "Save video";
  }

  function attach(video) {
    if (video.closest("[data-videopocket-ignore]")) return;
    const container = postContainer(video);
    if (!container || container.querySelector(`.${BUTTON}`)) return;
    const button = document.createElement("button");
    button.className = BUTTON;
    button.type = "button";
    button.textContent = "Save video";
    button.title = "Save this video with VideoPocket";
    button.addEventListener("click", event => {
      event.preventDefault(); event.stopPropagation(); save(video, container, button);
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
      document.querySelectorAll("video").forEach(attach);
    });
  }
  new MutationObserver(scan).observe(document.documentElement, { childList: true, subtree: true });
  // React-based players, especially Facebook Reels, can replace overlays
  // without replacing the video node. Periodically restore a removed button.
  setInterval(scan, 1500);
  scan();
})();
