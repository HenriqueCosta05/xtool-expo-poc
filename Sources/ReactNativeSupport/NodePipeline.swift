import Foundation
import PackLib
import Subprocess
import XUtils

struct NodePipeline: Sendable {
    var projectRoot: URL
    var appRoot: URL
    var isExpo: Bool

    var bundleDirectory: URL { appRoot.appendingPathComponent("build/bundle") }

    func generatePackages() async throws {
        let environment = try await toolEnvironment()
        let configFile = try await writeAutolinkingConfig(environment: environment)
        let configCommand = String(decoding: try JSONEncoder().encode(["cat", configFile.path]), as: UTF8.self)
        let setupScript = projectRoot.appendingPathComponent("node_modules/react-native/scripts/setup-apple-spm.js")
        try await run(
            ["node", setupScript.path, "update", "--yes", "--config-command", configCommand],
            in: appRoot,
            environment: environment
        )
    }

    func prepareBundle(configuration: BuildConfiguration) async throws -> [String] {
        try? FileManager.default.removeItem(at: bundleDirectory)
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        switch configuration {
        case .debug:
            let host = try await metroHost()
            print("Metro host: \(host) (override with XTOOL_METRO_HOST)")
            try Data("\(host)\n".utf8).write(to: bundleDirectory.appendingPathComponent("ip.txt"))
        case .release:
            let bundler = isExpo
                ? ["npx", "expo", "export:embed"]
                : ["npx", "react-native", "bundle", "--entry-file", "index.js"]
            try await run(bundler + [
                "--platform", "ios",
                "--dev", "false",
                "--bundle-output", bundleDirectory.appendingPathComponent("main.jsbundle").path,
                "--assets-dest", bundleDirectory.path,
            ], in: projectRoot)
        }

        return try FileManager.default.contentsOfDirectory(atPath: bundleDirectory.path)
            .map { "build/bundle/\($0)" }
    }

    private func writeAutolinkingConfig(environment: Environment) async throws -> URL {
        let command = isExpo
            ? ["npx", "expo-modules-autolinking", "react-native-config", "--json", "--platform", "ios"]
            : ["npx", "@react-native-community/cli", "config"]
        let output = try await capture(command, in: projectRoot, environment: environment)

        guard var config = try JSONSerialization.jsonObject(with: output) as? [String: Any] else {
            throw StringError("Unexpected output from `\(command.joined(separator: " "))`")
        }
        var project = config["project"] as? [String: Any] ?? [:]
        var ios = project["ios"] as? [String: Any] ?? [:]
        ios["sourceDir"] = appRoot.path
        project["ios"] = ios
        config["project"] = project

        let file = appRoot.appendingPathComponent("autolinking-config.json")
        try JSONSerialization.data(withJSONObject: config).write(to: file)
        return file
    }

    private func toolEnvironment() async throws -> Environment {
        #if os(macOS)
        return .inherit
        #else
        let shims = appRoot.appendingPathComponent(".shims")
        try? FileManager.default.removeItem(at: shims)
        try FileManager.default.createDirectory(at: shims, withIntermediateDirectories: true)

        try FileManager.default.createSymbolicLink(
            at: shims.appendingPathComponent("otool"),
            withDestinationURL: try await toolchainBinary("llvm-objdump")
        )

        let plutil = shims.appendingPathComponent("plutil")
        try Data("""
        #!/usr/bin/env python3
        import json, plistlib, sys
        with open(sys.argv[-1], "rb") as f:
            sys.stdout.write(json.dumps(plistlib.load(f), default=str))

        """.utf8).write(to: plutil)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: plutil.path)

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return .inherit.updating(["PATH": "\(shims.path):\(path)"])
        #endif
    }

    private func toolchainBinary(_ name: String) async throws -> URL {
        let info = try await capture(["swiftc", "-print-target-info"], in: appRoot)
        let paths = (try JSONSerialization.jsonObject(with: info) as? [String: Any])?["paths"] as? [String: Any]
        guard let resourcePath = paths?["runtimeResourcePath"] as? String else {
            throw StringError("Could not locate the Swift toolchain")
        }
        return URL(fileURLWithPath: resourcePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("bin/\(name)")
    }

    private func metroHost() async throws -> String {
        if let host = ProcessInfo.processInfo.environment["XTOOL_METRO_HOST"] {
            return host
        }
        #if os(macOS)
        let command = ["ipconfig", "getifaddr", "en0"]
        #else
        let command = ["hostname", "-I"]
        #endif
        let output = String(decoding: try await capture(command, in: appRoot), as: UTF8.self)
        guard let host = output.split(whereSeparator: \.isWhitespace).first else {
            throw StringError("Could not determine this machine's IP address. Set XTOOL_METRO_HOST.")
        }
        return String(host)
    }

    private func run(_ command: [String], in directory: URL, environment: Environment = .inherit) async throws {
        try await Subprocess.run(
            .name(command[0]),
            arguments: .init(Array(command.dropFirst())),
            environment: environment,
            workingDirectory: FilePath(directory.path),
            output: .currentStandardOutput,
            error: .currentStandardError,
        )
        .checkSuccess()
    }

    private func capture(_ command: [String], in directory: URL, environment: Environment = .inherit) async throws -> Data {
        let result = try await Subprocess.run(
            .name(command[0]),
            arguments: .init(Array(command.dropFirst())),
            environment: environment,
            workingDirectory: FilePath(directory.path),
            output: .data(limit: .max),
            error: .currentStandardError,
        )
        .checkSuccess()
        return result.standardOutput
    }
}
