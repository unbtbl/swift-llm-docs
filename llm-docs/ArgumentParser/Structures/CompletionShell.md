# CompletionShell

A shell for which the parser can generate a completion script.

```
struct CompletionShell
```

---

## init(rawValue:)

Creates a new instance from the given string.

```
init?(rawValue: String)
```

---

## rawValue

```
var rawValue: String
```

---

## allCases

An array of all supported shells for completion scripts.

```
static var allCases: [CompletionShell] { get }
```

---

## bash

An instance representing `bash`.

```
static var bash: CompletionShell { get }
```

---

## fish

An instance representing `fish`.

```
static var fish: CompletionShell { get }
```

---

## requesting

The shell for which completions will be or are being requested.

```
static var requesting: CompletionShell? { get }
```

### Discussion

`CompletionShell.requesting` is non-`nil` only while generating a shell
completion script or while a Swift custom completion function is executing
to offer completions for a word from a command line (that is, while
`customCompletion` from `@Option(completion: .custom(customCompletion))`
executes).

---

## requestingVersion

The shell version for which completions will be or are being requested.

```
static var requestingVersion: String? { get }
```

### Discussion

`CompletionShell.requestingVersion` is non-`nil` only while generating a
shell completion script or while a Swift custom completion function is
running (that is, while `customCompletion` from
`@Option(completion: .custom(customCompletion))` executes).

---

## zsh

An instance representing `zsh`.

```
static var zsh: CompletionShell { get }
```

---

## autodetected()

Returns an instance representing the current shell, if recognized.

```
static func autodetected() -> CompletionShell?
```