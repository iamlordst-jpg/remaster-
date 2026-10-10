# Amethyst iOS — ST Mod Browser

A community-maintained Mod Browser improvement for the original Amethyst iOS launcher. The goal is to keep the familiar Amethyst experience while making Minecraft mod discovery, filtering, and downloads cleaner and easier to use.

## Features

### Mod Browser
- Search Minecraft projects on **Modrinth** and **CurseForge**.
- Browse project details, galleries, versions, dependencies, and downloadable files.
- Use a cleaner browser layout with separate, easy-to-find filter menus.
- Filter by Minecraft version and mod loader.
- Sort results by relevance, downloads, or recently updated.
- Cache thumbnails and reuse in-flight image requests to reduce repeated loading while scrolling.

### Optional stable features

These features are regular options—not experimental screens—and are **off by default**. Toggle them from the Mod Browser's filter menu.

- **Advanced Mod Search** — unlocks project-type filters for mods, resource packs, shaders, and data packs, plus Modrinth client/server compatibility filters.
- **Turbo Downloads** — increases the per-host connection limit, prioritizes the download task, and allows more time for a transfer to finish. Actual speed still depends on the server and network.

### Downloads
- Display download progress, transferred bytes, approximate speed, and estimated remaining time when available.
- Save files in the app's `Documents/ST Mod Browser/` directory, organized by project type.
- Avoid overwriting an existing file when downloading the same filename again.
- Downloads are saved files; they are not automatically installed into an active Minecraft instance.

## Building from an iPhone

The project uses GitHub Actions to build the iOS artifacts, so you can build from an iPhone without connecting a Mac. The workflow includes Homebrew download caching, less redundant setup, and cancellation of older in-progress builds on the same branch.

1. Open the [iOS workflow](https://github.com/iamlordst-jpg/STLauncher/actions/workflows/ios.yml).
2. Choose the branch you want to build.
3. Open the latest run and download the IPA artifact.
4. Install/sign it using your usual iPhone workflow, such as LiveContainer or SideStore.

## Project

- **Original launcher:** [Amethyst-Offline](https://github.com/AngelAuraMC/Amethyst-Offline)
- **Upstream iOS project:** [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- **Mod source:** [Modrinth](https://modrinth.com/)
- **Creator:** ST — made with the help of ChatGPT.

## Disclaimer

This is an independent community project and is not affiliated with or endorsed by Amethyst, Mojang Studios, Microsoft, Modrinth, or CurseForge.
