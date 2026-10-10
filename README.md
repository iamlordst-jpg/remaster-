# Amethyst iOS Mod Browser Improvements

A community-maintained improvement set for the original Amethyst iOS launcher. The original launcher remains the app experience; this branch adds an integrated mod browser and two optional, stable browser features.

## Mod Browser

- Search Minecraft projects on Modrinth.
- Search CurseForge with a locally stored API key.
- View project details, galleries, versions, dependencies, and downloadable files.
- Choose a Minecraft version, mod loader, and result sort order.
- Use a cleaner header, source selector, and separate filter menus.
- Thumbnail requests are cached and duplicate in-flight requests are reused to reduce repeat loading while scrolling.

## Optional stable features

Both features are **off by default** and can be toggled from the Mod Browser filter menu.

- **Advanced Mod Search** — enables project-type filters (mods, resource packs, shaders, data packs) and Modrinth client/server compatibility filters, including optional support.
- **Turbo Downloads** — raises the per-host connection limit, gives the download task higher priority, and allows a longer resource timeout. It cannot bypass server or network limits and may not make a single-file transfer faster.

## Downloads

- Progress shows transferred bytes, percentage when available, approximate speed, and estimated remaining time.
- Files are saved under `Documents/ST Mod Browser/` in a folder matching the selected project type.
- Downloads are not automatically installed into Minecraft's active instance. Move or import them into the correct instance folder before launching the game.
- Existing files are not overwritten by a repeated download.

## Build from iPhone

GitHub Actions builds the iOS artifacts, so the project can be tested from an iPhone without a Mac. The workflow caches Homebrew downloads, removes redundant setup, cancels older in-progress builds for the same branch, and keeps the existing IPA packaging variants.

A successful workflow confirms compilation and packaging only; install the resulting IPA in LiveContainer and test the browser and downloads on-device before considering the changes verified.

## Credits

- [Amethyst-Offline](https://github.com/AngelAuraMC/Amethyst-Offline) — launcher codebase/fork.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) — upstream iOS launcher.
- [Modrinth](https://modrinth.com/) — project discovery and data.
- Made by ST, with the help of ChatGPT.

## Disclaimer

This is an independent community project and is not affiliated with or endorsed by Amethyst, Mojang Studios, Microsoft, Modrinth, or CurseForge.
