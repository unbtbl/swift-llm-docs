import ArgumentParser
import Foundation

@main
struct SwiftLLMDocs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-llm-docs",
        abstract: "Generate LLM-friendly Markdown documentation from Swift packages",
        discussion: """
            This tool generates Markdown documentation from Swift packages using DocC's
            experimental markdown output feature. The output is optimized for consumption
            by Large Language Models.

            On first run, it will build DocC from the release/6.3 branch which includes
            the markdown output feature. This is cached for subsequent runs.
            """,
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "Path to the Swift package directory")
    var package: String = "."

    @Option(name: .shortAndLong, help: "Target to generate documentation for")
    var target: String?

    @Option(name: .shortAndLong, help: "Output directory for generated documentation")
    var output: String = "./llm-docs"

    @Option(name: .long, help: "Path to a custom docc binary (skips building DocC)")
    var doccPath: String?

    @Option(name: .long, help: "Path to a custom Swift executable")
    var swiftPath: String?

    @Option(name: .long, help: "Path to Xcode project (.xcodeproj)")
    var xcodeproj: String?

    @Option(name: .long, help: "Xcode scheme to build documentation for")
    var scheme: String?

    #if os(macOS)
    @Flag(name: .long, help: "Use xcrun to invoke Swift (ignored when --swift-path is set)")
    var useXcrun: Bool = false
    #endif

    @Flag(name: .long, inversion: .prefixedNo, help: "Include documentation for dependencies (default: false)")
    var includeDependencies: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    func run() async throws {
        #if os(macOS)
        let swiftInvocation = SwiftInvocation(
            customSwiftPath: swiftPath,
            useXcrun: useXcrun
        )
        #else
        let swiftInvocation = SwiftInvocation(
            customSwiftPath: swiftPath
        )
        #endif

        let generator = DocumentationGenerator(
            packagePath: package,
            target: target,
            outputPath: output,
            customDoccPath: doccPath,
            xcodeProjectPath: xcodeproj,
            scheme: scheme,
            swiftInvocation: swiftInvocation,
            includeDependencies: includeDependencies,
            verbose: verbose
        )

        try await generator.run()
    }
}
