# swift-llm-docs

Generate LLM-friendly Markdown documentation from Swift packages.

This tool uses DocC's experimental markdown output feature (from release/6.3) to generate documentation optimized for consumption by Large Language Models.

## Example Output

See the [llm-docs](./llm-docs) directory for example generated documentation, including [ArgumentParser](./llm-docs/ArgumentParser).

## Installation

```bash
git clone https://github.com/unbtbl/swift-llm-docs.git
cd swift-llm-docs
swift build -c release
```

The binary will be at `.build/release/swift-llm-docs`.

## Usage

```bash
# Generate docs for a Swift package
swift-llm-docs --package /path/to/MyPackage --target MyTarget

# Specify output directory
swift-llm-docs --package . --target MyTarget --output ./docs

# Use a pre-built docc binary (skips building DocC)
swift-llm-docs --package . --target MyTarget --docc-path /path/to/docc
```

### Options

| Option | Description |
|--------|-------------|
| `-p, --package` | Path to the Swift package directory (default: `.`) |
| `-t, --target` | Target to generate documentation for |
| `-o, --output` | Output directory (default: `./llm-docs`) |
| `--docc-path` | Path to a custom docc binary (skips building DocC) |
| `--no-include-dependencies` | Exclude documentation for dependencies (included by default) |
| `--verbose` | Verbose output |

## First Run

On first run, the tool will:

1. Clone DocC from the `release/6.3` branch
2. Build it (takes ~2-3 minutes)
3. Cache it at `~/Library/Caches/swift-llm-docs/`

Subsequent runs use the cached binary.

## Output Format

The tool generates a directory containing only markdown files:

```
llm-docs/
└── mytarget/
    ├── mytarget.md          # Module overview
    ├── myclass.md           # Type documentation
    └── myclass/
        └── mymethod.md      # Member documentation
```

Each markdown file includes a JSON metadata header:

```markdown
<!--
{
  "documentType": "symbol",
  "framework": "MyTarget",
  "identifier": "/documentation/MyTarget/MyClass",
  "title": "MyClass",
  ...
}
-->

# MyClass

Documentation content here...
```

## Requirements

- macOS 26+
- Swift 6.2+ toolchain
- Xcode Command Line Tools
