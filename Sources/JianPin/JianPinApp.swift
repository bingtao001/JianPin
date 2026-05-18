import SwiftUI
import JianPinEngine

@main
struct JianPinApp: App {

    @StateObject private var processor = ContactProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView(processor: processor)
                .frame(width: 400, height: 560)
                .frame(minWidth: 360, maxWidth: 440, minHeight: 440, maxHeight: 600)
        }
    }
}