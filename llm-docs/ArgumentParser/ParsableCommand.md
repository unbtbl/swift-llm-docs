# ParsableCommand

A type that can be executed as part of a nested tree of commands.

```
protocol ParsableCommand : ParsableArguments
```

---

## run()

The behavior or functionality of this command.

```
mutating func run() throws
```

### Discussion

Implement this method in your `ParsableCommand`-conforming type with the
functionality that this command represents.

This method has a default implementation that prints the help screen for
this command.

---

## configuration

Configuration for this command, including subcommands and custom help
text.

```
static var configuration: CommandConfiguration { get }
```

---

## helpMessage(for:columns:)

Returns the text of the help screen for the given subcommand of this
command.

```
static func helpMessage(for subcommand: ParsableCommand.Type, columns: Int? = nil) -> String
```

### Parameters

`subcommand`

The subcommand to generate the help screen for.
`subcommand` must be declared in the subcommand tree of this
command.

`columns`

The column width to use when wrapping long line in the
help screen. If `columns` is `nil`, uses the current terminal
width, or a default value of `80` if the terminal width is not
available.

### Return Value

The full help screen for this type.

---

## helpMessage(for:includeHidden:columns:)

Returns the text of the help screen for the given subcommand of this
command.

```
static func helpMessage(for subcommand: ParsableCommand.Type, includeHidden: Bool = false, columns: Int? = nil) -> String
```

### Parameters

`subcommand`

The subcommand to generate the help screen for.
`subcommand` must be declared in the subcommand tree of this
command.

`includeHidden`

Include hidden help information in the generated
message.

`columns`

The column width to use when wrapping long line in the
help screen. If `columns` is `nil`, uses the current terminal
width, or a default value of `80` if the terminal width is not
available.

### Return Value

The full help screen for this type.

---

## main()

Executes this command, or one of its subcommands, with the program’s
command-line arguments.

```
static func main()
```

### Discussion

Instead of calling this method directly, you can add `@main` to the root
command for your command-line tool.

This method parses an instance of this type, one of its subcommands, or
another built-in `ParsableCommand` type, from command-line arguments,
and then calls its `run()` method, exiting with a relevant error message
if necessary.

---

## main(_:)

Executes this command, or one of its subcommands, with the given
arguments.

```
static func main(_ arguments: [String]?)
```

### Parameters

`arguments`

An array of arguments to use for parsing. If
`arguments` is `nil`, this uses the program’s command-line arguments.

### Discussion

This method parses an instance of this type, one of its subcommands, or
another built-in `ParsableCommand` type, from command-line arguments,
and then calls its `run()` method, exiting with a relevant error message
if necessary.

---

## parseAsRoot(_:)

Parses an instance of this type, or one of its subcommands, from
command-line arguments.

```
static func parseAsRoot(_ arguments: [String]? = nil) throws -> ParsableCommand
```

### Parameters

`arguments`

An array of arguments to use for parsing. If
`arguments` is `nil`, this uses the program’s command-line arguments.

### Return Value

A new instance of this type, one of its subcommands, or a
command type internal to the `ArgumentParser` library.

### Discussion> Throws: If parsing fails.

---

## usageString(for:includeHidden:)

Returns the usage text for the given subcommand of this command.

```
static func usageString(for subcommand: ParsableCommand.Type, includeHidden: Bool = false) -> String
```

### Parameters

`subcommand`

The subcommand to generate the help screen for.
`subcommand` must be declared in the subcommand tree of this
command.

`includeHidden`

Include hidden help information in the generated
message.

### Return Value

The usage text for this type.