import SwiftUI

enum NavigationOptions: Equatable, Hashable, Identifiable {
    case files
    case upload
    case settings

    static let mainPages: [NavigationOptions] = [
        .files, .upload, .settings,
    ]

    var id: String {
        switch self {
        case .files: return "Files"
        case .upload: return "Share"
        case .settings: return "Settings"
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .files:
            LocalizedStringResource(
                "Files",
                comment: "Title for the Files tab, shown in the sidebar."
            )
        case .upload:
            LocalizedStringResource(
                "Share",
                comment: "Title for the Share tab, shown in the sidebar."
            )
        case .settings:
            LocalizedStringResource(
                "Settings",
                comment: "Title for the Settings tab, shown in the sidebar."
            )
        }
    }

    var symbolName: String {
        switch self {
        case .files: "lock.document"
        case .upload: "icloud.and.arrow.up"
        case .settings: "gear"
        }
    }

    /// A view builder that the split view uses to show a view for the selected navigation option.
    @MainActor @ViewBuilder func viewForPage() -> some View {
        switch self {
        case .files: ContentView()
        case .upload: ContentView()
        case .settings: ContentView()
        }

    }
}
