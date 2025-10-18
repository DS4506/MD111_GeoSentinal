import SwiftUI

struct DebugConsoleView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Logs").font(.headline)
                Spacer()
                Button("Copy") {
                    UIPasteboard.general.string = vm.logs.map { "\($0.timestamp) • \($0.message)" }.joined(separator: "\n")
                }
            }
            .padding(.horizontal)

            List(vm.logs) { log in
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.timestamp.formatted()).font(.caption2).foregroundStyle(.secondary)
                    Text(log.message).font(.caption)
                }
            }
        }
    }
}
