import Foundation

struct DocumentationGenerator {
    let packagePath: String
    let target: String?
    let outputPath: String
    let customDoccPath: String?
    let includeDependencies: Bool
    let verbose: Bool

    private let fileManager = FileManager.default

    // Cache DocC in user's cache directory
    private var cacheDirectory: URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("swift-llm-docs", isDirectory: true)
    }

    private var doccRepoPath: URL {
        cacheDirectory.appendingPathComponent("swift-docc", isDirectory: true)
    }

    private var doccBinaryPath: URL {
        doccRepoPath.appendingPathComponent(".build/release/docc", isDirectory: false)
    }

    private var symbolGraphsPath: URL {
        cacheDirectory.appendingPathComponent("symbol-graphs", isDirectory: true)
    }

    func run() async throws {
        let packageURL = URL(fileURLWithPath: packagePath).standardizedFileURL
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL

        print("📦 Package: \(packageURL.path)")

        // Resolve target name (may take a while if resolving dependencies)
        if target == nil {
            print("🔍 Discovering targets...")
        }
        let targetName = try await resolveTarget(in: packageURL)

        print("🎯 Target: \(targetName)")
        print("📁 Output: \(outputURL.path)")
        print()

        // Step 1: Ensure we have a working docc binary
        let doccURL = try await ensureDocC()

        // Step 2: Generate symbol graphs
        print("📊 Generating symbol graphs...")
        try await generateSymbolGraphs(for: targetName, in: packageURL)
        print("   ✓ Symbol graphs generated")

        // Step 3: Run docc convert
        print("📝 Generating Markdown documentation...")
        try await runDoccConvert(docc: doccURL, target: targetName, output: outputURL)

        // Step 4: Report results
        try reportResults(target: targetName, output: outputURL)
    }

    // MARK: - Target Resolution

    private func resolveTarget(in packageURL: URL) async throws -> String {
        if let target = target {
            return target
        }

        // Try to get the default target from Package.swift
        let packageSwiftURL = packageURL.appendingPathComponent("Package.swift")
        guard fileManager.fileExists(atPath: packageSwiftURL.path) else {
            throw GeneratorError.notASwiftPackage(packageURL.path)
        }

        // Use swift package dump-package to get targets
        let result = try await shell(
            "swift", "package", "dump-package",
            workingDirectory: packageURL
        )

        guard let data = result.output.data(using: .utf8),
              let package = try? JSONDecoder().decode(PackageDescription.self, from: data) else {
            throw GeneratorError.couldNotParsePackage
        }

        // Find first library or executable target
        guard let firstTarget = package.targets.first(where: { $0.type == "regular" || $0.type == "executable" }) else {
            throw GeneratorError.noTargetsFound
        }

        return firstTarget.name
    }

    // MARK: - DocC Management

    private func ensureDocC() async throws -> URL {
        // Check for custom path first
        if let customPath = customDoccPath {
            let url = URL(fileURLWithPath: customPath)
            guard fileManager.isExecutableFile(atPath: url.path) else {
                throw GeneratorError.doccNotExecutable(customPath)
            }
            // Verify it has markdown output support
            let result = try await shell(url.path, "convert", "--help")
            guard result.output.contains("enable-experimental-markdown-output") else {
                throw GeneratorError.doccMissingMarkdownSupport
            }
            print("🔧 Using custom DocC: \(customPath)")
            return url
        }

        // Check if we have a cached build
        if fileManager.isExecutableFile(atPath: doccBinaryPath.path) {
            // Verify it still has markdown support
            let result = try await shell(doccBinaryPath.path, "convert", "--help")
            if result.output.contains("enable-experimental-markdown-output") {
                if verbose {
                    print("🔧 Using cached DocC: \(doccBinaryPath.path)")
                }
                return doccBinaryPath
            }
        }

        // Need to build DocC
        print("🔨 Building DocC (first run only, this takes a few minutes)...")
        try await buildDocC()
        return doccBinaryPath
    }

    private func buildDocC() async throws {
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let doccRepoURL = "https://github.com/swiftlang/swift-docc.git"
        let doccBranch = "release/6.3"

        if fileManager.fileExists(atPath: doccRepoPath.path) {
            // Update existing checkout
            print("   Updating DocC repository...")
            _ = try await shell(
                "git", "fetch", "origin", doccBranch,
                workingDirectory: doccRepoPath
            )
            _ = try await shell(
                "git", "checkout", doccBranch,
                workingDirectory: doccRepoPath
            )
            _ = try await shell(
                "git", "pull", "origin", doccBranch,
                workingDirectory: doccRepoPath
            )
        } else {
            // Fresh clone
            print("   Cloning DocC repository...")
            _ = try await shell(
                "git", "clone", "--branch", doccBranch, doccRepoURL, doccRepoPath.path
            )
        }

        print("   Compiling DocC (this may take 2-3 minutes)...")
        _ = try await shell(
            "swift", "build", "-c", "release", "--product", "docc",
            workingDirectory: doccRepoPath,
            timeout: 600 // 10 minutes
        )

        guard fileManager.isExecutableFile(atPath: doccBinaryPath.path) else {
            throw GeneratorError.doccBuildFailed
        }

        print("   ✓ DocC built successfully")
    }

    // MARK: - Symbol Graph Generation

    private func generateSymbolGraphs(for target: String, in packageURL: URL) async throws {
        // Clean previous symbol graphs
        try? fileManager.removeItem(at: symbolGraphsPath)
        try fileManager.createDirectory(at: symbolGraphsPath, withIntermediateDirectories: true)

        // First, try a normal build with symbol graph emission
        var result = try await shell(
            "xcrun", "swift", "build",
            "--target", target,
            "-Xswiftc", "-emit-symbol-graph",
            "-Xswiftc", "-emit-symbol-graph-dir",
            "-Xswiftc", symbolGraphsPath.path,
            workingDirectory: packageURL,
            timeout: 300 // 5 minutes
        )

        // Verify symbol graph was created
        let targetSymbolGraph = symbolGraphsPath.appendingPathComponent("\(target).symbols.json")

        if !fileManager.fileExists(atPath: targetSymbolGraph.path) {
            // Symbol graphs not generated - likely due to incremental build cache
            // Touch source files to invalidate the cache for this target only
            print("   Invalidating build cache for \(target)...")

            let sourcesDir = packageURL.appendingPathComponent("Sources/\(target)")
            if let enumerator = fileManager.enumerator(at: sourcesDir, includingPropertiesForKeys: nil) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.pathExtension == "swift" {
                        // Touch the file to update its modification date
                        try? fileManager.setAttributes(
                            [.modificationDate: Date()],
                            ofItemAtPath: fileURL.path
                        )
                    }
                }
            }

            result = try await shell(
                "xcrun", "swift", "build",
                "--target", target,
                "-Xswiftc", "-emit-symbol-graph",
                "-Xswiftc", "-emit-symbol-graph-dir",
                "-Xswiftc", symbolGraphsPath.path,
                workingDirectory: packageURL,
                timeout: 300
            )
        }

        guard fileManager.fileExists(atPath: targetSymbolGraph.path) else {
            // Show build output to help debug
            if !result.output.isEmpty {
                print("   Build output: \(result.output.suffix(500))")
            }
            if !result.error.isEmpty {
                print("   Build errors: \(result.error.suffix(500))")
            }
            throw GeneratorError.symbolGraphNotGenerated(target)
        }
    }

    // MARK: - DocC Convert

    private func runDoccConvert(docc: URL, target: String, output: URL) async throws {
        // Generate doccarchive in temp directory
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("swift-llm-docs-\(UUID().uuidString)")
        let archivePath = tempDir.appendingPathComponent("\(target).doccarchive")

        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        _ = try await shell(
            docc.path, "convert",
            "--additional-symbol-graph-dir", symbolGraphsPath.path,
            "--output-path", archivePath.path,
            "--fallback-display-name", target,
            "--fallback-bundle-identifier", "com.package.\(target)",
            "--enable-experimental-markdown-output",
            "--enable-experimental-markdown-output-manifest",
            "--no-transform-for-static-hosting",
            timeout: 600 // 10 minutes - docc can be slow with many symbol graphs
        )

        // Verify doccarchive was created with markdown
        let manifestPath = archivePath.appendingPathComponent("\(target)-markdown-manifest.json")
        guard fileManager.fileExists(atPath: manifestPath.path) else {
            throw GeneratorError.markdownNotGenerated
        }

        // Extract only markdown files to output directory
        try extractMarkdownFiles(from: archivePath, to: output, target: target)
    }

    private func extractMarkdownFiles(from archivePath: URL, to output: URL, target: String) throws {
        // Remove existing output and recreate
        try? fileManager.removeItem(at: output)
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        // Copy all markdown files, preserving directory structure relative to data/
        let dataDir = archivePath.appendingPathComponent("data")
        guard let enumerator = fileManager.enumerator(at: dataDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return
        }

        while let sourceURL = enumerator.nextObject() as? URL {
            guard sourceURL.pathExtension == "md" else { continue }

            // Get path relative to data/ directory
            let relativePath = sourceURL.path.replacingOccurrences(of: dataDir.path + "/", with: "")
            let destURL = output.appendingPathComponent(relativePath)

            // Create parent directories
            try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            // Copy file
            try fileManager.copyItem(at: sourceURL, to: destURL)
        }
    }

    // MARK: - Results

    private func reportResults(target: String, output: URL) throws {
        let targetLower = target.lowercased()

        // Count markdown files
        let enumerator = fileManager.enumerator(
            at: output,
            includingPropertiesForKeys: nil
        )

        var totalCount = 0
        var targetCount = 0

        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "md" {
                totalCount += 1
                if url.path.lowercased().contains("/\(targetLower)/") {
                    targetCount += 1
                }
            }
        }

        print()
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Documentation generated successfully!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print("📊 Generated \(totalCount) markdown files")
        print("   • \(targetCount) for \(target)")
        print("   • \(totalCount - targetCount) for dependencies")
        print()
        print("📁 Output: \(output.path)")
    }

    // MARK: - Shell Execution

    private func shell(
        _ args: String...,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 120
    ) async throws -> ShellResult {
        try await shell(args, workingDirectory: workingDirectory, timeout: timeout)
    }

    private func shell(
        _ args: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 120
    ) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        if verbose {
            print("   $ \(args.joined(separator: " "))")
        }

        try process.run()

        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.terminate()
            throw GeneratorError.commandTimeout(args.joined(separator: " "))
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && verbose {
            print("   stderr: \(error)")
        }

        return ShellResult(
            exitCode: process.terminationStatus,
            output: output,
            error: error
        )
    }
}

// MARK: - Supporting Types

struct ShellResult {
    let exitCode: Int32
    let output: String
    let error: String
}

struct PackageDescription: Decodable {
    let name: String
    let targets: [Target]

    struct Target: Decodable {
        let name: String
        let type: String
    }
}

enum GeneratorError: LocalizedError {
    case notASwiftPackage(String)
    case couldNotParsePackage
    case noTargetsFound
    case doccNotExecutable(String)
    case doccMissingMarkdownSupport
    case doccBuildFailed
    case symbolGraphNotGenerated(String)
    case markdownNotGenerated
    case commandTimeout(String)

    var errorDescription: String? {
        switch self {
        case .notASwiftPackage(let path):
            return "Not a Swift package: \(path) (no Package.swift found)"
        case .couldNotParsePackage:
            return "Could not parse Package.swift"
        case .noTargetsFound:
            return "No targets found in package. Use --target to specify one."
        case .doccNotExecutable(let path):
            return "DocC not executable at: \(path)"
        case .doccMissingMarkdownSupport:
            return "The provided DocC binary doesn't support markdown output. Use DocC from release/6.3 or later."
        case .doccBuildFailed:
            return "Failed to build DocC"
        case .symbolGraphNotGenerated(let target):
            return "Symbol graph not generated for target: \(target)"
        case .markdownNotGenerated:
            return "Markdown output was not generated"
        case .commandTimeout(let command):
            return "Command timed out: \(command)"
        }
    }
}
