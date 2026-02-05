# FlagInversion

The options for converting a Boolean flag into a `true`/`false` pair.

```
struct FlagInversion
```

---

## prefixedEnableDisable

Uses matching flags with `enable-` and `disable-` prefixes.

```
static var prefixedEnableDisable: FlagInversion { get }
```

### Discussion

For example, the `extraOutput` property in this declaration is set to
`true` when a user provides `--enable-extra-output` and to `false` when
the user provides `--disable-extra-output`:

```
@Flag(inversion: .prefixedEnableDisable)
var extraOutput: Bool
```

---

## prefixedNo

Adds a matching flag with a `no-` prefix to represent `false`.

```
static var prefixedNo: FlagInversion { get }
```

### Discussion

For example, the `shouldRender` property in this declaration is set to
`true` when a user provides `--render` and to `false` when the user
provides `--no-render`:

```
@Flag(name: .customLong("render"), inversion: .prefixedNo)
var shouldRender: Bool
```