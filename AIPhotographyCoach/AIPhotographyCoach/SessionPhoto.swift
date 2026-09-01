import UIKit

// One photo captured during this app session, held only in memory — cleared
// automatically when the app is closed. This is what powers the swipeable preview
// gallery: every shot taken while the app stays open shows up here, not just the
// most recent one.
struct SessionPhoto: Identifiable {
    let id: UUID
    var image: UIImage
    var quality: CaptureQuality?
    var metadata: PhotoMetadata?

    init(id: UUID = UUID(), image: UIImage, quality: CaptureQuality?, metadata: PhotoMetadata?) {
        self.id = id
        self.image = image
        self.quality = quality
        self.metadata = metadata
    }
}
