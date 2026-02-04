# ToolInfoV0

Top-level structure containing serialization version and information for all
commands in a tool.

```
struct ToolInfoV0
```

---

## init(command:)

```
init(command: CommandInfoV0)
```

---

## init(from:)

```
init(from decoder: any Decoder) throws
```

---

## command

Root command of the tool.

```
var command: CommandInfoV0
```

---

## serializationVersion

A sentinel value indicating the version of the ToolInfo struct used to
generate the serialized form.

```
var serializationVersion: Int
```