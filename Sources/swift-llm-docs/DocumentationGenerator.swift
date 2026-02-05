import Foundation

/// Configuration for how to invoke Swift commands.
struct SwiftInvocation {
    /// Custom path to Swift executable. When set, `useXcrun` is ignored.
    let customSwiftPath: String?

    #if os(macOS)
    /// Use `xcrun swift` instead of `swift`. Ignored when `customSwiftPath` is set.
    /// Only available on macOS.
    let useXcrun: Bool
    #endif

    var commandPrefix: [String] {
        if let customPath = customSwiftPath {
            return [customPath]
        }
        #if os(macOS)
        if useXcrun {
            return ["xcrun", "swift"]
        }
        #endif
        return ["swift"]
    }
}

enum InputType {
    case swiftPackage(URL)
    case xcodeProject(URL)
}

struct DocumentationGenerator {
    let packagePath: String
    let target: String?
    let outputPath: String
    let customDoccPath: String?
    let xcodeProjectPath: String?
    let scheme: String?
    let swiftInvocation: SwiftInvocation
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

    private var xcodeDerivedDataPath: URL {
        cacheDirectory.appendingPathComponent("xcode-derived-data", isDirectory: true)
    }

    private func detectInputType() throws -> InputType {
        if let xcodePath = xcodeProjectPath {
            let url = URL(fileURLWithPath: xcodePath).standardizedFileURL
            guard url.pathExtension == "xcodeproj" else {
                throw GeneratorError.notAnXcodeProject(xcodePath)
            }
            return .xcodeProject(url)
        }
        return .swiftPackage(URL(fileURLWithPath: packagePath).standardizedFileURL)
    }

    private func swiftCommand(_ args: String...) -> [String] {
        swiftInvocation.commandPrefix + args
    }

    private func swiftCommand(_ args: [String]) -> [String] {
        swiftInvocation.commandPrefix + args
    }

    func run() async throws {
        let inputType = try detectInputType()
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL

        switch inputType {
        case .swiftPackage(let packageURL):
            try await runSwiftPackageFlow(packageURL: packageURL, outputURL: outputURL)

        case .xcodeProject(let projectURL):
            try await runXcodeProjectFlow(projectURL: projectURL, outputURL: outputURL)
        }
    }

    private func runSwiftPackageFlow(packageURL: URL, outputURL: URL) async throws {
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
        print("🔧 Checking DocC...")
        let doccURL = try await ensureDocC()

        // Step 2: Generate symbol graphs for dependencies
        print("📊 Generating symbol graphs for dependencies...")
        try await generateSymbolGraphs(for: targetName, in: packageURL)

        // Step 3: Run docc convert
        print("📝 Running DocC convert...")
        try await runDoccConvert(docc: doccURL, target: targetName, output: outputURL)

        // Step 4: Copy articles from .docc catalogs
        print("📚 Copying articles from documentation catalogs...")
        try copyArticlesFromDoccCatalogs(packageURL: packageURL, output: outputURL)

        // Step 5: Report results
        try reportResults(output: outputURL)
    }

    private func runXcodeProjectFlow(projectURL: URL, outputURL: URL) async throws {
        print("📦 Xcode Project: \(projectURL.path)")

        // Resolve scheme
        if scheme == nil {
            print("🔍 Discovering schemes...")
        }
        let schemeName = try await resolveXcodeScheme(in: projectURL)

        print("🎯 Scheme: \(schemeName)")
        print("📁 Output: \(outputURL.path)")
        print()

        // Step 1: Ensure we have a working docc binary
        print("🔧 Checking DocC...")
        let doccURL = try await ensureDocC()

        // Step 2: Generate symbol graphs via xcodebuild
        print("📊 Building documentation with xcodebuild...")
        try await generateSymbolGraphsViaXcodebuild(project: projectURL, scheme: schemeName)

        // Step 3: Run docc convert
        print("📝 Running DocC convert...")
        try await runDoccConvert(docc: doccURL, target: schemeName, output: outputURL)

        // Step 4: Copy articles from .docc catalogs (search project directory)
        print("📚 Copying articles from documentation catalogs...")
        try copyArticlesFromDoccCatalogs(packageURL: projectURL.deletingLastPathComponent(), output: outputURL)

        // Step 5: Report results
        try reportResults(output: outputURL)
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

        print("   Running swift package dump-package...")
        let result = try await shell(
            swiftCommand("package", "dump-package"),
            workingDirectory: packageURL,
            captureOutput: true
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

    // MARK: - Xcode Scheme Resolution

    private func resolveXcodeScheme(in projectURL: URL) async throws -> String {
        if let scheme = scheme {
            return scheme
        }

        // Run: xcodebuild -list -project <path> -json
        print("   Running xcodebuild -list...")
        let result = try await shell(
            "xcodebuild", "-list", "-project", projectURL.path, "-json",
            captureOutput: true
        )

        // Parse JSON to get schemes
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONDecoder().decode(XcodeBuildList.self, from: data),
              let firstScheme = json.project.schemes.first else {
            throw GeneratorError.noSchemesFound
        }

        return firstScheme
    }

    // MARK: - Xcode Symbol Graph Generation

    private func generateSymbolGraphsViaXcodebuild(project: URL, scheme: String) async throws {
        // Clean previous derived data and symbol graphs
        print("   Cleaning previous builds...")
        try? fileManager.removeItem(at: xcodeDerivedDataPath)
        try? fileManager.removeItem(at: symbolGraphsPath)
        try fileManager.createDirectory(at: symbolGraphsPath, withIntermediateDirectories: true)

        // Run xcodebuild docbuild
        print("   Running xcodebuild docbuild (this may take a while)...")
        if verbose {
            print("   $ xcodebuild docbuild -project \(project.path) -scheme \(scheme) -derivedDataPath \(xcodeDerivedDataPath.path)")
        }

        _ = try await shell(
            "xcodebuild", "docbuild",
            "-project", project.path,
            "-scheme", scheme,
            "-derivedDataPath", xcodeDerivedDataPath.path
        )

        // Collect symbol graphs from derived data
        print("   Collecting symbol graphs...")
        let totalCollected = try collectSymbolGraphs(from: xcodeDerivedDataPath, scheme: scheme)
        print("   Collected \(totalCollected) symbol graphs total")

        // Filter symbol graphs if not including dependencies
        if !includeDependencies {
            print("   Filtering to project-related modules...")
            try filterSymbolGraphsForScheme(scheme)
        }

        // Check what we got
        let contents = try? fileManager.contentsOfDirectory(at: symbolGraphsPath, includingPropertiesForKeys: nil)
        let allGraphs = contents?.filter { $0.pathExtension == "json" } ?? []

        print("   Found \(allGraphs.count) symbol graphs for documentation")

        guard !allGraphs.isEmpty else {
            throw GeneratorError.symbolGraphNotGenerated(scheme)
        }
    }

    private func collectSymbolGraphs(from derivedDataPath: URL, scheme: String) throws -> Int {
        let buildDir = derivedDataPath.appendingPathComponent("Build/Intermediates.noindex")

        guard let enumerator = fileManager.enumerator(at: buildDir, includingPropertiesForKeys: nil) else {
            return 0
        }

        var count = 0
        while let fileURL = enumerator.nextObject() as? URL {
            // Look for symbol graph JSON files
            if fileURL.pathExtension == "json" && fileURL.path.contains("symbol-graph") {
                let destURL = symbolGraphsPath.appendingPathComponent(fileURL.lastPathComponent)
                // Skip if already exists (avoid duplicates)
                if !fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.copyItem(at: fileURL, to: destURL)
                    count += 1
                }
            }
        }
        return count
    }

    /// Filters symbol graphs to only include modules related to the scheme.
    /// A module is considered related if its name contains the scheme name (case-insensitive).
    private func filterSymbolGraphsForScheme(_ scheme: String) throws {
        let contents = try fileManager.contentsOfDirectory(at: symbolGraphsPath, includingPropertiesForKeys: nil)
        let schemeLower = scheme.lowercased()

        var removed = 0
        for fileURL in contents where fileURL.pathExtension == "json" {
            // Get the module name from the file (e.g., "ModuleName.symbols.json" or "ModuleName@Extension.symbols.json")
            let fileName = fileURL.deletingPathExtension().lastPathComponent // Remove .json
            let baseName = fileName.replacingOccurrences(of: ".symbols", with: "") // Remove .symbols
            let moduleName = baseName.components(separatedBy: "@").first ?? baseName // Get module before @

            // Keep if the module name contains the scheme name (case-insensitive)
            let moduleNameLower = moduleName.lowercased()
            let isRelated = moduleNameLower.contains(schemeLower)

            if !isRelated {
                try? fileManager.removeItem(at: fileURL)
                removed += 1
            }
        }

        if removed > 0 {
            print("   Removed \(removed) dependency symbol graphs")
        }
    }

    // MARK: - DocC Management

    private func ensureDocC() async throws -> URL {
        // Check for custom path first
        if let customPath = customDoccPath {
            let url = URL(fileURLWithPath: customPath)
            guard fileManager.isExecutableFile(atPath: url.path) else {
                throw GeneratorError.doccNotExecutable(customPath)
            }
            print("   Verifying custom DocC...")
            let result = try await shell(url.path, "convert", "--help")
            guard result.output.contains("enable-experimental-markdown-output") else {
                throw GeneratorError.doccMissingMarkdownSupport
            }
            print("   ✓ Using custom DocC: \(customPath)")
            return url
        }

        // Check if we have a cached build
        if fileManager.isExecutableFile(atPath: doccBinaryPath.path) {
            print("   Verifying cached DocC...")
            let result = try await shell(doccBinaryPath.path, "convert", "--help")
            if result.output.contains("enable-experimental-markdown-output") {
                print("   ✓ Using cached DocC")
                return doccBinaryPath
            }
        }

        // Need to build DocC
        print("🔨 Building DocC (first run only)...")
        try await buildDocC()
        return doccBinaryPath
    }

    private func buildDocC() async throws {
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let doccRepoURL = "https://github.com/swiftlang/swift-docc.git"
        let doccBranch = "release/6.3"

        if fileManager.fileExists(atPath: doccRepoPath.path) {
            print("   Updating DocC repository...")
            _ = try await shell("git", "fetch", "origin", doccBranch, workingDirectory: doccRepoPath)
            _ = try await shell("git", "checkout", doccBranch, workingDirectory: doccRepoPath)
            _ = try await shell("git", "pull", "origin", doccBranch, workingDirectory: doccRepoPath)
        } else {
            print("   Cloning DocC repository...")
            _ = try await shell("git", "clone", "--branch", doccBranch, doccRepoURL, doccRepoPath.path)
        }

        print("   Compiling DocC...")
        _ = try await shell(
            swiftCommand("build", "-c", "release", "--product", "docc"),
            workingDirectory: doccRepoPath
        )

        guard fileManager.isExecutableFile(atPath: doccBinaryPath.path) else {
            throw GeneratorError.doccBuildFailed
        }

        print("   ✓ DocC built successfully")
    }

    // MARK: - Symbol Graph Generation

    private func generateSymbolGraphs(for target: String, in packageURL: URL) async throws {
        // Clean previous symbol graphs
        print("   Cleaning symbol graphs directory...")
        try? fileManager.removeItem(at: symbolGraphsPath)
        try fileManager.createDirectory(at: symbolGraphsPath, withIntermediateDirectories: true)

        // Clean the package build to force symbol graph emission for all modules
        print("   Running swift package clean...")
        _ = try await shell(swiftCommand("package", "clean"), workingDirectory: packageURL)

        // Build with symbol graph emission
        print("   Building package with symbol graph emission (this may take a while)...")
        _ = try await shell(
            swiftCommand([
                "build",
                "-Xswiftc", "-emit-symbol-graph",
                "-Xswiftc", "-emit-symbol-graph-dir",
                "-Xswiftc", symbolGraphsPath.path
            ]),
            workingDirectory: packageURL
        )

        // Check what we got
        let contents = try? fileManager.contentsOfDirectory(at: symbolGraphsPath, includingPropertiesForKeys: nil)
        let allGraphs = contents?.filter { $0.pathExtension == "json" } ?? []

        print("   Found \(allGraphs.count) symbol graphs total")

        guard !allGraphs.isEmpty else {
            throw GeneratorError.symbolGraphNotGenerated(target)
        }

        // Remove the main target's symbol graphs - we only want dependencies
        let targetLower = target.lowercased()
        var removed = 0
        for file in allGraphs {
            let name = file.deletingPathExtension().lastPathComponent.lowercased()
            if name.hasPrefix(targetLower) || name.contains("@\(targetLower)") {
                try? fileManager.removeItem(at: file)
                removed += 1
            }
        }

        let remaining = allGraphs.count - removed
        print("   ✓ Kept \(remaining) dependency symbol graphs (removed \(removed) for \(target))")
    }

    // MARK: - DocC Convert

    private func runDoccConvert(docc: URL, target: String, output: URL) async throws {
        // Generate doccarchive in temp directory
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("swift-llm-docs-\(UUID().uuidString)")
        let archivePath = tempDir.appendingPathComponent("Dependencies.doccarchive")

        defer {
            print("   Cleaning up temp directory...")
            try? fileManager.removeItem(at: tempDir)
        }

        print("   Creating temp directory...")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        print("   Running docc convert...")
        _ = try await shell(
            docc.path, "convert",
            "--additional-symbol-graph-dir", symbolGraphsPath.path,
            "--output-path", archivePath.path,
            "--fallback-display-name", "Dependencies",
            "--fallback-bundle-identifier", "com.dependencies",
            "--enable-experimental-markdown-output",
            "--enable-experimental-markdown-output-manifest",
            "--no-transform-for-static-hosting"
        )

        print("   Checking for doccarchive...")
        guard fileManager.fileExists(atPath: archivePath.path) else {
            throw GeneratorError.markdownNotGenerated
        }

        // Extract and consolidate markdown files
        print("   Extracting and consolidating markdown...")
        try extractAndConsolidate(from: archivePath, to: output, packageURL: URL(fileURLWithPath: packagePath))
    }

    private func extractAndConsolidate(from archivePath: URL, to output: URL, packageURL: URL) throws {
        // Remove existing output and recreate
        try? fileManager.removeItem(at: output)
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        let dataDir = archivePath.appendingPathComponent("data")

        // Build type index mapping lowercased identifier path -> (properCasedModule, properCasedType)
        var typeIndex: [String: TypeInfo] = [:]
        // Map lowercased module path -> proper cased module name
        var moduleNames: [String: String] = [:]

        // Process both documentation/ and privatedocumentation/
        for docType in ["documentation", "privatedocumentation"] {
            let docsDir = dataDir.appendingPathComponent(docType)
            guard fileManager.fileExists(atPath: docsDir.path) else { continue }

            // Find all module JSON files (direct children)
            let contents = try? fileManager.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil)
            let moduleJsonFiles = contents?.filter { $0.pathExtension == "json" } ?? []

            print("   Found \(moduleJsonFiles.count) modules in \(docType)/")

            // First pass: get proper module names and build type index
            for moduleJsonURL in moduleJsonFiles {
                let modulePathName = moduleJsonURL.deletingPathExtension().lastPathComponent
                if let moduleInfo = getModuleInfo(jsonURL: moduleJsonURL),
                   let moduleName = moduleInfo.title {
                    moduleNames[modulePathName] = moduleName
                    buildTypeIndex(
                        jsonURL: moduleJsonURL,
                        modulePathName: modulePathName,
                        moduleName: moduleName,
                        docsDir: docsDir,
                        typeIndex: &typeIndex
                    )
                }
            }

            // Second pass: process modules with link support
            for moduleJsonURL in moduleJsonFiles {
                let modulePathName = moduleJsonURL.deletingPathExtension().lastPathComponent
                guard let moduleName = moduleNames[modulePathName] else { continue }
                print("   Processing module: \(moduleName)")
                try processModule(
                    jsonURL: moduleJsonURL,
                    modulePathName: modulePathName,
                    moduleName: moduleName,
                    docsDir: docsDir,
                    output: output,
                    typeIndex: typeIndex,
                    packageURL: packageURL
                )
            }
        }
    }

    private func getModuleInfo(jsonURL: URL) -> DocCMetadata? {
        guard let jsonData = fileManager.contents(atPath: jsonURL.path),
              let moduleDoc = try? JSONDecoder().decode(DocCDocument.self, from: jsonData) else {
            return nil
        }
        return moduleDoc.metadata
    }

    private func buildTypeIndex(
        jsonURL: URL,
        modulePathName: String,
        moduleName: String,
        docsDir: URL,
        typeIndex: inout [String: TypeInfo]
    ) {
        guard let jsonData = fileManager.contents(atPath: jsonURL.path),
              let moduleDoc = try? JSONDecoder().decode(DocCDocument.self, from: jsonData) else {
            return
        }

        // Build a mapping from identifier to section title
        var identifierToSection: [String: String] = [:]
        for section in moduleDoc.topicSections ?? [] {
            guard let sectionTitle = section.title else { continue }
            for identifier in section.identifiers {
                identifierToSection[identifier] = sectionTitle
            }
        }

        let typeIdentifiers = moduleDoc.topicSections?.flatMap { $0.identifiers } ?? []

        for identifier in typeIdentifiers {
            guard let pathComponents = identifier.split(separator: "/documentation/").last else { continue }
            let relativePath = String(pathComponents).lowercased()
            let parts = relativePath.components(separatedBy: "/")
            guard parts.count >= 2 else { continue }

            let typePath = parts.dropFirst().joined(separator: "/")
            let typeJsonURL = docsDir.appendingPathComponent("\(parts[0])/\(typePath).json")

            if fileManager.fileExists(atPath: typeJsonURL.path),
               let typeJsonData = fileManager.contents(atPath: typeJsonURL.path),
               let typeDoc = try? JSONDecoder().decode(DocCDocument.self, from: typeJsonData) {
                let typeName = typeDoc.metadata?.title ?? typePath.components(separatedBy: "/").last ?? typePath
                let sectionTitle = identifierToSection[identifier]

                // Store full path -> type info mapping
                let fullIdentifierPath = relativePath
                typeIndex[fullIdentifierPath] = TypeInfo(
                    moduleName: moduleName,
                    typeName: typeName,
                    fileName: "\(typeName).md",
                    sectionTitle: sectionTitle
                )
                // Also index by simple type name for backtick matching
                typeIndex["type:\(typeName)"] = TypeInfo(
                    moduleName: moduleName,
                    typeName: typeName,
                    fileName: "\(typeName).md",
                    sectionTitle: sectionTitle
                )
            }
        }
    }

    private func processModule(
        jsonURL: URL,
        modulePathName: String,
        moduleName: String,
        docsDir: URL,
        output: URL,
        typeIndex: [String: TypeInfo],
        packageURL: URL
    ) throws {
        guard let jsonData = fileManager.contents(atPath: jsonURL.path),
              let moduleDoc = try? JSONDecoder().decode(DocCDocument.self, from: jsonData) else {
            print("      Could not parse module JSON")
            return
        }

        // Create module directory with proper case
        let moduleDir = output.appendingPathComponent(moduleName)
        try fileManager.createDirectory(at: moduleDir, withIntermediateDirectories: true)

        // Write module overview page at top level (llm-docs/ModuleName.md)
        let moduleMarkdownURL = docsDir.appendingPathComponent("\(modulePathName).md")
        if let moduleMarkdown = try? String(contentsOf: moduleMarkdownURL, encoding: .utf8) {
            var content = stripMetadataComment(from: moduleMarkdown)
            content = rewriteDocCLinks(in: content, currentModule: moduleName, typeIndex: typeIndex)
            let overviewURL = output.appendingPathComponent("\(moduleName).md")
            try content.write(to: overviewURL, atomically: true, encoding: .utf8)
        }

        // Find the .docc catalog for this module to get custom section organization
        let customSectionMapping = findCustomSectionMapping(for: moduleName, in: packageURL)

        // Process types organized by topic sections
        let topicSections = moduleDoc.topicSections ?? []
        var processedIdentifiers = Set<String>()

        // Track processed type names to avoid duplicates across sections
        var processedTypeNames = Set<String>()

        for section in topicSections {
            guard let autoGeneratedSection = section.title else { continue }

            for identifier in section.identifiers {
                guard let pathComponents = identifier.split(separator: "/documentation/").last else { continue }
                let relativePath = String(pathComponents).lowercased()
                let parts = relativePath.components(separatedBy: "/")
                guard parts.count >= 2 else { continue }

                let typePath = parts.dropFirst().joined(separator: "/")

                // Get the properly-cased type name from the type index
                let typeInfo = typeIndex[relativePath]
                let typeName = typeInfo?.typeName ?? typePath.components(separatedBy: "/").last ?? typePath

                // Skip if this type was already processed (even in different sections)
                guard !processedTypeNames.contains(typeName) else { continue }

                // Check for custom section assignment from .docc catalog, fall back to auto-generated
                let sectionTitle = customSectionMapping[typeName] ?? autoGeneratedSection

                // Mark as processed before writing
                processedTypeNames.insert(typeName)
                processedIdentifiers.insert(identifier)

                let sectionDir = moduleDir.appendingPathComponent(sectionTitle)

                try processType(
                    typePath: typePath,
                    modulePath: parts[0],
                    moduleName: moduleName,
                    sectionTitle: sectionTitle,
                    docsDir: docsDir,
                    sectionDir: sectionDir,
                    typeIndex: typeIndex
                )
            }
        }

        print("      Processed \(processedIdentifiers.count) types across \(topicSections.count) sections")
    }

    /// Finds the .docc catalog for a module and builds a custom section mapping
    private func findCustomSectionMapping(for moduleName: String, in packageURL: URL) -> [String: String] {
        let checkoutsPath = packageURL.appendingPathComponent(".build/checkouts")

        // Search for .docc catalogs in checkouts
        guard let enumerator = fileManager.enumerator(
            at: checkoutsPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "docc" {
                // Check if this catalog belongs to the module we're processing
                let pathComponents = url.pathComponents
                if let sourcesIndex = pathComponents.firstIndex(of: "Sources"),
                   sourcesIndex + 1 < pathComponents.count {
                    let catalogModuleName = pathComponents[sourcesIndex + 1]
                    if catalogModuleName == moduleName {
                        return buildItemToSectionMapping(in: url, moduleName: moduleName)
                    }
                }
            }
        }

        return [:]
    }

    private func processType(
        typePath: String,
        modulePath: String,
        moduleName: String,
        sectionTitle: String,
        docsDir: URL,
        sectionDir: URL,
        typeIndex: [String: TypeInfo]
    ) throws {
        let fullTypePath = "\(modulePath)/\(typePath)"
        let typeJsonURL = docsDir.appendingPathComponent(fullTypePath + ".json")

        guard fileManager.fileExists(atPath: typeJsonURL.path),
              let jsonData = fileManager.contents(atPath: typeJsonURL.path),
              let typeDoc = try? JSONDecoder().decode(DocCDocument.self, from: jsonData) else {
            return
        }

        let typeName = typeDoc.metadata?.title ?? typePath.components(separatedBy: "/").last ?? typePath

        // Read the type's markdown
        let typeMarkdownURL = docsDir.appendingPathComponent(fullTypePath + ".md")
        var combinedMarkdown = ""

        if let typeMarkdown = try? String(contentsOf: typeMarkdownURL, encoding: .utf8) {
            combinedMarkdown = stripMetadataComment(from: typeMarkdown)
        }

        // Get all member identifiers
        let memberIdentifiers = typeDoc.topicSections?.flatMap { $0.identifiers } ?? []

        for identifier in memberIdentifiers {
            // Skip collection groups
            if let ref = typeDoc.references?[identifier], ref.kind == "article" {
                continue
            }

            guard let pathComponents = identifier.split(separator: "/documentation/").last else { continue }
            let fullPath = String(pathComponents).lowercased()
            let memberMarkdownURL = docsDir.appendingPathComponent(fullPath + ".md")

            if let memberMarkdown = try? String(contentsOf: memberMarkdownURL, encoding: .utf8) {
                let strippedMarkdown = stripMetadataComment(from: memberMarkdown)
                let demotedMarkdown = demoteHeadings(in: strippedMarkdown)
                combinedMarkdown += "\n\n---\n\n" + demotedMarkdown
            }
        }

        // Rewrite DocC links to our file structure and add type links
        combinedMarkdown = rewriteDocCLinks(in: combinedMarkdown, currentModule: moduleName, typeIndex: typeIndex)
        combinedMarkdown = addTypeLinks(to: combinedMarkdown, currentModule: moduleName, currentType: typeName, typeIndex: typeIndex)

        // Create section directory if needed and write file there
        try fileManager.createDirectory(at: sectionDir, withIntermediateDirectories: true)
        let outputURL = sectionDir.appendingPathComponent("\(typeName).md")
        try combinedMarkdown.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    /// Rewrites DocC-style links to our flat file structure
    private func rewriteDocCLinks(in markdown: String, currentModule: String, typeIndex: [String: TypeInfo]) -> String {
        var result = markdown

        // Match markdown links: [text](/documentation/Module/Type) or [text](doc:Module/Type)
        let linkPattern = /\[([^\]]+)\]\(((?:\/documentation\/|doc:)([^)]+))\)/

        var replacements: [(Range<String.Index>, String)] = []

        for match in result.matches(of: linkPattern) {
            let linkText = String(match.output.1)
            let fullPath = String(match.output.3).lowercased()

            // Look up in type index
            if let typeInfo = typeIndex[fullPath] {
                let newLink: String
                if typeInfo.moduleName == currentModule {
                    newLink = "[\(linkText)](\(typeInfo.fileName))"
                } else {
                    newLink = "[\(linkText)](\(typeInfo.moduleName)/\(typeInfo.fileName))"
                }
                replacements.append((match.range, newLink))
            }
        }

        // Apply replacements in reverse order to preserve indices
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }

        return result
    }

    /// Adds links to type names in backticks (only if not already inside a link)
    private func addTypeLinks(to markdown: String, currentModule: String, currentType: String, typeIndex: [String: TypeInfo]) -> String {
        var result = markdown

        // Get all types sorted by name length (longest first)
        let typeNames = typeIndex.keys
            .filter { $0.hasPrefix("type:") }
            .map { String($0.dropFirst(5)) }
            .sorted { $0.count > $1.count }

        for typeName in typeNames {
            guard let typeInfo = typeIndex["type:\(typeName)"] else { continue }

            // Don't link to self
            if typeName == currentType && typeInfo.moduleName == currentModule {
                continue
            }

            // Skip very short type names to avoid false positives
            if typeName.count < 3 {
                continue
            }

            // Create the link path (relative from current module)
            let linkPath: String
            if typeInfo.moduleName == currentModule {
                linkPath = typeInfo.fileName
            } else {
                linkPath = "../\(typeInfo.moduleName)/\(typeInfo.fileName)"
            }

            // Match backtick-wrapped type names NOT followed by ]( which would indicate already in a link
            let searchTarget = "`\(typeName)`"
            var searchStart = result.startIndex

            while let range = result.range(of: searchTarget, range: searchStart..<result.endIndex) {
                // Check if this is already part of a link (followed by "](" or preceded by "[")
                let afterEnd = range.upperBound
                let beforeStart = range.lowerBound

                let isInsideLink = (afterEnd < result.endIndex && result[afterEnd...].hasPrefix("]("))
                    || (beforeStart > result.startIndex && result[result.index(before: beforeStart)] == "[")

                if !isInsideLink {
                    let replacement = "[\(typeName)](\(linkPath))"
                    result.replaceSubrange(range, with: replacement)
                    // Move past the replacement
                    searchStart = result.index(range.lowerBound, offsetBy: replacement.count)
                } else {
                    // Move past this match
                    searchStart = range.upperBound
                }
            }
        }

        return result
    }

    private func stripMetadataComment(from markdown: String) -> String {
        if markdown.hasPrefix("<!--") {
            if let endRange = markdown.range(of: "-->") {
                let afterComment = markdown[endRange.upperBound...]
                return String(afterComment).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return markdown
    }

    private func demoteHeadings(in markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        for i in 0..<lines.count {
            if lines[i].hasPrefix("#") && !lines[i].hasPrefix("######") {
                lines[i] = "#" + lines[i]
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Article Extraction

    /// Copies articles from .docc catalogs in the package's dependencies
    /// Articles are placed in topic section directories based on the module's topic organization
    private func copyArticlesFromDoccCatalogs(packageURL: URL, output: URL) throws {
        let checkoutsPath = packageURL.appendingPathComponent(".build/checkouts")
        guard fileManager.fileExists(atPath: checkoutsPath.path) else {
            print("   No checkouts directory found, skipping articles")
            return
        }

        // Find all .docc directories
        let enumerator = fileManager.enumerator(
            at: checkoutsPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var doccCatalogs: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "docc" {
                doccCatalogs.append(url)
            }
        }

        print("   Found \(doccCatalogs.count) documentation catalogs")

        var totalArticles = 0

        for catalogURL in doccCatalogs {
            // Extract module name from path: .../Sources/ModuleName/Something.docc
            let pathComponents = catalogURL.pathComponents
            guard let sourcesIndex = pathComponents.firstIndex(of: "Sources"),
                  sourcesIndex + 1 < pathComponents.count else {
                continue
            }
            let moduleName = pathComponents[sourcesIndex + 1]

            // Find the corresponding module directory in output
            let moduleDir = output.appendingPathComponent(moduleName)
            guard fileManager.fileExists(atPath: moduleDir.path) else {
                // Module wasn't generated (might be filtered out), skip
                continue
            }

            // Find the module landing page and write it as the overview
            if let landingPageURL = findModuleLandingPage(in: catalogURL, moduleName: moduleName),
               let landingContent = try? String(contentsOf: landingPageURL, encoding: .utf8) {
                let processedOverview = processArticle(landingContent, moduleName: moduleName)
                let overviewURL = output.appendingPathComponent("\(moduleName).md")
                try processedOverview.write(to: overviewURL, atomically: true, encoding: .utf8)
            }

            // Build item name to section mapping from the landing page
            let itemToSection = buildItemToSectionMapping(in: catalogURL, moduleName: moduleName)

            // Copy articles to their appropriate section directories
            let articleCount = try copyArticlesToSections(
                from: catalogURL,
                to: moduleDir,
                moduleName: moduleName,
                itemToSection: itemToSection
            )
            if articleCount > 0 {
                totalArticles += articleCount
            }
        }

        print("   ✓ Copied \(totalArticles) articles")
    }

    /// Builds a mapping from item name (article or symbol) to section title
    /// by parsing the ## Topics section in the module landing page
    private func buildItemToSectionMapping(in catalogURL: URL, moduleName: String) -> [String: String] {
        guard let landingPageURL = findModuleLandingPage(in: catalogURL, moduleName: moduleName),
              let content = try? String(contentsOf: landingPageURL, encoding: .utf8) else {
            return [:]
        }

        var mapping: [String: String] = [:]
        var currentSection: String? = nil
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect section headers: ### Section Title
            if trimmed.hasPrefix("### ") {
                currentSection = String(trimmed.dropFirst(4))
                continue
            }

            // Detect references in current section
            if let section = currentSection {
                // Match <doc:ArticleName>
                if let docRange = trimmed.range(of: "<doc:"),
                   let endRange = trimmed.range(of: ">", range: docRange.upperBound..<trimmed.endIndex) {
                    let articleName = String(trimmed[docRange.upperBound..<endRange.lowerBound])
                    mapping[articleName] = section
                }

                // Match ``SymbolName`` (DocC symbol references)
                // Use simple string scanning instead of regex
                var searchIndex = trimmed.startIndex
                while let startRange = trimmed.range(of: "``", range: searchIndex..<trimmed.endIndex) {
                    let afterStart = startRange.upperBound
                    if let endRange = trimmed.range(of: "``", range: afterStart..<trimmed.endIndex) {
                        let symbolName = String(trimmed[afterStart..<endRange.lowerBound])
                        // Handle potential namespace prefixes like Module.Symbol
                        let baseName = symbolName.components(separatedBy: ".").last ?? symbolName
                        mapping[baseName] = section
                        searchIndex = endRange.upperBound
                    } else {
                        break
                    }
                }
            }
        }

        return mapping
    }

    /// Finds the module landing page in a .docc catalog
    /// The landing page is identified by starting with `# ``ModuleName`` `
    private func findModuleLandingPage(in catalogURL: URL, moduleName: String) -> URL? {
        let expectedTitle = "# ``\(moduleName)``"

        // Check direct children first (most common location)
        let directContents = try? fileManager.contentsOfDirectory(at: catalogURL, includingPropertiesForKeys: nil)
        for url in directContents ?? [] {
            guard url.pathExtension == "md" else { continue }
            if let content = try? String(contentsOf: url, encoding: .utf8),
               content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(expectedTitle) {
                return url
            }
        }

        return nil
    }

    /// Copies article markdown files from a docc catalog to section directories
    private func copyArticlesToSections(
        from catalogURL: URL,
        to moduleDir: URL,
        moduleName: String,
        itemToSection: [String: String]
    ) throws -> Int {
        var count = 0

        // Find the landing page so we can skip it
        let landingPageURL = findModuleLandingPage(in: catalogURL, moduleName: moduleName)

        let enumerator = fileManager.enumerator(
            at: catalogURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "md" else { continue }

            // Skip the module landing page - it's used for the overview
            if url == landingPageURL {
                continue
            }

            // Get article name without extension
            let articleName = url.deletingPathExtension().lastPathComponent

            // Determine the section for this article
            let sectionTitle = itemToSection[articleName] ?? "Articles"
            let sectionDir = moduleDir.appendingPathComponent(sectionTitle)

            // Create section directory if needed
            try fileManager.createDirectory(at: sectionDir, withIntermediateDirectories: true)

            // Determine the output path
            // Strip any leading directory structure from the source (e.g., Articles/, Extensions/)
            let destURL = sectionDir.appendingPathComponent(url.lastPathComponent)

            // Read, process, and write the article
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let processedContent = processArticle(content, moduleName: moduleName)
                try processedContent.write(to: destURL, atomically: true, encoding: .utf8)
                count += 1
            }
        }

        return count
    }

    /// Process article content to clean up DocC-specific syntax
    private func processArticle(_ content: String, moduleName: String) -> String {
        var result = content

        // Remove @Metadata blocks (simple approach - find @Metadata and remove until closing brace)
        while let metaStart = result.range(of: "@Metadata") {
            if let braceStart = result.range(of: "{", range: metaStart.upperBound..<result.endIndex),
               let braceEnd = result.range(of: "}", range: braceStart.upperBound..<result.endIndex) {
                result.removeSubrange(metaStart.lowerBound...braceEnd.upperBound)
            } else {
                break
            }
        }

        // Remove @Options blocks
        while let optStart = result.range(of: "@Options") {
            if let braceStart = result.range(of: "{", range: optStart.upperBound..<result.endIndex),
               let braceEnd = result.range(of: "}", range: braceStart.upperBound..<result.endIndex) {
                result.removeSubrange(optStart.lowerBound...braceEnd.upperBound)
            } else {
                break
            }
        }

        // Convert ``Symbol`` to `Symbol` (DocC double backticks to standard markdown)
        // But preserve triple backticks for code blocks - replace them temporarily
        result = result.replacingOccurrences(of: "```", with: "<<<CODE_FENCE>>>")
        result = result.replacingOccurrences(of: "``", with: "`")
        result = result.replacingOccurrences(of: "<<<CODE_FENCE>>>", with: "```")

        // Convert <doc:Article> links to relative markdown links
        let docLinkPattern = /<doc:([^>]+)>/
        var replacements: [(Range<String.Index>, String)] = []
        for match in result.matches(of: docLinkPattern) {
            let target = String(match.output.1)
            let replacement = "[\(target)](\(target).md)"
            replacements.append((match.range, replacement))
        }
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Results

    private func reportResults(output: URL) throws {
        let enumerator = fileManager.enumerator(at: output, includingPropertiesForKeys: nil)

        var totalCount = 0
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "md" {
                totalCount += 1
            }
        }

        print()
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Documentation generated successfully!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print("📊 Generated \(totalCount) markdown files")
        print("📁 Output: \(output.path)")
    }

    // MARK: - Shell Execution

    private func shell(
        _ args: String...,
        workingDirectory: URL? = nil,
        captureOutput: Bool = false
    ) async throws -> ShellResult {
        try await shell(args, workingDirectory: workingDirectory, captureOutput: captureOutput)
    }

    private func shell(
        _ args: [String],
        workingDirectory: URL? = nil,
        captureOutput: Bool = false
    ) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        var stdout: Pipe?
        var stderr: Pipe?

        if captureOutput {
            stdout = Pipe()
            stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
        } else {
            // Stream output directly to terminal
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        }

        if verbose {
            print("   $ \(args.joined(separator: " "))")
        }

        try process.run()
        process.waitUntilExit()

        var output = ""
        var error = ""

        if captureOutput, let stdout, let stderr {
            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            output = String(data: outputData, encoding: .utf8) ?? ""
            error = String(data: errorData, encoding: .utf8) ?? ""
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

struct XcodeBuildList: Decodable {
    let project: XcodeProjectInfo

    struct XcodeProjectInfo: Decodable {
        let schemes: [String]
    }
}

struct DocCDocument: Decodable {
    let metadata: DocCMetadata?
    let topicSections: [DocCTopicSection]?
    let references: [String: DocCReference]?
}

struct DocCMetadata: Decodable {
    let title: String?
    let symbolKind: String?
}

struct DocCTopicSection: Decodable {
    let title: String?
    let identifiers: [String]
    let generated: Bool?
}

struct DocCReference: Decodable {
    let kind: String?
    let title: String?
    let url: String?
}

struct TypeInfo {
    let moduleName: String
    let typeName: String
    let fileName: String
    let sectionTitle: String?
}

enum GeneratorError: LocalizedError {
    case notASwiftPackage(String)
    case couldNotParsePackage
    case noTargetsFound
    case notAnXcodeProject(String)
    case noSchemesFound
    case doccNotExecutable(String)
    case doccMissingMarkdownSupport
    case doccBuildFailed
    case symbolGraphNotGenerated(String)
    case markdownNotGenerated

    var errorDescription: String? {
        switch self {
        case .notASwiftPackage(let path):
            return "Not a Swift package: \(path) (no Package.swift found)"
        case .couldNotParsePackage:
            return "Could not parse Package.swift"
        case .noTargetsFound:
            return "No targets found in package. Use --target to specify one."
        case .notAnXcodeProject(let path):
            return "Not an Xcode project: \(path) (expected .xcodeproj)"
        case .noSchemesFound:
            return "No schemes found in Xcode project. Use --scheme to specify one."
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
        }
    }
}

// MARK: - Helpers

private func regexEscape(_ string: String) -> String {
    let specialCharacters = #"\.+*?^${}[]|()\"#
    var result = ""
    for char in string {
        if specialCharacters.contains(char) {
            result.append("\\")
        }
        result.append(char)
    }
    return result
}
