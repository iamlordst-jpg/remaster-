# STLauncher

**A custom iOS Minecraft Java launcher based on Amethyst-iOS and Amethyst-Offline, with an integrated Modrinth browser.**

STLauncher is a community-made project and is not an official Amethyst, Mojang, or Microsoft product.

## Features

- **Minecraft Java launcher** — built on the Amethyst launcher codebase.
- **Built-in Modrinth browser** — browse projects without leaving the app.
- **Minecraft version and mod-loader filters** — narrow results by game version and supported loader.
- **Project details** — view descriptions, screenshots, compatibility information, links, and available versions.
- **Download mods in-app** — save downloads to the ST Mod Browser folder in the app's Documents directory.
- **iPhone-friendly workflow** — developed from an iPhone, with GitHub Actions used for iOS builds.

> **Note:** Files downloaded by the browser are saved in the separate `Documents/ST Mod Browser/mods/` folder. They are not automatically installed into Minecraft's active `mods` folder; move or import them into the correct Minecraft instance's mods folder before launching the game.

## Getting STLauncher

Open the repository's **Actions** tab and select the iOS workflow to view its runs and available build artifacts:

- [iOS GitHub Actions builds](https://github.com/iamlordst-jpg/STLauncher/actions/workflows/ios.yml)

Artifact availability depends on the workflow run. A successful build is required before an installable artifact will be available.

## Building from source

STLauncher uses the upstream Amethyst launcher codebase with a custom Modrinth browser integration. The existing iOS build workflow is kept in the repository.

## Credits

- [Amethyst-Offline](https://github.com/iamlordst-jpg/Amethyst-Offline) — the offline launcher fork/codebase used in this project.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) — the upstream Amethyst iOS launcher project.
- [Modrinth](https://modrinth.com/) — mod discovery and project data.
- **Made by ST**, with the help of ChatGPT.

## Disclaimer

STLauncher is an independent community project. Minecraft is owned by Mojang Studios and Microsoft. Amethyst and its upstream components belong to their respective contributors. This project is not affiliated with or endorsed by those parties.
