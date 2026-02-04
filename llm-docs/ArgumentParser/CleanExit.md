# CleanExit

An error type that represents a clean (non-error state) exit of the
utility.

```
struct CleanExit
```

## Overview

Throwing a `CleanExit` instance from a `validate` or `run` method, or
passing it to `exit(with:)`, exits the program with exit code `0`.

---

## description

```
var description: String { get }
```

---

## helpRequest(_:)

Treat this error as a help request and display the full help message.

```
static func helpRequest(_ command: ParsableCommand.Type? = nil) -> CleanExit
```

### Parameters

`command`

The command type to offer help for, if different
from the root command.

### Return Value

A throwable CleanExit error.

### Discussion

You can use this case to simulate the user specifying one of the help
flags or subcommands.

---

## helpRequest(_:)

Treat this error as a help request and display the full help message.

```
static func helpRequest(_ command: ParsableCommand) -> CleanExit
```

### Parameters

`command`

A command to offer help for, if different from
the root command.

### Return Value

A throwable CleanExit error.

### Discussion

You can use this case to simulate the user specifying one of the help
flags or subcommands.

---

## message(_:)

Treat this error as a clean exit with the given message.

```
static func message(_ text: String) -> CleanExit
```