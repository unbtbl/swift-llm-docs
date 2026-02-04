# Flag

A property wrapper that represents a command-line flag.

```
@propertyWrapper struct Flag<Value>
```

## Overview

Use the `@Flag` wrapper to define a property of your custom type as a
command-line flag. A *flag* is a dash-prefixed label that can be provided on
the command line, such as `-d` and `--debug`.

For example, the following program declares a flag that lets a user indicate
that seconds should be included when printing the time.

```swift
@main
struct Time: ParsableCommand {
    @Flag var includeSeconds = false

    mutating func run() {
        if includeSeconds {
            print(Date.now.formatted(.dateTime.hour().minute().second()))
        } else {
            print(Date.now.formatted(.dateTime.hour().minute()))
        }
    }
}
```

`includeSeconds` has a default value of `false`, but becomes `true` if
`--include-seconds` is provided on the command line.

```
$ time
11:09 AM
$ time --include-seconds
11:09:15 AM
```

A flag can have a value that is a `Bool`, an `Int`, or any [EnumerableFlag](EnumerableFlag.md)
type. When using an [EnumerableFlag](EnumerableFlag.md) type as a flag, the individual cases
form the flags that are used on the command line.

```
@main
struct Math: ParsableCommand {
    enum Operation: EnumerableFlag {
        case add
        case multiply
    }

    @Flag var operation: Operation

    mutating func run() {
        print("Time to \(operation)!")
    }
}
```

Instead of using the name of the `operation` property as the flag in this
case, the two cases of the `Operation` enumeration become valid flags.
The `operation` property is neither optional nor given a default value, so
one of the two flags is required.

```
$ math --add
Time to add!
$ math
Error: Missing one of: '--add', '--multiply'
```

---

## init(exclusivity:help:)

Creates a property that gets its value from the presence of a flag,
where the allowed flags are defined by an [EnumerableFlag](EnumerableFlag.md) type.

```
init<Element>(exclusivity: FlagExclusivity = .exclusive, help: ArgumentHelp? = nil) where Value == Element?, Element : EnumerableFlag
```

---

## init(exclusivity:help:)

Creates a property with no default value that gets its value from the presence of a flag.

```
init(exclusivity: FlagExclusivity = .exclusive, help: ArgumentHelp? = nil)
```

### Parameters

`exclusivity`

The behavior to use when multiple flags are specified.

`help`

Information about how to use this flag.

### Discussion

Use this initializer to customize the name and number of states further than using a `Bool`.
To use, define an [EnumerableFlag](EnumerableFlag.md) enumeration with a case for each state, and use that as the type for your flag.
In this case, the user can specify either `--use-production-server` or `--use-development-server` to set the flag’s value.

```swift
enum ServerChoice: EnumerableFlag {
  case useProductionServer
  case useDevelopmentServer
}

@Flag var serverChoice: ServerChoice
```

---

## init(help:)

Creates an array property with no default value that gets its values from the presence of zero or more flags, where the allowed flags are defined by an [EnumerableFlag](EnumerableFlag.md) type.

```
init<Element>(help: ArgumentHelp? = nil) where Value == [Element], Element : EnumerableFlag
```

### Parameters

`help`

Information about how to use this flag.

### Discussion

This method is called to initialize an array `Flag` with no default value such as:

```swift
@Flag
var foo: [CustomFlagType]
```

---

## init(name:help:)

Creates an integer property that gets its value from the number of times
a flag appears.

```
init(name: NameSpecification = .long, help: ArgumentHelp? = nil)
```

### Parameters

`name`

A specification for what names are allowed for this flag.

`help`

Information about how to use this flag.

### Discussion

This property defaults to a value of zero.

---

## init(name:inversion:exclusivity:help:)

Creates a Boolean property with no default value that reads its value from the presence of one or more inverted flags.

```
init(name: NameSpecification = .long, inversion: FlagInversion, exclusivity: FlagExclusivity = .chooseLast, help: ArgumentHelp? = nil)
```

### Parameters

`name`

A specification for what names are allowed for this flag.

`inversion`

The method for converting this flag’s name into an on/off pair.

`exclusivity`

The behavior to use when an on/off pair of flags is specified.

`help`

Information about how to use this flag.

### Discussion

Use this initializer to create a Boolean flag with an on/off pair.
With the following declaration, for example, the user can specify either `--use-https` or `--no-use-https` to set the `useHTTPS` flag to `true` or `false`, respectively.

```swift
@Flag(inversion: .prefixedNo)
var useHTTPS: Bool
```

---

## init(name:inversion:exclusivity:help:)

Creates a Boolean property that reads its value from the presence of
one or more inverted flags.

```
init(name: NameSpecification = .long, inversion: FlagInversion, exclusivity: FlagExclusivity = .chooseLast, help: ArgumentHelp? = nil)
```

### Parameters

`name`

A specification for what names are allowed for this flag.

`inversion`

The method for converting this flags name into an on/off
pair.

`exclusivity`

The behavior to use when an on/off pair of flags is
specified.

`help`

Information about how to use this flag.

### Discussion

Use this initializer to create an optional Boolean flag with an on/off
pair. With the following declaration, for example, the user can specify
either `--use-https` or `--no-use-https` to set the `useHTTPS` flag to
`true` or `false`, respectively. If neither is specified, the resulting
flag value would be `nil`.

```
@Flag(inversion: .prefixedNo)
var useHTTPS: Bool?
```

---

## init(wrappedValue:exclusivity:help:)

Creates a property with a default value provided by standard Swift default value syntax that gets its value from the presence of a flag.

```
init(wrappedValue: Value, exclusivity: FlagExclusivity = .exclusive, help: ArgumentHelp? = nil)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided implicitly by the compiler during property wrapper initialization.

`exclusivity`

The behavior to use when multiple flags are specified.

`help`

Information about how to use this flag.

### Discussion

Use this initializer to customize the name and number of states further than using a `Bool`.
To use, define an [EnumerableFlag](EnumerableFlag.md) enumeration with a case for each state, and use that as the type for your flag.
In this case, the user can specify either `--use-production-server` or `--use-development-server` to set the flag’s value.

```swift
enum ServerChoice: EnumerableFlag {
  case useProductionServer
  case useDevelopmentServer
}

@Flag var serverChoice: ServerChoice = .useProductionServer
```

---

## init(wrappedValue:help:)

Creates an array property that gets its values from the presence of
zero or more flags, where the allowed flags are defined by an
[EnumerableFlag](EnumerableFlag.md) type.

```
init<Element>(wrappedValue: [Element], help: ArgumentHelp? = nil) where Value == [Element], Element : EnumerableFlag
```

### Parameters

`wrappedValue`

A default value to use for this property, provided

`help`

Information about how to use this flag.

### Discussion

This property has an empty array as its default value.

---

## init(wrappedValue:name:help:)

Creates a Boolean property with default value provided by standard Swift default value syntax that reads its value from the presence of a flag.

```
init(wrappedValue: Bool, name: NameSpecification = .long, help: ArgumentHelp? = nil)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this flag.

`help`

Information about how to use this flag.

---

## init(wrappedValue:name:inversion:exclusivity:help:)

Creates a Boolean property with default value provided by standard Swift default value syntax that reads its value from the presence of one or more inverted flags.

```
init(wrappedValue: Bool, name: NameSpecification = .long, inversion: FlagInversion, exclusivity: FlagExclusivity = .chooseLast, help: ArgumentHelp? = nil)
```

### Parameters

`wrappedValue`

A default value to use for this property, provided
implicitly by the compiler during property wrapper initialization.

`name`

A specification for what names are allowed for this flag.

`inversion`

The method for converting this flag’s name into an on/off pair.

`exclusivity`

The behavior to use when an on/off pair of flags is specified.

`help`

Information about how to use this flag.

### Discussion

Use this initializer to create a Boolean flag with an on/off pair.
With the following declaration, for example, the user can specify either `--use-https` or `--no-use-https` to set the `useHTTPS` flag to `true` or `false`, respectively.

```swift
@Flag(inversion: .prefixedNo)
var useHTTPS: Bool = true
```

---

## wrappedValue

The value presented by this property wrapper.

```
var wrappedValue: Value { get set }
```