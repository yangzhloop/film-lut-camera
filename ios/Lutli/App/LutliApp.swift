import SwiftUI

@main
@MainActor
struct LutliApp: App {
    @StateObject private var model = LutliAppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .environmentObject(model)
                .environmentObject(model.camera)
                .preferredColorScheme(.dark)
                .tint(.white)
                .task {
                    if scenePhase == .active { model.camera.start() }
                    await model.prepare()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.camera.start()
                    } else {
                        model.cancelCountdown()
                        model.camera.stop()
                    }
                }
        }
    }
}
