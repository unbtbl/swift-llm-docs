# ToolInfoHeader

Header used to validate serialization version of an encoded ToolInfo struct.

```
struct ToolInfoHeader
```

---

## init(from:)

```
init(from decoder: any Decoder) throws
```

---

## init(serializationVersion:)

```
init(serializationVersion: Int)
```

---

## serializationVersion

A sentinel value indicating the version of the ToolInfo struct used to
generate the serialized form.

```
var serializationVersion: Int
```