# CommandGroup

A set of commands grouped together under a common name.

```
struct CommandGroup
```

---

## init(name:subcommands:)

Create a command group.

```
init(name: String, subcommands: [ParsableCommand.Type])
```

---

## name

The name of the command group that will be displayed in help.

```
let name: String
```

---

## subcommands

The list of subcommands that are part of this group.

```
let subcommands: [ParsableCommand.Type]
```