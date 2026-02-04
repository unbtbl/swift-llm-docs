# ArgumentHelp

Help information for a command-line argument.

```
struct ArgumentHelp
```

---

## init(_:discussion:valueName:shouldDisplay:)

Creates a new help instance.

```
init(_ abstract: String = "", discussion: String? = nil, valueName: String? = nil, shouldDisplay: Bool)
```

---

## init(_:discussion:valueName:visibility:argumentType:)

Creates a new help instance.

```
init(_ abstract: String = "", discussion: String? = nil, valueName: String? = nil, visibility: ArgumentVisibility = .default, argumentType: (any ExpressibleByArgument.Type)? = nil)
```

---

## abstract

A short description of the argument.

```
var abstract: String
```

---

## argumentType

A property of meta type `any ExpressibleByArgument.Type` that serves to retain
information about any arguments that have enumerable values and their descriptions.

```
var argumentType: (any ExpressibleByArgument.Type)?
```

---

## discussion

An expanded description of the argument, in plain text form.

```
var discussion: String?
```

---

## shouldDisplay

A Boolean value indicating whether this argument should be shown in
the extended help display.

```
var shouldDisplay: Bool { get set }
```

---

## valueName

An alternative name to use for the argument’s value when showing usage
information.

```
var valueName: String?
```

### Discussion> Note: This property is ignored when generating help for flags, since
> flags don’t include a value.

---

## visibility

A visibility level indicating whether this argument should be shown in
the extended help display.

```
var visibility: ArgumentVisibility
```

---

## hidden

A `Help` instance that shows an argument only in the extended help display.

```
static var hidden: ArgumentHelp { get }
```

---

## private

A `Help` instance that hides an argument from the extended help display.

```
static var `private`: ArgumentHelp { get }
```