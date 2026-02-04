# CommandInfoV0

All information about a particular command, including arguments and
subcommands.

```
struct CommandInfoV0
```

---

## init(from:)

```
init(from decoder: any Decoder) throws
```

---

## init(superCommands:shouldDisplay:commandName:abstract:discussion:defaultSubcommand:subcommands:arguments:)

```
init(superCommands: [String], shouldDisplay: Bool, commandName: String, abstract: String, discussion: String, defaultSubcommand: String?, subcommands: [CommandInfoV0], arguments: [ArgumentInfoV0])
```

---

## abstract

Short description of the command’s functionality.

```
var abstract: String?
```

---

## arguments

List of supported arguments.

```
var arguments: [ArgumentInfoV0]?
```

---

## commandName

Name used to invoke the command.

```
var commandName: String
```

---

## defaultSubcommand

Optional name of the subcommand invoked when the command is invoked with
no arguments.

```
var defaultSubcommand: String?
```

---

## discussion

Extended description of the command’s functionality.

```
var discussion: String?
```

---

## shouldDisplay

Command should appear in help displays.

```
var shouldDisplay: Bool
```

---

## subcommands

List of nested commands.

```
var subcommands: [CommandInfoV0]?
```

---

## superCommands

Super commands and tools.

```
var superCommands: [String]?
```