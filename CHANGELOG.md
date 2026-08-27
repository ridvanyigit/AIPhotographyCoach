# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.5.3] - 2026-08-27
### Added
- **Vision Face Landmarks Engine:** Integrated Apple Vision's 76-point biometric `VNDetectFaceLandmarksRequest` for micron-level facial feature tracking.
- **Pupil Tracking & Eye Contact Gaze Analysis:** Real-time tracking of left and right pupils to ensure direct eye contact with the camera lens.
- **Luxury Vision Corner Brackets:** Minimalist viewfinder corner brackets replacing crude bounding rectangles.
- **Voice Assistant Mute Toggle:** Quick mute/unmute button added to the left of the shutter button with symmetric Apple Glass aesthetic.
- **Dynamic BodyFitState Integration:** Fully unified full-body golden ratio framing engine with the compiler-optimized reactive architecture.

## [v0.5.2] - 2026-08-27
### Added
- **Dynamic Full-Body Pose Coaching:** Integrated Apple Vision's `VNDetectHumanBodyPoseRequest` to evaluate real-time Headroom and Feet Baseline framing (`BodyFitState`).
- Active guidance feedback: Lines and badges dynamically glow green/yellow on perfect framing ("GOLDEN RATIO: PERFECT FIT ✨") and warn the user when to step back or move closer.
- Full-body pose alignment is now fully linked with the intelligent Auto-Capture engine.

### Changed & Improved
- **Apple-Standard Monochrome UI:** Camera modes unified to classic Apple yellow (`.yellow`); all sub-dials, icons, and text updated to clean, high-contrast white with 5% transparent inner fills.
- **Ultra-Sheer Frosted Glass (15% Opacity):** Measurement labels (Headroom, 1H-7H, Feet Baseline) enclosed in individual, 15% transparent crystal-glass capsules for 100% legibility on any background.
- **Layout Collision Fix:** Moved 8-Head proportion ruler and Feet Baseline label to the left side of the screen, resolving all overlaps with the right-side dynamic sidebar and gear button.
- **SwiftUI Architecture Optimization:** Refactored `ContentView` state reactivity to eliminate compiler generic depth constraints.

## [v0.5.1] - 2026-08-27
### Fixed / Improved
- Increased the height of the dynamic sidebar (now displays up to 7 items simultaneously without scrolling).
- Enhanced tap-to-dismiss behavior: Sidebar now reliably closes when tapping anywhere on the screen or tapping the gear icon again.

## [v0.5.0] - 2026-08-27
### Product Pivot: "Human-Only Photography"
The application has officially pivoted to focus exclusively on human photography (Portraits, Runway, Fashion, Beauty, Spatial 3D). All general-purpose camera features have been removed to create a highly specialized professional tool.