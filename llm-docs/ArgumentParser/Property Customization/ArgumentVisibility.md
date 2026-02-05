# ArgumentVisibility

Visibility level of an argument’s help.

```
struct ArgumentVisibility
```

---

## default

Show help for this argument whenever appropriate.

```
static let `default`: ArgumentVisibility
```

---

## hidden

Only show help for this argument in the extended help screen.

```
static let hidden: ArgumentVisibility
```

---

## private

Never show help for this argument.

```
static let `private`: ArgumentVisibility
```