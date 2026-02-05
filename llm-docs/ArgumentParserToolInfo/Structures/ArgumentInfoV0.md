# ArgumentInfoV0

All information about a particular argument, including display names and
options.

```
struct ArgumentInfoV0
```

---

## ArgumentInfoV0.NameInfoV0

Information about an argument’s name.

```
struct NameInfoV0
```

---

## init(from:)

```
init(from decoder: any Decoder) throws
```

---

## init(kind:shouldDisplay:sectionTitle:isOptional:isRepeating:parsingStrategy:names:preferredName:valueName:defaultValue:allValueStrings:allValueDescriptions:completionKind:abstract:discussion:)

```
init(kind: KindV0, shouldDisplay: Bool, sectionTitle: String?, isOptional: Bool, isRepeating: Bool, parsingStrategy: ParsingStrategyV0, names: [NameInfoV0]?, preferredName: NameInfoV0?, valueName: String?, defaultValue: String?, allValueStrings: [String]?, allValueDescriptions: [String : String]?, completionKind: CompletionKindV0?, abstract: String?, discussion: String?)
```

---

## abstract

Short description of the argument’s functionality.

```
var abstract: String?
```

---

## allValueDescriptions

Mapping of valid values to descriptions of the value.

```
var allValueDescriptions: [String : String]?
```

---

## allValueStrings

List of all valid values.

```
var allValueStrings: [String]? { get set }
```

---

## allValues

List of all valid values.

```
var allValues: [String]?
```

---

## completionKind

The type of completion to use for an argument or an option value.

```
var completionKind: CompletionKindV0?
```

### Discussion

`nil` if the tool uses the default completion kind.

---

## defaultValue

Default value of the argument is none is specified on the command line.

```
var defaultValue: String?
```

---

## discussion

Extended description of the argument’s functionality.

```
var discussion: String?
```

---

## isOptional

Argument can be omitted.

```
var isOptional: Bool
```

---

## isRepeating

Argument can be specified multiple times.

```
var isRepeating: Bool
```

---

## kind

Kind of argument the ArgumentInfo describes.

```
var kind: KindV0
```

---

## names

All names of the argument.

```
var names: [NameInfoV0]?
```

---

## parsingStrategy

Parsing strategy of the ArgumentInfo.

```
var parsingStrategy: ParsingStrategyV0
```

---

## preferredName

The best name to use when referring to the argument in help displays.

```
var preferredName: NameInfoV0?
```

---

## sectionTitle

Custom name of argument’s section.

```
var sectionTitle: String?
```

---

## shouldDisplay

Argument should appear in help displays.

```
var shouldDisplay: Bool
```

---

## valueName

Name of argument’s value.

```
var valueName: String?
```

---

## ArgumentInfoV0.CompletionKindV0

```
enum CompletionKindV0
```

---

## ArgumentInfoV0.KindV0

Kind of argument.

```
enum KindV0
```

---

## ArgumentInfoV0.ParsingStrategyV0

```
enum ParsingStrategyV0
```