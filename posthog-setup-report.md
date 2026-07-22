# PostHog post-wizard report

The wizard has completed a PostHog analytics integration for the **CigarTV Roku** app. Because Roku BrightScript has no official PostHog SDK and `roUrlTransfer` cannot run on the SceneGraph render thread, a fire-and-forget `PostHogTask` async Task component was created to POST events to the PostHog capture endpoint from a background thread. A `source/PostHog.brs` helper library provides the `PhCapture()` function, which creates and runs this task for any given event. The PostHog configuration (token and host) lives in `ApiConfig()` in `source/Theme.brs`, following the project's existing configuration pattern. Eight events were instrumented across the core viewer journey in `components/MainScene.brs`.

| Event name | Description | File |
|---|---|---|
| `app_launched` | Fired once when the app fully loads and the splash screen completes | `components/MainScene.brs` |
| `live_stream_started` | User chose to watch the live CigarTV linear channel | `components/MainScene.brs` |
| `vod_grid_opened` | User entered the VOD browse grid to discover shows | `components/MainScene.brs` |
| `show_selected` | User selected a specific show and entered its episode guide | `components/MainScene.brs` |
| `episode_started` | User began playing an on-demand episode | `components/MainScene.brs` |
| `episode_playback_failed` | An episode stream could not be resolved and playback failed | `components/MainScene.brs` |
| `season_changed` | User switched to a different season within an episode guide | `components/MainScene.brs` |
| `locked_episode_selected` | User attempted to play a locked (coming soon) episode | `components/MainScene.brs` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- **Dashboard** — [Analytics basics (wizard)](https://us.posthog.com/project/523921/dashboard/1889056)
- **Episode plays over time** — [jhc2zI3e](https://us.posthog.com/project/523921/insights/jhc2zI3e)
- **Live vs VOD viewer split** — [AjrIOEpF](https://us.posthog.com/project/523921/insights/AjrIOEpF)
- **Show popularity** — [X4GmbtrF](https://us.posthog.com/project/523921/insights/X4GmbtrF)
- **Content engagement funnel** — [J3mfFLOl](https://us.posthog.com/project/523921/insights/J3mfFLOl)
- **Playback failures** — [mw6IhipS](https://us.posthog.com/project/523921/insights/mw6IhipS)

## Verify before merging

- [ ] Run a full production build (the wizard only verified the files it touched) and fix any lint or type errors introduced by the generated code.
- [ ] Run the test suite — call sites that were rewritten or instrumented may need updated mocks or fixtures.
- [ ] Add `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` to `.env.example` and any onboarding docs so collaborators know what these values are (both are already written to `.env` locally).
- [ ] Sideload the channel to a Roku device and confirm `app_launched` appears in PostHog Live Events within seconds of the app loading. This validates the `PostHogTask` networking and certificate path.
- [ ] Confirm the returning-visitor path also calls `identify` if/when a registration or login screen is added — any handler that only identifies on first launch can leave returning sessions on anonymous distinct IDs.

### Agent skill

We've left an agent skill folder in your project. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.
