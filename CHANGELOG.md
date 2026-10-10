# Changelog

All notable changes to the Quick Tote plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2026-10-11

### Added
- **Segmented Settings Architecture**: Redesigned settings interface to match the modern DMS segmented group pattern with unified outer/inner corner radius hierarchy (`outerR`/`innerR`).
- **Standardized Settings Components**:
  - `PathFieldItem`: Directory path configuration cards with icon avatars and text field inputs.
  - `SettingsToggleItem`: 56px segmented toggles with animated state icons, title, and description.
  - `SettingsSliderItem`: Numeric limit configuration cards featuring `DankSlider`, editable input boxes, and animated reset buttons.
- **System Drag Dependencies**: Added `ripdrag | xdragon | dragon` as optional/recommended drag-and-drop provider dependencies in `plugin.json`.

### Changed
- **Icon Sizing & Consistency**: Updated widget and settings icons across pinned, download, and screenshot cards to dynamically use `Theme.iconSize` tokens for consistent scaling.
- **Corner Radii Tokens**: Normalized UI corner radius calculations across items using `Theme.cornerRadius` and `Theme.cornerRadius / 2`.
- **Plugin Manifest**: Bumped version to `1.3.0` in [plugin.json](file:///home/JD/Downloads/Projects/DMS-Quick_Tote/plugin.json).

---

## [1.2.2] - 2026-10-10

### Changed
- Disabled mouse wheel manipulation on numeric text inputs to prevent accidental value scrolling.
- Enabled masking layers for thumbnail icon delegates.
- Cleaned up plugin dependencies in manifest.

---

## [1.2.1] - 2026-10-10

### Added
- External drag-and-drop support via layer-shell compatible native CLI tool detection (`ripdrag`, `xdragon`, `dragon`).
- Responsive screenshot column calculation ("Smart Sort").

### Fixed
- Smooth ListModel sync animations on filesystem changes.

---

## [1.0.0] - 2026-10-09

### Added
- Initial release of Quick Tote widget for Dank Material Shell.
- Pinned files management and persistence.
- Recent downloads scanner and quick-access view.
- Recent screen captures viewer with thumbnail previews.
