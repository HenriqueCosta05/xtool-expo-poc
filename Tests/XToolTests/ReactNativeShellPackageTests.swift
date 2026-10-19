import Testing
@testable import ReactNativeSupport

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
