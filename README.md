# CigarTV — Roku Channel

A Roku (BrightScript / SceneGraph) app for CigarTV: a live linear channel plus an
on-demand catalog of original series, styled to match cigartv.com.

> **Status: proof-of-concept.** The UI, navigation, live playback, and EPG are
> working. The VOD catalog is fully wired to the freecast API architecture but
> renders empty until an API key (and confirmed endpoint response shapes) are
> supplied. See [Current State](#current-state) and [Next Steps](#next-steps).

---

## Quick start (side-loading for development)

1. Enable **Developer Mode** on the Roku device (Home ×3, Up ×2, Right, Left,
   Right, Left, Right — then follow the prompts to set a dev password).
2. Note the device IP shown on the Developer Settings screen.
3. Zip the project contents (the `manifest` must be at the **root** of the zip,
   not inside a subfolder):
   ```
   zip -r cigartv.zip manifest source components images fonts
   ```
4. Open `http://<roku-ip>` in a browser, log in with `rokudev` + your dev
   password, and upload the zip.
5. Watch the debug console while it runs:
   ```
   telnet <roku-ip> 8085      # or:  nc <roku-ip> 8085
   ```

To produce a signed `.pkg` for the Roku Developer Dashboard, side-load first, then
use **Package Application** on the device's dev installer page — a `.pkg` can only
be generated on-device, signed with your developer account key.

---

## Architecture

The app is a single SceneGraph scene (`MainScene`) that swaps between screen
"states" rather than using multiple scenes. All UI nodes are built in code via
`CreateChild` rather than declared in XML — this proved far more reliable than
declarative children + `FindNode` in practice.

### Screen flow

```
                 ┌─────────────┐
                 │   Chooser   │  Home: pulsing logo + smoke, EPG now/next,
                 │  (home)     │  two panels: Live / Browse
                 └──────┬──────┘
              OK │              │ OK
         (Live)  ▼              ▼ (Browse)
       ┌──────────────┐   ┌──────────────┐
       │ Live Player  │   │  VOD Grid    │  4-col grid of series
       │ (fullscreen  │   │ ("Originals")│
       │  + EPG strip)│   └──────┬───────┘
       └──────────────┘      OK  │
                                 ▼
                          ┌──────────────┐
                          │ Episode Guide│  logo + description,
                          │ (per series) │  season dropdown, episode list
                          └──────┬───────┘
                             OK  │
                                 ▼
                          ┌──────────────┐
                          │  VOD Player  │  fullscreen, stream resolved
                          │              │  via freecast /streams
                          └──────────────┘
```

### Files

| Path | Purpose |
|------|---------|
| `manifest` | Channel metadata, resolution, font registry. |
| `source/Main.brs` | Entry point; creates the scene + message loop. |
| `source/Theme.brs` | Palette, Poppins font helper, per-series asset map, `ApiConfig` (live/EPG URLs), and **`FreecastConfig`** (catalog + streaming API config). |
| `source/Freecast.brs` | Freecast API layer: catalog URL builders, **assumed** show/episodes JSON parsers, and the stream resolver (HLS/DASH + Widevine DRM). |
| `source/AdMacros.brs` | Builds the live HLS URL with SSAI ad macros populated from `roDeviceInfo`. |
| `components/MainScene.{xml,brs}` | The whole app: all screens, navigation, catalog loading, EPG, playback. |
| `components/ShowCard.{xml,brs}` | VOD grid card: thumbnail, gradient scrim, focus glow + scale animation. |
| `components/ApiTask.{xml,brs}` | Generic async HTTP Task (JSON/XML), supports a Bearer auth token. |
| `images/` | Logo, backgrounds (baked at 30% over the dark base), show logos, smoke wisps, scrim, focus frame, back button. |
| `fonts/` | Poppins family (Regular → ExtraBold). |

### Data sources

| Feature | Source | State |
|---------|--------|-------|
| Live stream | Amagi HLS playlist (`ApiConfig.liveStreamUrl`) | Working |
| Live EPG (now/next + 1hr overlay) | CloudFront XMLTV feed (`ApiConfig.epgUrl`) | Working (XMLTV parsing confirmed against real timestamps) |
| VOD catalog (shows → seasons → episodes) | freecast API (`FreecastConfig`) | **Wired, needs key + confirmed response shapes** |
| VOD playback (stream resolution) | freecast `/streams` endpoint | **Wired; `/streams` response shape confirmed** |

---

## Configuration

Everything integration-related lives in two functions in `source/Theme.brs`:

- **`ApiConfig()`** — live stream URL and EPG feed URL.
- **`FreecastConfig()`** — the freecast catalog + streaming setup:
  - `baseUrl` — base of the freecast VOD API.
  - `apiKey` — auth token (sent as `Bearer`). **Empty by default** → app runs
    with an empty catalog and an on-screen notice.
  - `shows` — the list of show slugs to load, in display order, each mapped to a
    local `seriesKey` (for logos/backgrounds/category).
  - `preferredOrder` — stream selection preference (HLS-clear → DASH+Widevine →
    DASH-clear). FairPlay HLS is intentionally never selected (Apple-only).
  - `enabled` — master switch; flip to `true` once `apiKey` is set.

---

## Security: API keys (read before shipping)

**A client-side Roku app cannot hold a secret that can't be discovered.** Anything
in the package can be extracted, and device traffic can be proxied to reveal any
key the app sends. Do **not** ship the real freecast key in `FreecastConfig.apiKey`
for production.

Recommended approach — **backend proxy**:

1. Stand up a small server (Lambda / Cloudflare Worker / etc.) that holds the real
   freecast key server-side.
2. Point the app's `baseUrl` at that proxy; leave `apiKey` empty.
3. The proxy injects the real key and forwards to freecast.

This keeps the secret off the device, and lets you rotate keys, cache, and rate-
limit without shipping an app update. If freecast supports **short-lived tokens**
or a **device-auth flow** (via `roDeviceInfo.GetChannelClientId()`), that's an even
stronger option. Note: protecting the *API key* (proxy) and protecting the *media*
(Widevine DRM) are separate concerns — you likely want both.

---

## Current State

**Working**
- Home/chooser screen: pulsing logo, rising smoke effect, Live/Browse panels with
  25%-opacity focus highlight, EPG now/next (episode sub-title).
- Live playback: fullscreen HLS with SSAI ad macros; 1-hour EPG overlay that
  auto-hides after 5s and reappears on OK.
- VOD grid, episode guide (season dropdown, scrolling episode list), and player
  navigation — all functional.
- Full freecast API architecture: catalog fetch chain (shows → seasons →
  episodes) and stream resolution with Widevine DRM support.
- Brand styling: Poppins throughout, `#f3d389` accent, per-series backgrounds and
  show logos.

**Not yet functional / blocked**
- **VOD catalog renders empty** — needs a valid `apiKey` and `enabled = true`.
- **Show/episodes JSON parsing is assumed** — only the `/streams` response shape
  is confirmed. `ParseShowSeasons` / `ParseEpisodes` in `Freecast.brs` are written
  defensively against a best guess and will likely need correction against real
  responses. They are isolated so this is a one-function-each fix.
- **Show slugs are assumed** (`mcs-BEHINDBLEND-cigar`, etc.) — real slugs may differ.
- **App icons and splash screens are missing** — the `manifest` references
  `icon_focus_hd.png`, `splash_hd.jpg`, etc., which don't exist in `images/` yet.

---

## Next Steps

### 1. Make the catalog live (unblocks everything)
- [ ] Obtain a freecast **API key / token** (and confirm the auth scheme is Bearer).
- [ ] Provide **sample JSON** from the show endpoint and the episodes endpoint
      (like the `/streams` sample already captured).
- [ ] Correct `ParseShowSeasons` / `ParseEpisodes` in `source/Freecast.brs` against
      those real responses.
- [ ] Confirm the real **show slugs** and update `FreecastConfig.shows`.
- [ ] Set `apiKey`, flip `enabled = true`, and verify the grid populates.

### 2. Secure the key before any public build
- [ ] Stand up the backend proxy (see [Security](#security-api-keys-read-before-shipping)).
- [ ] Point `baseUrl` at the proxy; ship with `apiKey` empty.

### 3. Playback hardening
- [ ] Verify HLS-clear playback end-to-end through the resolver.
- [ ] Test the Widevine DASH path if any content is DRM-protected.
- [ ] Add a loading spinner + error state while `/streams` resolves.
- [ ] Add resume/continue-watching (persist per-episode position).

### 4. Store-readiness assets
- [ ] Create channel icons (`mm_icon_focus_hd/sd`, `mm_icon_side_hd/sd`) and splash
      screens (`splash_hd.jpg`, `splash_sd.jpg`) — currently referenced but missing.
- [ ] Prepare Developer Dashboard listing (description, screenshots, category,
      content rating).

### 5. Polish & QA
- [ ] Tune on-device: smoke speed/opacity, card scale animation, EPG overlay timing.
- [ ] Confirm Poppins glyph coverage for accented characters in descriptions.
- [ ] Verify EPG now/next against the live schedule across time zones.
- [ ] Handle empty/short seasons and long titles/descriptions gracefully.
- [ ] Full remote-navigation pass (focus never gets trapped or lost).

### 6. Nice-to-haves
- [ ] Deep-linking (launch straight into a specific episode from Roku search/feed).
- [ ] Roku Content Feed / Search integration for discoverability.
- [ ] Analytics (playback starts, completions, errors).
- [ ] Captions/subtitles (the source had en/es/de/pt) surfaced in the player.

---

## Known constraints / gotchas (from development)

- **Build all nodes in code.** Declarative XML children + `FindNode` were
  unreliable here; every UI node is created with `CreateChild`.
- **`roUrlTransfer` only runs on the main thread or inside a Task** — all network
  calls go through `ApiTask`, never directly from the render thread.
- **No non-ASCII in `.brs` source** — em-dashes/smart quotes in comments break the
  compiler. Keep source ASCII-only (feed *data* with accents is fine, it's fetched
  at runtime).
- **Animations via string-id interpolators were unreliable** — the logo pulse,
  smoke, and card scale are driven by manual `Timer`s instead, which is dependable.
- **`m` is the reserved scope object** — never use it as a local variable name.
