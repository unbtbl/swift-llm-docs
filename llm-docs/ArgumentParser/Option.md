# Option

A property wrapper that represents a command-line option.

```
@propertyWrapper struct Option<Value>
```

## Overview

Use the `@Option` wrapper to define a property of your custom command as a
command-line option. An *option* is a named value passed to a command-line
tool, like `--configuration debug`. Options can be specified in any order.

An option can have a default value specified as part of its
declaration; options with optional `Value` types implicitly have `nil` as
their default value. Options that are neither declared as `Optional` nor
given a default value are required for users of your command-line tool.

For example, the following program defines three options:

```swift
@main
struct Greet: ParsableCommand {
    @Option var greeting = "Hello"
    @Option var age: Int? = nil
    @Option var name: String

    mutating func run() {
        print("\(greeting) \(name)!")
        if let age {
            print("Congrats on making it to the ripe old age of \(age)!")
        }
    }
}
```

`greeting` has a default value of `"Hello"`, which can be overridden by
providing a different string as an argument, while `age` defaults to `nil`.
`name` is a required option because it is non-`nil` and has no default
value.

```
$ greet --name Alicia
Hello Alicia!
$ greet --age 28 --name Seungchin --greeting Hi
Hi Seungchin!
Congrats on making it to the ripe old age of 28!
```

---

## init(name:parsing:help:completion:)

Creates a required array property that reads its values from zero or
more labeled options.

```
init<T>(name: NameSpecification = .long, parsing parsingStrategy: ArrayParsingStrategy = .singleValue, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == [T], T : ExpressibleByArgument
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when parsing the elements for
this option.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer is used when you declare an `@Option`-attributed array
property without a default value:

```swift
@Option(name: .customLong("char"))
var chars: [Character]
```

If the element type conforms to [ExpressibleByArgument](ExpressibleByArgument.md) and has enumerable
value descriptions (via `defaultValueDescription`), the help output will
display each possible value with its description, similar to single
enumerable options.

---

## init(name:parsing:help:completion:)

Creates a required property that reads its value from a labeled option.

```
init(name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil)
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
that has an [ExpressibleByArgument](ExpressibleByArgument.md) type, but without a default value:

```swift
@Option var title: String
```

---

## init(name:parsing:help:completion:)

Creates an optional property that reads its value from a labeled option.

```
init<T>(name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == T?, T : ExpressibleByArgument
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
with an optional type and no default value:

```swift
@Option var count: Int?
```

---

## init(name:parsing:help:completion:transform:)

Creates an optional property that reads its value from a labeled option,
parsing with the given closure.

```
@preconcurrency init<T>(name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == T?
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
with a transform closure and without a default value:

```swift
@Option(transform: { $0.first ?? " " })
var char: Character?
```

---

## init(name:parsing:help:completion:transform:)

Creates a required property that reads its value from a labeled option,
parsing with the given closure.

```
@preconcurrency init(name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> Value)
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
with a transform closure and without a default value:

```swift
@Option(transform: { $0.first ?? " " })
var char: Character
```

---

## init(name:parsing:help:completion:transform:)

Creates a required array property that reads its values from zero or
more labeled options, parsing each element with the given closure.

```
@preconcurrency init<T>(name: NameSpecification = .long, parsing parsingStrategy: ArrayParsingStrategy = .singleValue, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == [T]
```

### Parameters

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when parsing the elements for
this option.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
element type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed array
property with a transform closure and without a default value:

```swift
@Option(name: .customLong("char"), transform: { $0.first ?? " " })
var chars: [Character]
```

---

## init(wrappedValue:name:parsing:help:completion:)

Creates an array property that reads its values from zero or
more labeled options.

```
init<T>(wrappedValue: [T], name: NameSpecification = .long, parsing parsingStrategy: ArrayParsingStrategy = .singleValue, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == [T], T : ExpressibleByArgument
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.
If this initial value is non-empty, elements passed from the command
line are appended to the original contents.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when parsing the elements for
this option.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer is used when you declare an `@Option`-attributed array
property with a default value:

```swift
@Option(name: .customLong("char"))
var chars: [Character] = []
```

If the element type conforms to [ExpressibleByArgument](ExpressibleByArgument.md) and has enumerable
value descriptions (via `defaultValueDescription`), the help output will
display each possible value with its description, similar to single
enumerable options.

---

## init(wrappedValue:name:parsing:help:completion:)

Creates an optional property that reads its value from a labeled option,
with an explicit `nil` default.

```
init<T>(wrappedValue: _OptionalNilComparisonType, name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == T?, T : ExpressibleByArgument
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer allows a user to provide a `nil` default value for an
optional `@Option`-marked property:

```swift
@Option var count: Int? = nil
```

---

## init(wrappedValue:name:parsing:help:completion:)

Creates a property with a default value that reads its value from a
labeled option.

```
init(wrappedValue: Value, name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
that has an [ExpressibleByArgument](ExpressibleByArgument.md) type, providing a default value:

```swift
@Option var title: String = "<Title>"
```

---

## init(wrappedValue:name:parsing:help:completion:transform:)

Creates an array property that reads its values from zero or
more labeled options, parsing each element with the given closure.

```
@preconcurrency init<T>(wrappedValue: [T], name: NameSpecification = .long, parsing parsingStrategy: ArrayParsingStrategy = .singleValue, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == [T]
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.
If this initial value is non-empty, elements passed from the command
line are appended to the original contents.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when parsing the elements for
this option.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
element type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed array
property with a transform closure and a default value:

```swift
@Option(name: .customLong("char"), transform: { $0.first ?? " " })
var chars: [Character] = []
```

---

## init(wrappedValue:name:parsing:help:completion:transform:)

Creates a property with a default value that reads its value from a
labeled option, parsing with the given closure.

```
@preconcurrency init(wrappedValue: Value, name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> Value)
```

### Parameters

`wrappedValue`

The default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
with a transform closure and a default value:

```swift
@Option(transform: { $0.first ?? " " })
var char: Character = "_"
```

---

## init(wrappedValue:name:parsing:help:completion:transform:)

Creates an optional property that reads its value from a labeled option,
parsing with the given closure, with an explicit `nil` default.

```
@preconcurrency init<T>(wrappedValue: _OptionalNilComparisonType, name: NameSpecification = .long, parsing parsingStrategy: SingleValueParsingStrategy = .next, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == T?
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this option.

`parsingStrategy`

The behavior to use when looking for this option’s
value.

`help`

Information about how to use this option.

`completion`

The type of command-line completion provided for this
option.

`transform`

A closure that converts a string into this property’s
type, or else throws an error.

### Discussion

This initializer is used when you declare an `@Option`-attributed property
with a transform closure and with a default value of `nil`:

```swift
@Option(transform: { $0.first ?? " " })
var char: Character? = nil
```

---

## wrappedValue

The value presented by this property wrapper.

```
var wrappedValue: Value { get set }
```