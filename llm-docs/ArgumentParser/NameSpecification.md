# NameSpecification

A specification for how to represent a property as a command-line argument
label.

```
struct NameSpecification
```

---

## NameSpecification.Element

An individual property name translation.

```
struct Element
```

---

## init(_:)

```
init<S>(_ sequence: S) where S : Sequence, S.Element == NameSpecification.Element
```

---

## init(arrayLiteral:)

```
init(arrayLiteral elements: Element...)
```

---

## long

Use the property’s name converted to lowercase with words separated by
hyphens.

```
static var long: NameSpecification { get }
```

### Discussion

For example, a property named `allowLongNames` would be converted to the
label `--allow-long-names`.

---

## short

Use the first character of the property’s name as a short option label.

```
static var short: NameSpecification { get }
```

### Discussion

For example, a property named `verbose` would be converted to the
label `-v`. Short labels can be combined into groups.

---

## shortAndLong

Combine the `.short` and `.long` specifications to allow both long
and short labels.

```
static var shortAndLong: NameSpecification { get }
```

### Discussion

For example, a property named `verbose` would be converted to both the
long `--verbose` and short `-v` labels.

---

## customLong(_:withSingleDash:)

Use the given string instead of the property’s name.

```
static func customLong(_ name: String, withSingleDash: Bool = false) -> NameSpecification
```

### Parameters

`name`

The name of the option or flag.

`withSingleDash`

A Boolean value indicating whether to use a single
dash as the prefix. If `false`, the name has a double-dash prefix.

### Return Value

A `long` name specification with the requested `name`.

### Discussion

To create a single-dash argument, pass `true` as `withSingleDash`. Note
that combining single-dash options and options with short,
single-character names can lead to ambiguities for the user.

---

## customShort(_:allowingJoined:)

Use the given character as a short option label.

```
static func customShort(_ char: Character, allowingJoined: Bool = false) -> NameSpecification
```

### Parameters

`char`

The name of the option or flag.

`allowingJoined`

A Boolean value indicating whether this short name
allows a joined value.

### Return Value

A `short` name specification with the requested `char`.

### Discussion

When passing `true` as `allowingJoined` in an `@Option` declaration,
the user can join a value with the option name. For example, if an
option is declared as `-D`, allowing joined values, a user could pass
`-Ddebug` to specify `debug` as the value for that option.