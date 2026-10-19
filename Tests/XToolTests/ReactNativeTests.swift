import Foundation
import Testing
@testable import ReactNativeSupport

private func makeProject(files: [String: String]) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (name, contents) in files {
        try Data(contents.utf8).write(to: dir.appendingPathComponent(name))
    }
    return dir
}

@Test func detectsExpoProject() throws {
    let dir = try makeProject(files: [
        "package.json": #"{"name": "my-app", "dependencies": {"expo": "~58.0.0", "react-native": "0.88.0"}}"#,
        "app.json": #"{"expo": {"name": "My Cool App"}}"#,
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let project = try #require(try ReactNativeProject(directory: dir))
    #expect(project.isExpo)
    #expect(project.productName == "MyCoolApp")
}

@Test func ignoresNonReactNativeProjects() throws {
    let swiftPackage = try makeProject(files: [
        "Package.swift": "",
        "package.json": #"{"dependencies": {"react-native": "0.88.0"}}"#,
    ])
    let webApp = try makeProject(files: ["package.json": #"{"dependencies": {"react": "19.0.0"}}"#])
    defer {
        try? FileManager.default.removeItem(at: swiftPackage)
        try? FileManager.default.removeItem(at: webApp)
    }

    #expect(try ReactNativeProject(directory: swiftPackage) == nil)
    #expect(try ReactNativeProject(directory: webApp) == nil)
}

@Test func resolvesRelativePaths() {
    let root = URL(fileURLWithPath: "/work/app")
    #expect(ReactNativeProject.absolute("assets/icon.png", in: root) == "/work/app/assets/icon.png")
    #expect(ReactNativeProject.absolute("/abs/icon.png", in: root) == "/abs/icon.png")
}

@Test func shellManifestLinksRuntimeFrameworks() {
    let package = ShellPackage(productName: "Demo", moduleName: "main", isExpo: true, frameworks: ["React", "hermesvm"])
    let manifest = package.manifest

    #expect(manifest.contains(#".library(name: "Demo", targets: ["Demo"])"#))
    #expect(manifest.contains(#""hermesvm","#))
    #expect(manifest.contains(#".binaryTarget(name: "React", path: "Frameworks/React.xcframework"),"#))
    #expect(manifest.contains(#".package(name: "Autolinked", path: "build/generated/autolinking")"#))
}

@Test func appDelegateMatchesProjectFlavor() {
    let bare = ShellPackage(productName: "Demo", moduleName: "Demo", isExpo: false, frameworks: []).appDelegate
    #expect(bare.contains("final class AppDelegate: UIResponder, UIApplicationDelegate"))
    #expect(bare.contains(#"forBundleRoot: "index""#))
    #expect(!bare.contains("import Expo"))

    let expo = ShellPackage(productName: "Demo", moduleName: "main", isExpo: true, frameworks: []).appDelegate
    #expect(expo.contains("final class AppDelegate: ExpoAppDelegate"))
    #expect(expo.contains("override func application("))
    #expect(expo.contains(#"withModuleName: "main""#))
}

@Test func stubProjectUsesXcodeLayout() {
    let project = ShellPackage.stubProject
    #expect(project.contains("/* Begin PBXNativeTarget section */"))
    #expect(project.contains("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \(ShellPackage.deploymentTarget);"))
    #expect(!project.contains("    "))
}
