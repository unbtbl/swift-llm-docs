# ParsableArguments

A type that can be parsed from a program’s command-line arguments.

```
protocol ParsableArguments : _SendableMetatype, Decodable
```

## Overview

When you implement a `ParsableArguments` type, all properties must be declared with
one of the four property wrappers provided by the `ArgumentParser` library.

---

## init()

Creates an instance of this parsable type using the definitions
given by each property’s wrapper.

```
init()
```

---

## validate()

Validates the properties of the instance after parsing.

```
mutating func validate() throws
```

### Discussion

Implement this method to perform validation or other processing after
creating a new instance from command-line arguments.

---

## completionScript(for:)

Returns a shell completion script for the specified shell.

```
static func completionScript(for shell: CompletionShell) -> String
```

### Parameters

`shell`

The shell to generate a completion script for.

### Return Value

The completion script for `shell`.

---

## exit(withError:)

Terminates execution with a message and exit code that is appropriate
for the given error.

```
static func exit(withError error: Error? = nil) -> Never
```

### Parameters

`error`

The error to use when exiting, if any.

### Discussion

If the `error` parameter is `nil`, this method prints nothing and exits
with code `EXIT_SUCCESS`. If `error` represents a help request or
another [CleanExit](CleanExit.md) error, this method prints help information and
exits with code `EXIT_SUCCESS`. Otherwise, this method prints a relevant
error message and exits with code `EX_USAGE` or `EXIT_FAILURE`.

---

## exitCode(for:)

Returns the exit code for the given error.

```
static func exitCode(for error: Error) -> ExitCode
```

### Parameters

`error`

An error to generate an exit code for.

### Return Value

The exit code for `error`.

### Discussion

The returned code is the same exit code that is used if `error` is passed
to `exit(withError:)`.

---

## fullMessage(for:columns:)

Returns a full message for the given error, including usage information,
if appropriate.

```
static func fullMessage(for error: Error, columns: Int? = nil) -> String
```

### Parameters

`error`

An error to generate a message for.

`columns`

The column width to use when wrapping long line in the
help screen. If `columns` is `nil`, uses the current terminal
width, or a default value of `80` if the terminal width is not
available.

### Return Value

A message that can be displayed to the user.

---

## helpMessage(columns:)

Returns the text of the help screen for this type.

```
static func helpMessage(columns: Int?) -> String
```

### Parameters

`columns`

The column width to use when wrapping long line in
the help screen. If `columns` is `nil`, uses the current terminal width,
or a default value of `80` if the terminal width is not available.

### Return Value

The full help screen for this type.

---

## helpMessage(includeHidden:columns:)

Returns the text of the help screen for this type.

```
static func helpMessage(includeHidden: Bool = false, columns: Int? = nil) -> String
```

### Parameters

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

## message(for:)

Returns a brief message for the given error.

```
static func message(for error: Error) -> String
```

### Parameters

`error`

An error to generate a message for.

### Return Value

A message that can be displayed to the user.

---

## parse(_:)

Parses a new instance of this type from command-line arguments.

```
static func parse(_ arguments: [String]? = nil) throws -> Self
```

### Parameters

`arguments`

An array of arguments to use for parsing. If
`arguments` is `nil`, this uses the program’s command-line arguments.

### Return Value

A new instance of this type.

### Discussion> Throws: If parsing failed or arguments contains a help request.

---

## parseOrExit(_:)

Parses a new instance of this type from command-line arguments or exits
with a relevant message.

```
static func parseOrExit(_ arguments: [String]? = nil) -> Self
```

### Parameters

`arguments`

An array of arguments to use for parsing. If
`arguments` is `nil`, this uses the program’s command-line arguments.

### Return Value

An instance of `Self` parsable properties populated with the
provided argument values.

---

## usageString(includeHidden:)

Returns the usage text for this type.

```
static func usageString(includeHidden: Bool = false) -> String
```

### Return Value

The usage text for this type.