import SwiftUI

struct BeatResultView: View {
    let model: BeatResultModel

    var body: some View {
        UploadResultView(model: model)
    }
}
