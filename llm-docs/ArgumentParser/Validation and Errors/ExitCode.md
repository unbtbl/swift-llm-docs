# ExitCode

An error type that only includes an exit code.

```
struct ExitCode
```

## Overview

If you’re printing custom error messages yourself, you can throw this error
to specify the exit code without adding any additional output to standard
out or standard error.

---

## init(_:)

Creates a new `ExitCode` with the given code.

```
init(_ code: Int32)
```

---

## init(rawValue:)

```
init(rawValue: Int32)
```

---

## isSuccess

A Boolean value indicating whether this exit code represents the
successful completion of a command.

```
var isSuccess: Bool { get }
```

---

## rawValue

The exit code represented by this instance.

```
var rawValue: Int32
```

---

## failure

An exit code that indicates that the command failed.

```
static let failure: ExitCode
```

---

## success

An exit code that indicates successful completion of a command.

```
static let success: ExitCode
```

---

## validationFailure

An exit code that indicates that the user provided invalid input.

```
static let validationFailure: ExitCode
```