# ArgumentArrayParsingStrategy

The strategy to use when parsing multiple values from positional arguments
into an array.

```
struct ArgumentArrayParsingStrategy
```

---

## allUnrecognized

After parsing, capture all unrecognized inputs in this argument array.

```
static var allUnrecognized: ArgumentArrayParsingStrategy { get }
```

### Discussion

You can use the `allUnrecognized` parsing strategy to suppress
“unexpected argument” errors or to capture unrecognized inputs for further
processing.

For example, the `Example` command defined below has an `other` array that
uses the `allUnrecognized` parsing strategy:

```
@main
struct Example: ParsableCommand {
    @Flag var verbose = false
    @Argument var name: String

    @Argument(parsing: .allUnrecognized)
    var other: [String]

    func run() {
        print(other.joined(separator: "\n"))
    }
}
```

After parsing the `--verbose` flag and `<name>` argument, any remaining
input is captured in the `other` array.

```
$ example --verbose Negin one two
one
two
$ example Asa --verbose --other -zzz
--other
-zzz
```

---

## captureForPassthrough

Parse all remaining inputs after parsing any known options or flags,
including dash-prefixed inputs and the `--` terminator.

```
static var captureForPassthrough: ArgumentArrayParsingStrategy { get }
```

### Discussion

You can use the `captureForPassthrough` parsing strategy if you need to
capture a user’s input to manually pass it unchanged to another command.

When you use this parsing strategy, the parser stops parsing flags and
options as soon as it encounters a positional argument or an unrecognized
flag, and captures all remaining inputs in the array argument.

For example, the `Example` command defined below has an `words` array that
uses the `captureForPassthrough` parsing strategy:

```
@main
struct Example: ParsableCommand {
    @Flag var verbose = false

    @Argument(parsing: .captureForPassthrough)
    var words: [String] = []

    func run() {
        print(words.joined(separator: "\n"))
    }
}
```

Any values after the first unrecognized input are captured in the `words`
array.

```
$ example --verbose one two --other
one
two
--other
$ example one two --verbose
one
two
--verbose
```

With the `captureForPassthrough` parsing strategy, the `--` terminator
is included in the captured values.

```
$ example --verbose one two -- --other
one
two
--
--other
```

> Note: This parsing strategy can be surprising for users, particularly
> when combined with options and flags. Prefer ``doc://com.dependencies/documentation/ArgumentParser/ArgumentArrayParsingStrategy/remaining`` or
> ``doc://com.dependencies/documentation/ArgumentParser/ArgumentArrayParsingStrategy/allUnrecognized`` whenever possible, since users can always terminate
> options and flags with the `--` terminator. With the `remaining`
> parsing strategy, the input `--verbose -- one two --other` would have
> the same result as the first example above.

---

## postTerminator

Before parsing arguments, capture all inputs that follow the `--`
terminator in this argument array.

```
static var postTerminator: ArgumentArrayParsingStrategy { get }
```

### Discussion

For example, the `Example` command defined below has a `words` array that
uses the `postTerminator` parsing strategy:

```
@main
struct Example: ParsableCommand {
    @Flag var verbose = false
    @Argument var name = ""

    @Argument(parsing: .postTerminator)
    var words: [String]

    func run() {
        print(words.joined(separator: "\n"))
    }
}
```

Before looking for the `--verbose` flag and `<name>` argument, any inputs
after the `--` terminator are captured into the `words` array.

```
$ example --verbose Asa -- one two --other
one
two
--other
$ example Asa Extra -- one two --other
Error: Unexpected argument 'Extra'
```

Because options are parsed before arguments, an option that consumes or
suppresses the `--` terminator can prevent a `postTerminator` argument
array from capturing any input. In particular, the
[`unconditional`](/documentation/ArgumentParser/SingleValueParsingStrategy/unconditional),
[`unconditionalSingleValue`](/documentation/ArgumentParser/ArrayParsingStrategy/unconditionalSingleValue), and
[`remaining`](/documentation/ArgumentParser/ArrayParsingStrategy/remaining) parsing strategies can all consume
the terminator as part of their values.

> Note: This parsing strategy can be surprising for users, since it
> changes the behavior of the `--` terminator. Prefer ``doc://com.dependencies/documentation/ArgumentParser/ArgumentArrayParsingStrategy/remaining``
> whenever possible.

---

## remaining

Parse only unprefixed values from the command-line input, ignoring
any inputs that have a dash prefix; this is the default strategy.

```
static var remaining: ArgumentArrayParsingStrategy { get }
```

### Discussion

`remaining` is the default parsing strategy for argument arrays.

For example, the `Example` command defined below has a `words` array that
uses the `remaining` parsing strategy:

```
@main
struct Example: ParsableCommand {
    @Flag var verbose = false

    @Argument(parsing: .remaining)
    var words: [String]

    func run() {
        print(words.joined(separator: "\n"))
    }
}
```

Any non-dash-prefixed inputs will be captured in the `words` array.

```
$ example --verbose one two
one
two
$ example one two --verbose
one
two
$ example one two --other
Error: Unknown option '--other'
```

If a user uses the `--` terminator in their input, all following inputs
will be captured in `words`.

```
$ example one two -- --verbose --other
one
two
--verbose
--other
```

---

## unconditionalRemaining

```
static var unconditionalRemaining: ArgumentArrayParsingStrategy { get }
```