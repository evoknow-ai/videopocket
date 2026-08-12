# Chrome Web Store Permission Audit

Audited version: 0.4.6

Single purpose: Save media that users own or are authorized to download from supported X/Twitter, Facebook, and Instagram pages, using Chrome downloads or a local Mac Helper.

| Permission | Required use | Why a narrower alternative is insufficient |
|---|---|---|
| `activeTab` | Lets a user invoke Save from the popup on the tab they explicitly selected. | Avoids permanent access to unrelated tabs. |
| `alarms` | Runs the public version check every six hours. | A persistent background process is neither available nor desirable in Manifest V3. |
| `downloads` | Saves direct image and video files through Chrome's download manager. | The extension cannot create user-visible files without this API. |
| `storage` | Stores local preferences and a compatibility token for older local Helpers. | Data must survive service-worker suspension and browser restarts. |
| `scripting` | Invokes the existing page-level Save control when the user clicks Save in the popup. | Used only on the active tab after an explicit user action. |
| `x.com`, `twitter.com` | Detects supported media and post URLs on X/Twitter. | Content scripts need declared access to operate on these pages. |
| `facebook.com` | Detects supported videos and post URLs on Facebook. | Content scripts need declared access to operate on these pages. |
| `instagram.com` | Detects supported videos, Reels, post images, and carousel images. | Content scripts need declared access to operate on these pages. |
| `127.0.0.1:17839` | Communicates with the Mac Helper on the user's computer. | Complex media streams require local merging and H.264/AAC conversion. |
| `raw.githubusercontent.com/evoknow-ai/videopocket` | Reads the project's public `update.json` manifest. | Provides an update notice for the separately installed Mac Helper. |

## Removed for 0.4.6

- LinkedIn and YouTube host permissions and content-script matches.
- CDN-wide permissions for `twimg.com`, `fbcdn.net`, `cdninstagram.com`, and `licdn.com` because `chrome.downloads.download` does not require persistent read access to those sites.

## Chrome Web Store data-use declarations

- Personally identifiable information: **No**
- Health information: **No**
- Financial and payment information: **No**
- Authentication information: **No**
- Personal communications: **No**
- Location: **No**
- Web history: **No collection or transmission**
- User activity: **No collection or transmission**
- Website content: **Processed locally only; not collected or transmitted to the publisher**

Certify that data is not sold, used for advertising, used for credit or lending decisions, or transferred for purposes unrelated to VideoPocket's single purpose.
