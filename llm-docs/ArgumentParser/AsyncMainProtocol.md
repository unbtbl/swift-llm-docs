# AsyncMainProtocol

A type that can designate an [AsyncParsableCommand](AsyncParsableCommand.md) as the program’s
entry point.

```
protocol AsyncMainProtocol
```

## Overview

See the [`AsyncParsableCommand`](AsyncParsableCommand.md) documentation for usage information.

---

## Command

```
associatedtype Command : ParsableCommand
```

---

## main()

Executes the designated command type, or one of its subcommands, with
the program’s command-line arguments.

```
static func main() async
```