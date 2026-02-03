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

    @Flag(name: .long, help: "Include documentation for dependencies")
    var includeDependencies: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    func run() async throws {
        let generator = DocumentationGenerator(
            packagePath: package,
            target: target,
            outputPath: output,
            customDoccPath: doccPath,
            includeDependencies: includeDependencies,
            verbose: verbose
        )

        try await generator.run()
    }
}
