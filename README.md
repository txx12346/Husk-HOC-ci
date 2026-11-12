# HOC IPA via GitHub Actions

Build a **Gameloft / 英雄战歌-oriented** Husk IPA on GitHub’s macOS runners (no cloud Mac desktop).

## What this does

- Keeps the HOC EGL black-screen patches in `src/translation-layer-next` / `HuskEGL.java`
- Skips MoltenVK (Unreal/Vulkan only)
- Stubs Built-in StikJIT (use **external StikDebug** on the iPad)
- Runs `scripts/ci_build.sh` and uploads `Husk-HOC.ipa`

## From Windows

1. Put this tree on GitHub (fork [Leviidev/Husk](https://github.com/Leviidev/Husk) or a new repo) and push.
2. Repo → **Actions** → **Husk HOC IPA** → **Run workflow**.
3. When green, download artifact **Husk-HOC-ipa**.
4. Install with Sideloadly / AltStore / SideStore; enable JIT with StikDebug.
5. Sideload the HOC APK inside Husk and check logs for `[hoc/gameloft]`.

## Local Mac (same prepare)

```bash
./scripts/ci_prepare_hoc.sh
./scripts/ci_build.sh ~/Desktop/Husk-HOC.ipa
```

## Costs / limits

- First run can take **hours** (ANGLE, QEMU, guest firmware, Rust, xcodebuild).
- Private repos: macOS Actions minutes are billable.
- If the job times out, re-run; Homebrew/`build/` caches are not persisted unless you add cache steps later.

## Not covered

- App Store / TestFlight signing (ad-hoc / sideload only)
- Built-in StikJIT inside the IPA (external StikDebug instead)
