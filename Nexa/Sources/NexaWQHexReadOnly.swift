import SwiftUI
import UIKit

/// The unmodified original WQFiles WQHexViewController does the real work:
/// paged file reads, snapshots, offset navigation and hex/text searches.
/// Nexa merely presents it for a validated imported file, without editing.
struct NexaWQHexSelection: Identifiable {
    let id = UUID()
    let file: URL
}

struct NexaWQOriginalHexView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let file: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let original = WQHexViewController(path: file.path, readOnly: true)
        original.title = file.lastPathComponent
        original.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        let navigation = UINavigationController(rootViewController: original)
        navigation.overrideUserInterfaceStyle = .dark
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject {
        let onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }
        @objc func close() { onClose() }
    }
}


/// Original WQFiles typed/plist tree viewer, with all editing disabled.
/// WQPlistEditor.m is compiled unchanged from the pinned WQFiles submodule.
struct NexaWQPlistSelection: Identifiable {
    let id = UUID()
    let file: URL
}

struct NexaWQOriginalPlistView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let file: URL

    func makeCoordinator() -> Coordinator { Coordinator(onClose: { dismiss() }) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let original = WQPlistEditorViewController(path: file.path, readOnly: true)
        original.title = file.lastPathComponent
        original.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        let navigation = UINavigationController(rootViewController: original)
        navigation.overrideUserInterfaceStyle = .dark
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject {
        let onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }
        @objc func close() { onClose() }
    }
}
