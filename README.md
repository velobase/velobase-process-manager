# DevMinder

[![GitHub stars](https://img.shields.io/github/stars/velobase/DevMinder?style=social)](https://github.com/velobase/DevMinder/stargazers)
[![Build macOS DMG](https://github.com/velobase/DevMinder/actions/workflows/build-dmg.yml/badge.svg)](https://github.com/velobase/DevMinder/actions/workflows/build-dmg.yml)
[![Latest release](https://img.shields.io/github/v/release/velobase/DevMinder?label=release)](https://github.com/velobase/DevMinder/releases/latest)
[![Download DMG](https://img.shields.io/badge/download-DMG-2f6feb)](https://github.com/velobase/DevMinder/releases/latest/download/DevMinder.dmg)

A tiny macOS menu bar app that helps you spot forgotten dev processes from Codex, Cursor, Next.js, Vite, test watchers, Docker containers, and other local tools before they quietly drain your Mac.

[Download the latest DMG](https://github.com/velobase/DevMinder/releases/latest/download/DevMinder.dmg) ·
[Releases](https://github.com/velobase/DevMinder/releases) ·
[Issues](https://github.com/velobase/DevMinder/issues)

## Why

When you are building with Codex, Cursor, or any fast AI coding workflow, it is easy to ask the tool to start a Next.js app, run a Vite preview, kick off tests, or bring up a Docker container. The work moves quickly. The cleanup does not always keep up.

A forgotten `next dev`, a Vite server on `5173`, a Flask API on `5000`, a test watcher, Redis, Postgres, or a mapped Docker container can sit in the background for hours. You usually notice only when your Mac feels warm, the battery drops faster than expected, or a familiar port is mysteriously already in use.

DevMinder was made for that small but annoying moment. It lives in the menu bar, watches the development ports and process rules you care about, and lets you stop forgotten processes when you decide they should go.

## Features

- Menu bar first: no Dock icon and no desktop window on launch.
- Port monitoring: defaults cover common development ports for Next.js/React/Nuxt, Vite, Angular, Astro, Flask/API, Postgres, Redis, Storybook, Django/FastAPI, Spring/Tomcat/API, Wrangler, and more.
- Process rules: match global processes with plain keywords or `/regex/` patterns such as `vite`, `next dev`, `rails server`, or `uvicorn`.
- Sleep mode: pause or resume monitoring from the menu bar.
- Low overhead scanning: defaults to a 30-second interval and batches port checks to avoid repeatedly spawning heavy commands.
- Safe stopping flow: send `TERM` first, then offer `KILL` only if the process does not exit.
- Docker scan: running Docker containers are listed even when they do not match a watched port or process rule; mapped Docker Desktop ports still resolve to containers and use `docker stop` / `docker kill`.
- System process protection: Apple system processes are marked as protected and cannot be stopped from the app.
- Unified target list: detected targets are shown in one list with subtle reason tags for port, rule, and Docker matches.
- Localization and appearance: follows system language and appearance, with Chinese/English and light/dark modes available in settings.

## Install

1. Download [DevMinder.dmg](https://github.com/velobase/DevMinder/releases/latest/download/DevMinder.dmg).
2. Open the DMG and drag `DevMinder.app` into `Applications`.
3. Launch the app and look for the menu bar icon.

This free distribution build is not notarized with an Apple Developer ID. If macOS says the developer cannot be verified, open **System Settings -> Privacy & Security** and choose **Open Anyway**. This keeps the project free to distribute, but it is not as smooth as a fully signed and notarized commercial build.

## Usage

- Click the menu bar icon to view detected targets grouped by port, rule, and Docker reason tags.
- Click refresh to scan immediately.
- Click pause to enter sleep mode and stop the background timer.
- Click the close button on a process row to send `TERM`.
- If the process does not exit, the button changes to a force-stop action.
- Docker rows show the container name, image, status, and published ports when available.
- Apple system processes show a protected system badge instead of a stop button.

## Development

```bash
swift run ProcessManager
```

## Checks

```bash
swift run ProcessManagerCheck
```

## Local Packaging

Build the `.app`:

```bash
./scripts/build-app.sh
open dist/DevMinder.app
```

Build the `.dmg`:

```bash
./scripts/build-dmg.sh
open dist/DevMinder-0.1.2.dmg
```

Override version metadata and the DMG name:

```bash
APP_VERSION=0.1.2 BUILD_NUMBER=3 DMG_NAME=DevMinder-0.1.2.dmg ./scripts/build-dmg.sh
```

## Automated Releases

GitHub Actions builds a DMG in these cases:

- Push to `main`: build, smoke test, package, and upload an Actions artifact.
- Pull request: build, smoke test, package, and upload an Actions artifact.
- Push a `v*` tag: create a GitHub Release and upload DMG assets.

Create a release:

```bash
git tag v0.1.2
git push origin v0.1.2
```

Each release contains:

- `DevMinder-0.1.2.dmg`: versioned archive asset.
- `DevMinder.dmg`: stable filename for README and website download links.

Stable latest download URL:

```text
https://github.com/velobase/DevMinder/releases/latest/download/DevMinder.dmg
```

## Star History

<a href="https://star-history.com/#velobase/DevMinder&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=velobase/DevMinder&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=velobase/DevMinder&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=velobase/DevMinder&type=Date" />
  </picture>
</a>

## License

[MIT](LICENSE)
