# ParentCommand

A wrapper that adds a reference to a parent command.

```
@propertyWrapper struct ParentCommand<Value> where Value : ParsableCommand
```

## Overview

Use the `@ParentCommand` wrapper to gain access to a parent command’s state.

The arguments, options, and flags in a `@ParentCommand` type are omitted from
the help screen for the including child command, and only appear in the parent’s
help screen. To include the help in both screens, use the [`OptionGroup`](OptionGroup.md)
wrapper instead.

```swift
struct SuperCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        subcommands: [SubCommand.self]
    )

    @Flag(name: .shortAndLong)
    var verbose: Bool = false
}

struct SubCommand: ParsableCommand {
    @ParentCommand var parent: SuperCommand

    mutating func run() throws {
        if self.parent.verbose {
            print("Verbose")
        }
    }
}
```

---

## init()

```
init()
```

---

## wrappedValue

```
var wrappedValue: Value { get set }
```