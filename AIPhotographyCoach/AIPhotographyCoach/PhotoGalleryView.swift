import SwiftUI
import Photos

// Pages through every photo captured this session with a left/right swipe, each
// page reusing FullScreenImageView exactly as before (same top bar, same bottom
// action row, same Info/Filters/AI Edit/Delete/Share). Deleting a photo just drops
// it from the shared array and hands focus to a neighbor; the whole gallery only
// closes itself once every photo is gone.
struct PhotoGalleryView: View {
    @Binding var photos: [SessionPhoto]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentID: UUID?

    var body: some View {
        TabView(selection: $currentID) {
            ForEach(photos) { photo in
                FullScreenImageView(
                    image: photo.image,
                    quality: photo.quality,
                    metadata: photo.metadata,
                    onDelete: { deletePhoto(id: photo.id) },
                    onReplace: { newImage, newMetadata in replacePhoto(id: photo.id, image: newImage, metadata: newMetadata) }
                )
                .tag(photo.id as UUID?)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onAppear {
            if currentID == nil, photos.indices.contains(startIndex) {
                currentID = photos[startIndex].id
            }
        }
    }

    private func deletePhoto(id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let assetIdentifier = photos[index].metadata?.assetLocalIdentifier
        photos.remove(at: index)
        if photos.isEmpty {
            dismiss()
        } else {
            currentID = photos[min(index, photos.count - 1)].id
        }

        // Also remove the real asset from the Photos library, not just this app's
        // in-memory preview — otherwise "deleting" a photo here left it sitting in
        // the user's actual library untouched. iOS will show its own confirmation
        // before the asset is actually removed, which is standard, unavoidable
        // behavior for any app deleting a user's photos.
        if let assetIdentifier = assetIdentifier {
            PHPhotoLibrary.shared().performChanges({
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                if let asset = assets.firstObject {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
            }, completionHandler: nil)
        }
    }

    private func replacePhoto(id: UUID, image: UIImage, metadata: PhotoMetadata) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].image = image
        photos[index].metadata = metadata
    }
}
