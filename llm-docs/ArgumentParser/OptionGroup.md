# OptionGroup

A wrapper that transparently includes a parsable type.

```
@propertyWrapper struct OptionGroup<Value> where Value : ParsableArguments
```

## Overview

Use an option group to include a group of options, flags, or arguments
declared in a parsable type.

```swift
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    @Argument var values: [Int]
}

struct Options: ParsableArguments {
    @Option var name: String
    @OptionGroup var globals: GlobalOptions
}
```

The flag and positional arguments declared as part of `GlobalOptions` are
included when parsing `Options`.

---

## init()

Creates a property that represents another parsable type.

```
init()
```

---

## init(title:visibility:)

Creates a property that represents another parsable type, using the
specified title and visibility.

```
init(title: String = "", visibility: ArgumentVisibility = .default)
```

### Parameters

`title`

A title for grouping this option group’s members in your
command’s help screen. If `title` is empty, the members will be
displayed alongside the other arguments, flags, and options declared
by your command.

`visibility`

The visibility to use for the entire option group.

---

## title

The title to use in the help screen for this option group.

```
var title: String
```

---

## wrappedValue

The value presented by this property wrapper.

```
var wrappedValue: Value { get set }
```