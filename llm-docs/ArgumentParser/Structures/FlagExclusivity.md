# FlagExclusivity

The options for treating enumeration-based flags as exclusive.

```
struct FlagExclusivity
```

---

## chooseFirst

The first enumeration case that is provided is used.

```
static var chooseFirst: FlagExclusivity { get }
```

---

## chooseLast

The last enumeration case that is provided is used.

```
static var chooseLast: FlagExclusivity { get }
```

---

## exclusive

Only one of the enumeration cases may be provided.

```
static var exclusive: FlagExclusivity { get }
```