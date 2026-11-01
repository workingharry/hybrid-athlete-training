import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Generates valid, importable Apple Shortcuts (.shortcut) files for frictionless 1-tap installation
public struct ShortcutFileGenerator: Sendable {

    /// Creates an official .shortcut property list payload
    public static func makeShortcutPlistData() -> Data? {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>WFWorkflowActions</key>
            <array>
                <dict>
                    <key>WFWorkflowActionIdentifier</key>
                    <string>is.workflow.actions.openurl</string>
                    <key>WFWorkflowActionParameters</key>
                    <dict>
                        <key>WFURLActionURL</key>
                        <dict>
                            <key>Value</key>
                            <dict>
                                <key>attachmentsByRange</key>
                                <dict>
                                    <key>{26, 1}</key>
                                    <dict>
                                        <key>Type</key>
                                        <string>ExtensionInput</string>
                                    </dict>
                                </dict>
                                <key>string</key>
                                <string>zerotyping://record?notes=&#xFFFC;</string>
                            </dict>
                            <key>WFSerializationType</key>
                            <string>WFTextTokenString</string>
                        </dict>
                    </dict>
                </dict>
            </array>
            <key>WFWorkflowClientVersion</key>
            <string>2607.1</string>
            <key>WFWorkflowIcon</key>
            <dict>
                <key>WFWorkflowIconGlyphNumber</key>
                <integer>59511</integer>
                <key>WFWorkflowIconStartColor</key>
                <integer>4282601983</integer>
            </dict>
            <key>WFWorkflowMinimumClientVersion</key>
            <integer>900</integer>
            <key>WFWorkflowMinimumClientVersionString</key>
            <string>900</string>
            <key>WFWorkflowTypes</key>
            <array>
                <string>NCWidget</string>
                <string>Watch</string>
                <string>ActionExtension</string>
            </array>
        </dict>
        </plist>
        """
        return xmlContent.data(using: .utf8)
    }

    /// Writes the shortcut file to temporary storage and returns its file URL
    public static func generateShortcutFile() -> URL? {
        guard let data = makeShortcutPlistData() else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("零打字記帳_ApplePay極速自動入帳.shortcut")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Shares or exports the .shortcut file to Shortcuts app, AirDrop, or Files
    @MainActor
    public static func shareShortcutFile() {
        guard let fileURL = generateShortcutFile() else { return }
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // Find top-most view controller to present
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
        #endif
    }
}
