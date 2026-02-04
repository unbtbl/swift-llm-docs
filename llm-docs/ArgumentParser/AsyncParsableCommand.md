# AsyncParsableCommand

A type that can be executed asynchronously, as part of a nested tree of
commands.

```
protocol AsyncParsableCommand : ParsableCommand
```

---

## run()

The behavior or functionality of this command.

```
mutating func run() async throws
```

### Discussion

Implement this method in your [ParsableCommand](ParsableCommand.md)-conforming type with the
functionality that this command represents.

This method has a default implementation that prints the help screen for
this command.

---

## main()

Executes this command, or one of its subcommands, with the program’s
command-line arguments.

```
static func main() async
```

### Discussion

Instead of calling this method directly, you can add `@main` to the root
command for your command-line tool.

This method parses an instance of this type, one of its subcommands, or
another built-in `AsyncParsableCommand` type, from command-line arguments,
and then calls its `run()` method, exiting with a relevant error message
if necessary.

---

## main(_:)

Executes this command, or one of its subcommands, with the given arguments.

```
static func main(_ arguments: [String]?) async
```

### Parameters

`arguments`

An array of arguments to use for parsing. If
`arguments` is `nil`, this uses the program’s command-line arguments.

### Discussion

This method parses an instance of this type, one of its subcommands, or
another built-in `AsyncParsableCommand` type, from command-line
(or provided) arguments, and then calls its `run()` method, exiting
with a relevant error message if necessary.