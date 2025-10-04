import SwiftUI

struct ConnectingView: View {
    var body: some View {
        VStack(spacing: 48) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .scaleEffect(5)
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.pulse, options: .repeating, value: true)
                .shadow(radius: 4)
                .padding(.bottom, 32)

            VStack {
                Text("Connecting to nodes")
                    .font(.title2)
                    .bold()
                Text("Please wait while your device connects to the network.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(.circular)
        }
        .padding(40)

    }
}

#Preview {
    ConnectingView()
}
