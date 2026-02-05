# ExpressibleByArgument

A type that can be expressed as a command-line argument.

```
protocol ExpressibleByArgument : _SendableMetatype
```

---

## init(argument:)

Creates a new instance of this type from a command-line-specified
argument.

```
init?(argument: String)
```

---

## defaultValueDescription

The description of this instance to show as a default value in a
command-line tool’s help screen.

```
var defaultValueDescription: String { get }
```

---

## allValueDescriptions

A dictionary containing the descriptions for each possible value of this type,
for display in the help screen.

```
static var allValueDescriptions: [String : String] { get }
```

### Discussion

The default implementation of this property returns an empty dictionary. If
the conforming type is also `CaseIterable`, the default implementation
returns a dictionary with a description for each value as its key-value pair.
Note that the conforming type must implement the
`defaultValueDescription` for each value - if the description and the
value are the same string, it’s assumed that a description is not implemented.

---

## allValueStrings

An array of all possible strings that can convert to a value of this
type, for display in the help screen.

```
static var allValueStrings: [String] { get }
```

### Discussion

The default implementation of this property returns an empty array. If the
conforming type is also `CaseIterable`, the default implementation returns
an array with a value for each case.

---

## defaultCompletionKind

The completion kind to use for options or arguments of this type that
don’t explicitly declare a completion kind.

```
static var defaultCompletionKind: CompletionKind { get }
```

### Discussion

The default implementation of this property returns `.default`.