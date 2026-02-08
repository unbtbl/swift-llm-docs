# swift-llm-docs

**Give your coding agents (Claude, Codex, Cursor, ...) access to up-to-date documentation for your dependencies.**

`swift-llm-docs` extracts documentation for all the dependencies in your Swift package or Xcode project and converts it into Markdown files that you can point your coding agents to.

## What you get

Run this on this package, which depends on [swift-argument-parser](https://github.com/apple/swift-argument-parser), and you get 45 Markdown files organized by topic:

```
llm-docs/
├── ArgumentParser.md                        # Module overview
├── ArgumentParser/
│   ├── Essentials/
│   │   ├── ParsableCommand.md
│   │   ├── AsyncParsableCommand.md
│   │   ├── GettingStarted.md
│   │   └── ...
│   ├── Arguments, Options, and Flags/
│   │   ├── Argument.md
│   │   ├── Option.md
│   │   ├── Flag.md
│   │   └── ...
│   ├── Validation and Errors/
│   │   ├── ValidationError.md
│   │   └── ...
│   └── ...
├── ArgumentParserToolInfo.md
└── ...
```

The directory structure is based on the docc structure, and is similar to what you would see in Xcode's documentation browser.

<details>
<summary>Example: <code>AsyncParsableCommand.md</code></summary>

~~~markdown
# `ArgumentParser/AsyncParsableCommand`

To use `async`/`await` code in your commands' `run()` method implementations,
follow these steps:

1. For the root command in your command-line tool, declare conformance to
   `AsyncParsableCommand`, whether or not that command uses asynchronous code.
2. Apply the `@main` attribute to the root command.
3. For any command that needs to use asynchronous code, declare conformance to
   `AsyncParsableCommand` and mark the `run()` method as `async`.

```swift
@main
struct CountLines: AsyncParsableCommand {
    @Argument(transform: URL.init(fileURLWithPath:))
    var inputFile: URL

    mutating func run() async throws {
        let fileHandle = try FileHandle(forReadingFrom: inputFile)
        let lineCount = try await fileHandle.bytes.lines.reduce(into: 0)
            { count, _ in count += 1 }
        print(lineCount)
    }
}
```

## Topics

### Implementing a Command's Behavior

- `run()`

### Starting the Program

- `main()`
- `AsyncMainProtocol`
~~~

</details>

See the full example output in [llm-docs/ArgumentParser](./llm-docs/ArgumentParser).

## Quick Start

```bash
# Build the tool
git clone https://github.com/unbtbl/swift-llm-docs.git
cd swift-llm-docs && swift build -c release

# Generate dependency docs for your Swift package
.build/release/swift-llm-docs --package /path/to/YourPackage --target YourTarget

# Output is in ./llm-docs/ — your coding agent will pick it up automatically
```

## Features

- **Swift Packages and Xcode projects** — works with both
- **All your dependencies** — generates docs for every Swift Package dependency your target uses
- **Topic-based organization** — files are grouped by topic sections 
- **Markdown output** - by using the upcoming Swift docc 6.3, docs are exported as Markdown
- **macOS and Linux**

## Usage

### Swift Package

```bash
# Auto-detect target (works if your package has a single target)
swift-llm-docs --package .

# Specify target and output directory
swift-llm-docs --package /path/to/MyPackage --target MyTarget --output ./docs

# Exclude dependency documentation
swift-llm-docs --package . --target MyTarget --no-include-dependencies
```

### Xcode Project

```bash
swift-llm-docs --xcodeproj ./MyProject.xcodeproj --scheme MyScheme
```

### All Options

| Option | Description |
|--------|-------------|
| `-p, --package` | Path to the Swift package directory (default: `.`) |
| `-t, --target` | Target to generate documentation for |
| `-o, --output` | Output directory (default: `./llm-docs`) |
| `--xcodeproj` | Path to Xcode project (`.xcodeproj`) |
| `--scheme` | Xcode scheme to build documentation for |
| `--docc-path` | Path to a custom docc binary |
| `--swift-path` | Path to a custom Swift executable |
| `--use-xcrun` | Use `xcrun swift` instead of `swift` (macOS only) |
| `--no-include-dependencies` | Exclude documentation for dependencies |
| `--verbose` | Verbose output |

## How it works

`swift-llm-docs` uses DocC's experimental markdown output feature (from the `release/6.3` branch, not yet in stable DocC) to generate documentation. The pipeline:

1. **Build & extract symbol graphs** from your package or Xcode project
2. **Run DocC** with markdown output enabled to produce structured documentation
3. **Post-process** — rewrite links to relative Markdown paths, auto-link type references, organize files by topic sections, and merge type members into single files

On first run, the tool automatically builds DocC from source since the markdown output feature isn't in a stable release yet. This takes a few minutes and is cached for future runs.

## Requirements

- Swift 6.2+
- macOS or Linux
