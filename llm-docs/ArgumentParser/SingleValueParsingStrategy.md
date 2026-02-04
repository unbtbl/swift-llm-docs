# SingleValueParsingStrategy

The strategy to use when parsing a single value from `@Option` arguments.

```
struct SingleValueParsingStrategy
```

## Overview> SeeAlso: ``doc://com.dependencies/documentation/ArgumentParser/ArrayParsingStrategy``

---

## next

Parse the input after the option and expect it to be a value.

```
static var next: SingleValueParsingStrategy { get }
```

### Discussion

For inputs such as `--foo foo`, this would parse `foo` as the
value. However, the input `--foo --bar foo bar` would
result in an error. Even though two values are provided, they don’t
succeed each option. Parsing would result in an error such as the following:

```
Error: Missing value for '--foo <foo>'
Usage: command [--foo <foo>]
```

This is the **default behavior** for `@Option`-wrapped properties.

---

## scanningForValue

Parse the next input, as long as that input can’t be interpreted as
an option or flag.

```
static var scanningForValue: SingleValueParsingStrategy { get }
```

### Discussion> Note: This will skip other options and *read ahead* in the input
> to find the next available value. This may be *unexpected* for users.
> Use with caution.

For example, if `--foo` takes a value, then the input `--foo --bar bar`
would be parsed such that the value `bar` is used for `--foo`.

---

## unconditional

Parse the next input, even if it could be interpreted as an option or
flag.

```
static var unconditional: SingleValueParsingStrategy { get }
```

### Discussion

For inputs such as `--foo --bar baz`, if `.unconditional` is used for `foo`,
this would read `--bar` as the value for `foo` and would use `baz` as
the next positional argument.

This allows reading negative numeric values or capturing flags to be
passed through to another program since the leading hyphen is normally
interpreted as the start of another option.

> Note: This is usually *not* what users would expect. Use with caution.