# STLauncher

**An experimental iOS Minecraft Java launcher experience built on Amethyst-iOS, with an in-app mod browser and a separate STLauncher interface.**

STLauncher is a community-made project and is not an official Amethyst, Mojang, or Microsoft product.

## Launcher modes

- **Amethyst (Default)** keeps the original Amethyst interface and Mod Browser.
- **STLauncher (Experimental)** adds a dark purple home screen, selected Minecraft version, a prominent Play button, mod discovery, download history, and a favorites/library flow.
- The selected mode is remembered between app launches and can be switched back at any time.

## Mod Browser

- Browse **Modrinth** and **CurseForge** (CurseForge requires your own API key).
- Search projects, open full project details, view gallery images and links, inspect available versions and dependencies, and select loader/Minecraft-version filters.
- Sort by relevance, download count, or recent updates.
- STLauncher improves thumbnail reuse and can optionally prefetch upcoming thumbnails.
- The STLauncher browser has a clearer discovery header and optional dark-purple styling; the Amethyst browser keeps its existing appearance.
- Favorites and named collections are stored locally when that optional feature is enabled.

## Optional experimental features

All features below are **OFF by default** and can be toggled individually under **Launcher → Experimental Features**:

- **Turbo Downloads** — prioritizes a transfer and raises the connection limit for concurrent transfers. It cannot bypass host or network limits.
- **Instant Thumbnails** — prefetches upcoming project icons.
- **Smart Mod Installer** — verifies the downloaded file's SHA-1 when the source provides a hash, discarding files that fail verification.
- **Advanced Mod Search** — adds client-side and server-side environment filters to Modrinth.
- **Favorites & Collections** — save projects and organize them into named collections.
- **Experimental UI** — applies dark-purple STLauncher browser styling.
- **Download Diagnostics** — records HTTP status, file size, elapsed time, and average transfer rate.
- **Compact Browser Cards** — shortens result descriptions to show more projects at once.

## Downloads and file locations

- Downloads & History shows recent completed/failed transfers, file size, destination path, and diagnostic details.
- The in-progress download alert displays percentage (when the server reports a total), transferred bytes, speed, and an estimated time remaining.
- Downloaded mods are saved in `Documents/ST Mod Browser/mods/`.
- **Downloads are not automatically installed into Minecraft's active `mods` directory.** Move or import them into the correct instance's folder before launching the game.
- Transfer speed still depends on the source host, connection quality, and server limits. The app cannot force a server to send a file faster.

## Build from iPhone

This repository uses GitHub Actions to build the iOS app. The experimental work is kept on the `experimental-stlauncher` branch until it has been checked on a real device.

- [iOS GitHub Actions builds](https://github.com/iamlordst-jpg/STLauncher/actions/workflows/ios.yml)
- [Experimental STLauncher branch](https://github.com/iamlordst-jpg/STLauncher/tree/experimental-stlauncher)

An Actions build succeeding confirms compilation and packaging only; the resulting IPA still needs to be installed and tested on-device before calling the UI pixel-perfect.

## Credits

- [Amethyst-Offline](https://github.com/AngelAuraMC/Amethyst-Offline) — launcher codebase/fork.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) — upstream iOS launcher.
- [Modrinth](https://modrinth.com/) — project discovery and data.
- **Made by ST**, with the help of ChatGPT.

## Disclaimer

STLauncher is an independent community project. Minecraft is owned by Mojang Studios and Microsoft. Amethyst and its upstream components belong to their respective contributors. This project is not affiliated with or endorsed by those parties.
