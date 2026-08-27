# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.5.1] - 2026-08-27
### Fixed / Improved
- Increased the height of the dynamic sidebar (now displays up to 7 items simultaneously without scrolling).
- Enhanced tap-to-dismiss behavior: Sidebar now reliably closes when tapping anywhere on the screen or tapping the gear icon again.

## [v0.5.0] - 2026-08-27
### Product Pivot: "Human-Only Photography"
The application has officially pivoted to focus exclusively on human photography (Portraits, Runway, Fashion, Beauty, Spatial 3D). All general-purpose camera features have been removed to create a highly specialized professional tool.

### Added
- `RUNWAY` mode added for action/sports portrait scenarios.
- `GROUP PANO` mode to replace generic landscape panoramas.
- Clean "Fashion Magazine" UI mode: Guidance and grids now disappear when the shot is perfectly aligned, allowing an unobstructed view of the subject.

### Removed
- `CameraCategory` system completely removed (No more Photo vs. Human separation).
- `PHOTO`, `MACRO`, and `ACTION` general modes removed to keep the app strictly human-centric.