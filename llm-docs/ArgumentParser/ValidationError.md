# ValidationError

An error type that is presented to the user as an error with parsing their
command-line input.

```
struct ValidationError
```

---

## init(_:)

Creates a new validation error with the given message.

```
init(_ message: String)
```

---

## description

```
var description: String { get }
```

---

## message

The error message represented by this instance, this string is presented to
the user when a `ValidationError` is thrown from either; `run()`,
`validate()` or a transform closure.

```
var message: String { get }
```