# ArrayParsingStrategy

The strategy to use when parsing multiple values from `@Option` arguments into an
array.

```
struct ArrayParsingStrategy
```

---

## remaining

Parse all remaining arguments into an array.

```
static var remaining: ArrayParsingStrategy { get }
```

### Discussion

`.remaining` can be used for capturing pass-through flags. For example, for
a parsable type defined as
`@Option(parsing: .remaining) var passthrough: [String]`:

```
$ cmd --passthrough --foo 1 --bar 2 -xvf
------------
options.passthrough == ["--foo", "1", "--bar", "2", "-xvf"]
```

> Note: This will read all inputs following the option without attempting to do any parsing. This is
> usually *not* what users would expect. Use with caution.

Consider using a trailing `@Argument` instead and letting users explicitly turn off parsing
through the terminator `--`. That is the more common approach. For example:

```swift
struct Options: ParsableArguments {
    @Option var title: String
    @Argument var remainder: [String]
}
```

would parse the input `--title Foo -- Bar --baz` such that the `remainder`
would hold the value `["Bar", "--baz"]`.

---

## singleValue

Parse one value per option, joining multiple into an array.

```
static var singleValue: ArrayParsingStrategy { get }
```

### Discussion

For example, for a parsable type with a property defined as
`@Option(parsing: .singleValue) var read: [String]`,
the input `--read foo --read bar` would result in the array
`["foo", "bar"]`. The same would be true for the input
`--read=foo --read=bar`.

> Note: This follows the default behavior of differentiating between values and options. As
> such, the value for this option will be the next value (non-option) in the input. For the
> above example, the input `--read --name Foo Bar` would parse `Foo` into
> `read` (and `Bar` into `name`).

---

## unconditionalSingleValue

Parse the value immediately after the option while allowing repeating options, joining multiple into an array.

```
static var unconditionalSingleValue: ArrayParsingStrategy { get }
```

### Discussion

This is identical to `.singleValue` except that the value will be read
from the input immediately after the option, even if it could be interpreted as an option.

For example, for a parsable type with a property defined as
`@Option(parsing: .unconditionalSingleValue) var read: [String]`,
the input `--read foo --read bar` would result in the array
`["foo", "bar"]` – just as it would have been the case for `.singleValue`.

> Note: However, the input `--read --name Foo Bar --read baz` would result in
> `read` being set to the array `["--name", "baz"]`. This is usually *not* what users
> would expect. Use with caution.

---

## upToNextOption

Parse all values up to the next option.

```
static var upToNextOption: ArrayParsingStrategy { get }
```

### Discussion

For example, for a parsable type with a property defined as
`@Option(parsing: .upToNextOption) var files: [String]`,
the input `--files foo bar` would result in the array
`["foo", "bar"]`.

Parsing stops as soon as there’s another option in the input such that
`--files foo bar --verbose` would also set `files` to the array
`["foo", "bar"]`.