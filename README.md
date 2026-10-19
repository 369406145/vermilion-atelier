# Vermilion Atelier

A pocket Chinese ink studio. One finger draws. Two fingers pan and zoom. Works stay on the device. A PNG export lands in `Pictures/Vermilion Atelier`.

This repository is original studio software. It is not a copy of any commercial painting app.

## What is in here

| Folder | What it is |
| --- | --- |
| `flutter/` | The Flutter app. Open this folder. |
| `android/` | The same studio as a Kotlin / Jetpack Compose project. |
| `web/` | The in-browser studio (ink engine, editor, routes, styles). |

## Flutter

Needs Flutter 3.27 or newer.

```bash
cd flutter
flutter pub get
flutter run
```

If the platform folders look thin:

```bash
flutter create . --project-name vermilion_atelier --org studio.vermilion
```

Application id: `studio.vermilion.atelier`.

## Android (Kotlin)

Open `android/` in Android Studio (Ladybug or newer) and run the `:app` module on API 26+.

Gradle wrapper is 8.10.2, Android Gradle Plugin 8.7.3, Kotlin 2.0.21. The binary `gradle-wrapper.jar` is not in this repo. If `./gradlew` complains it is missing, install Gradle and run:

```bash
cd android
gradle wrapper --gradle-version 8.10.2
```

Do the same inside `flutter/android` if the Flutter Android build asks for the wrapper jar.

## How a sheet works

- The vermilion plus cuts a new sheet: hanging scroll, album leaf, seal square, handscroll, screen, letter, postcard.
- Paper: Bare, Xuan, Cold press, Raw silk.
- Brushes: Wolf hair, Goat wash, Dry pine, Reed pen, Soot stump. Also eraser, fill, eyedropper, shapes, and layers.
- The side rail has mirror, grid, and one-point perspective.
- Save keeps the work in the app's private directory. Download writes a PNG to the gallery.

## License

Source in this repository is released under the MIT License. See `LICENSE`.
