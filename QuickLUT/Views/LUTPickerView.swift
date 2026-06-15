import SwiftUI

struct LUTPickerView: View {
    @EnvironmentObject var viewModel: AppViewModel

    private let availableLUTs = [
        "DJI_DLog_to_Rec709_vivid.cube",
        "DJI_DLogM_to_Rec709.cube",
        "iPhone_2020_to_709_33.cube",
    ]

    var body: some View {
        HStack {
            Text("LUT")
                .frame(width: 70, alignment: .leading)
            Picker("", selection: viewModel.binding(\.lutFileName)) {
                ForEach(availableLUTs, id: \.self) { lut in
                    Text(lut.replacingOccurrences(of: ".cube", with: ""))
                        .tag(lut)
                }
            }
            .labelsHidden()
        }
    }
}
