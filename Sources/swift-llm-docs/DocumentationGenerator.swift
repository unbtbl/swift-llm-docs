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
            "xcrun", "swift", "package", "dump-package",
            workingDirectory: packageURL,
            timeout: 300,
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
            "xcrun", "swift", "build", "-c", "release", "--product", "docc",
            workingDirectory: doccRepoPath,
            timeout: 600
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
        _ = try await shell("xcrun", "swift", "package", "clean", workingDirectory: packageURL, timeout: 60)

        // Build with symbol graph emission
        print("   Building package with symbol graph emission (this may take a while)...")
        _ = try await shell(
            "xcrun", "swift", "build",
            "-Xswiftc", "-emit-symbol-graph",
            "-Xswiftc", "-emit-symbol-graph-dir",
            "-Xswiftc", symbolGraphsPath.path,
            workingDirectory: packageURL,
            timeout: 900
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
            "--no-transform-for-static-hosting",
            timeout: 600
        )

        print("   Checking for doccarchive...")
        guard fileManager.fileExists(atPath: archivePath.path) else {
            throw GeneratorError.markdownNotGenerated
        }

        // Extract and consolidate markdown files
        print("   Extracting and consolidating markdown...")
        try extractAndConsolidate(from: archivePath, to: output)
    }

    private func extractAndConsolidate(from archivePath: URL, to output: URL) throws {
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
                    typeIndex: typeIndex
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
                // Store full path -> type info mapping
                let fullIdentifierPath = relativePath
                typeIndex[fullIdentifierPath] = TypeInfo(
                    moduleName: moduleName,
                    typeName: typeName,
                    fileName: "\(typeName).md"
                )
                // Also index by simple type name for backtick matching
                typeIndex["type:\(typeName)"] = TypeInfo(
                    moduleName: moduleName,
                    typeName: typeName,
                    fileName: "\(typeName).md"
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
        typeIndex: [String: TypeInfo]
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

        // Get all type identifiers from topicSections
        let typeIdentifiers = moduleDoc.topicSections?.flatMap { $0.identifiers } ?? []
        print("      Found \(typeIdentifiers.count) types")

        for identifier in typeIdentifiers {
            guard let pathComponents = identifier.split(separator: "/documentation/").last else { continue }
            let relativePath = String(pathComponents).lowercased()
            let parts = relativePath.components(separatedBy: "/")
            guard parts.count >= 2 else { continue }

            let typePath = parts.dropFirst().joined(separator: "/")
            try processType(
                typePath: typePath,
                modulePath: parts[0],
                moduleName: moduleName,
                docsDir: docsDir,
                moduleDir: moduleDir,
                typeIndex: typeIndex
            )
        }
    }

    private func processType(
        typePath: String,
        modulePath: String,
        moduleName: String,
        docsDir: URL,
        moduleDir: URL,
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

        // Write combined markdown with proper cased filename
        let outputURL = moduleDir.appendingPathComponent("\(typeName).md")
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

            // Create Articles directory
            let articlesDir = moduleDir.appendingPathComponent("Articles")

            // Find the module landing page - it starts with # ``ModuleName``
            if let landingPageURL = findModuleLandingPage(in: catalogURL, moduleName: moduleName),
               let landingContent = try? String(contentsOf: landingPageURL, encoding: .utf8) {
                let processedOverview = processArticle(landingContent, moduleName: moduleName)
                let overviewURL = output.appendingPathComponent("\(moduleName).md")
                try processedOverview.write(to: overviewURL, atomically: true, encoding: .utf8)
            }

            // Copy all markdown files from the catalog (except index.md which is module overview)
            let articleCount = try copyArticles(from: catalogURL, to: articlesDir, moduleName: moduleName)
            if articleCount > 0 {
                totalArticles += articleCount
            }
        }

        print("   ✓ Copied \(totalArticles) articles")
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

    /// Copies article markdown files from a docc catalog to the output directory
    private func copyArticles(from catalogURL: URL, to articlesDir: URL, moduleName: String) throws -> Int {
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

            // Create articles directory if needed
            if !fileManager.fileExists(atPath: articlesDir.path) {
                try fileManager.createDirectory(at: articlesDir, withIntermediateDirectories: true)
            }

            // Determine relative path within the catalog for nested articles
            let relativePath = url.path.replacingOccurrences(of: catalogURL.path + "/", with: "")
            let destURL: URL

            if relativePath.contains("/") {
                // Nested article - preserve subdirectory structure
                let subdir = (relativePath as NSString).deletingLastPathComponent
                let subdirURL = articlesDir.appendingPathComponent(subdir)
                try fileManager.createDirectory(at: subdirURL, withIntermediateDirectories: true)
                destURL = articlesDir.appendingPathComponent(relativePath)
            } else {
                destURL = articlesDir.appendingPathComponent(url.lastPathComponent)
            }

            // Read, process, and write the article
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                // Strip any DocC-specific directives that won't render in plain markdown
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
        timeout: TimeInterval = 120,
        captureOutput: Bool = false
    ) async throws -> ShellResult {
        try await shell(args, workingDirectory: workingDirectory, timeout: timeout, captureOutput: captureOutput)
    }

    private func shell(
        _ args: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 120,
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

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.terminate()
            throw GeneratorError.commandTimeout(args.joined(separator: " "))
        }

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
