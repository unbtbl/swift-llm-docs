# Argument

A property wrapper that represents a positional command-line argument.

```
@propertyWrapper struct Argument<Value>
```

## Overview

Use the `@Argument` wrapper to define a property of your custom command as
a positional argument. A *positional argument* for a command-line tool is
specified without a label and must appear in declaration order. `@Argument`
properties with `Optional` type or a default value are optional for the user
of your command-line tool.

For example, the following program has two positional arguments. The `name`
argument is required, while `greeting` is optional because it has a default
value.

```swift
@main
struct Greet: ParsableCommand {
    @Argument var name: String
    @Argument var greeting: String = "Hello"

    mutating func run() {
        print("\(greeting) \(name)!")
    }
}
```

You can call this program with just a name or with a name and a
greeting. When you supply both arguments, the first argument is always
treated as the name, due to the order of the property declarations.

```
$ greet Nadia
Hello Nadia!
$ greet Tamara Hi
Hi Tamara!
```

---

## init(help:completion:)

Creates an optional property that reads its value from an argument.

```
init<T>(help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == T?, T : ExpressibleByArgument
```

### Parameters

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

### Discussion

The argument is optional for the caller of the command and defaults to
`nil`.

---

## init(help:completion:)

Creates a property with no default value.

```
init(help: ArgumentHelp? = nil, completion: CompletionKind? = nil)
```

### Parameters

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

### Discussion

This method is called to initialize an `Argument` without a default value
such as:

```swift
@Argument var foo: String
```

---

## init(help:completion:transform:)

Creates a property with no default value, parsing with the given closure.

```
@preconcurrency init(help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> Value)
```

### Parameters

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s
element type or throws an error.

### Discussion

This method is called to initialize an `Argument` with no default value such as:

```swift
@Argument(transform: baz)
var foo: String
```

---

## init(help:completion:transform:)

Creates an optional property that reads its value from an argument.

```
@preconcurrency init<T>(help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == T?
```

### Parameters

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s
element type or throws an error.

### Discussion

The argument is optional for the caller of the command and defaults to
`nil`.

---

## init(parsing:help:completion:)

Creates a property with no default value that reads an array from zero or
more arguments.

```
init<T>(parsing parsingStrategy: ArgumentArrayParsingStrategy = .remaining, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == [T], T : ExpressibleByArgument
```

### Parameters

`parsingStrategy`

The behavior to use when parsing multiple values from
the command-line arguments.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

### Discussion

This method is called to initialize an array `Argument` with no default
value such as:

```swift
@Argument()
var foo: [String]
```

---

## init(parsing:help:completion:transform:)

Creates a property with no default value that reads an array from zero or
more arguments, parsing each element with the given closure.

```
@preconcurrency init<T>(parsing parsingStrategy: ArgumentArrayParsingStrategy = .remaining, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == [T]
```

### Parameters

`parsingStrategy`

The behavior to use when parsing multiple values from
the command-line arguments.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s
element type or throws an error.

### Discussion

This method is called to initialize an array `Argument` with no default
value such as:

```swift
@Argument(transform: baz)
var foo: [String]
```

---

## init(wrappedValue:help:completion:)

This initializer allows a user to provide a `nil` default value for an
optional `@Argument`-marked property without allowing a non-`nil` default
value.

```
init<T>(wrappedValue: _OptionalNilComparisonType, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == T?, T : ExpressibleByArgument
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

---

## init(wrappedValue:help:completion:)

Creates a property with a default value provided by standard Swift default
value syntax.

```
init(wrappedValue: Value, help: ArgumentHelp? = nil, completion: CompletionKind? = nil)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

### Discussion

This method is called to initialize an `Argument` with a default value
such as:

```swift
@Argument var foo: String = "bar"
```

---

## init(wrappedValue:help:completion:transform:)

Creates a property with a default value provided by standard Swift default
value syntax, parsing with the given closure.

```
@preconcurrency init(wrappedValue: Value, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> Value)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s type
or throws an error.

### Discussion

This method is called to initialize an `Argument` with a default value
such as:

```swift
@Argument(transform: baz)
var foo: String = "bar"
```

---

## init(wrappedValue:help:completion:transform:)

This initializer allows a user to provide a `nil` default value for an
optional `@Argument`-marked property without allowing a non-`nil` default
value.

```
@preconcurrency init<T>(wrappedValue: _OptionalNilComparisonType, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == T?
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s
element type or throws an error.

---

## init(wrappedValue:parsing:help:completion:)

Creates a property that reads an array from zero or more arguments.

```
init<T>(wrappedValue: [T], parsing parsingStrategy: ArgumentArrayParsingStrategy = .remaining, help: ArgumentHelp? = nil, completion: CompletionKind? = nil) where Value == [T], T : ExpressibleByArgument
```

### Parameters

`wrappedValue`

A default value to use for this property.

`parsingStrategy`

The behavior to use when parsing multiple values from
the command-line arguments.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

---

## init(wrappedValue:parsing:help:completion:transform:)

Creates a property that reads an array from zero or more arguments,
parsing each element with the given closure.

```
@preconcurrency init<T>(wrappedValue: [T], parsing parsingStrategy: ArgumentArrayParsingStrategy = .remaining, help: ArgumentHelp? = nil, completion: CompletionKind? = nil, transform: @escaping (String) throws -> T) where Value == [T]
```

### Parameters

`wrappedValue`

A default value to use for this property.

`parsingStrategy`

The behavior to use when parsing multiple values from
the command-line arguments.

`help`

Information about how to use this argument.

`completion`

Kind of completion provided to the user for this option.

`transform`

A closure that converts a string into this property’s
element type or throws an error.

---

## wrappedValue

The value presented by this property wrapper.

```
var wrappedValue: Value { get set }
```