# Kurage (クラゲ)

*Pronounced similarly to “koo-rah-geh” — Japanese for jellyfish.*

> **AI Disclosure:** Kurage is developed with significant AI assistance. I lead the project's UI design and architecture, with AI assisting in investigation and implementation. I've reviewed and tested all changes.

Kurage is a manga and comic reader for [Jellyfin](https://jellyfin.org/), built with Flutter. It focuses on a clean interface, smooth reading, and a fast, responsive experience.

## Features

- CBZ-only support, with unsupported formats filtered from the UI.

- Seamless online and offline operation without separate interfaces.

- Reading progress tracking.

- Stream volumes directly from Jellyfin or download them for offline reading.

- Cover caching and preloading to minimize image pop-in during navigation.

## Screenshots
<p align="center">
  <img src="assets/githubImages/screenshots/Phone/library.jpg" width="250" alt="Library">
  <img src="assets/githubImages/screenshots/Phone/collection.jpg" width="250" alt="Collection">
  <br>
  <img src="assets/githubImages/screenshots/Phone/reader-ui_all.jpg" width="250" alt="Reader-UI-All">
  <img src="assets/githubImages/screenshots/Phone/reader_ui-immersive.jpg" width="250" alt="Reader-UI-Immersive">
</p>

## Platform Support
Android, Linux, and iOS are officially supported.
Windows and macOS are untested.

### Linux

Linux requires [`pass`](https://www.passwordstore.org/) for encrypted credential storage. Install it and initialize your password store with a GPG key before signing in:

```sh
pass init YOUR_GPG_KEY_ID
```

Press **F1** to view the keyboard and mouse shortcuts.

The Linux build uses [a fork of Sony's Flutter Embedded Linux](https://github.com/lkcv/flutter-embedded-linux) for native Wayland support and up to 120 FPS on compatible displays.

## Credits

Kurage is a fork of [**JellyBook**](https://github.com/JellyBookOrg/JellyBook). Full credit goes to Kara Wilson and the contributors to their project for creating the foundation for Kurage.
