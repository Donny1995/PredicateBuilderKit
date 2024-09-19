# PredicateBuilder

**PredicateBuilder** is a Swift library designed to simplify the creation and management of `NSPredicate` objects. It provides a fluent and expressive interface for building complex predicates, making it easier to filter data in Core Data, `NSArray`, and other collections that support predicates.

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Classes](#classes)
  - [PredicateBuilder](#predicatebuilder-class)
  - [ImmutablePredicateBuilder](#immutablepredicatebuilder-class)
- [Enums](#enums)
  - [Relation](#relation)
  - [RelationForString](#relationforstring)
  - [Aggregation](#aggregation)
- [Usage Examples](#usage-examples)
  - [Basic Comparison](#basic-comparison)
  - [String Comparison with Options](#string-comparison-with-options)
  - [Aggregation](#aggregation-example)
  - [Combining Predicates](#combining-predicates)
  - [Negation](#negation)
  - [Subquery](#subquery)
- [License](#license)

---

## Overview

`PredicateBuilder` streamlines the process of creating `NSPredicate` objects by providing a chainable and type-safe API. It supports various comparison relations, string-specific relations, and aggregation operations, allowing developers to build predicates without dealing with the complexity of predicate format strings.

## Simple example
```swift
  //updatedAt > CAST(748429210.498109, "NSDate") AND
  //organization.country CONTAINS[c] "Рус" AND
  //classifier.deletedAt == nil AND
  //classifier.category.idd IN { "water", "electricity" }
        
  let predicate = PredicateBuilder()
    .add(key: #keyPath(DBTicket.updatedAt), relation: .greater, value: Date() as NSDate)
    .add(key: #keyPath(DBTicket.organization.country), relation: .contains(caseInsensitive: true), value: "Рус")
    .add(key: #keyPath(DBTicket.classifier.deletedAt), value: NSNull())
    .add(key: #keyPath(DBTicket.classifier.category.idd), relation: .in, value: ["water", "electricity"])
    //.build()

  //SUBQUERY(employees, $s, $s.organization.idd == "1452").@count > 0
  let predicate2 = PredicateBuilder()
    .add(key: #keyPath(DBOrganizationEmployee.organization.idd), value: "1452")
    .wrapIntoSubquery(key: #keyPath(DBOrganization.employees))
    //.build()

  //(updatedAt > CAST(748429974.027069, "NSDate") AND organization.country CONTAINS[c] "Рус" AND classifier.deletedAt == nil AND classifier.category.idd IN {"water", "electricity"}) AND (SUBQUERY(employees, $s, $s.organization.idd == "1452").@count > 0)
  let predicate3 = predicate + predicate2
  
```

## Installation

To use `PredicateBuilder` in your project, add the source files to your project or include it via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PredicateBuilder.git", from: "1.0.0")
]
```

## Getting Started

Import the library into your Swift file:

```swift
import PredicateBuilder
```

Create an instance of `PredicateBuilder` and start adding conditions using the provided methods.

## Classes

### PredicateBuilder Class

`PredicateBuilder` is the main class you will interact with. It inherits from `ImmutablePredicateBuilder` and provides methods to add conditions and build the final `NSPredicate`.

#### Initialization

```swift
public override init(conjunction: NSCompoundPredicate.LogicalType = .and)
```

- **Parameters:**
  - `conjunction`: The logical type (`.and` or `.or`) used to combine multiple conditions. Default is `.and`.

#### Methods

##### add<T>

Adds a comparison condition to the predicate.

```swift
@discardableResult
public func add<T>(
    key: String,
    subKey: String? = nil,
    relation: Relation = .equal,
    value: T?
) -> Self where T: CVarArg
```

- **Parameters:**
  - `key`: The key path of the property to compare.
  - `subKey`: An optional sub-key for relationships.
  - `relation`: The comparison relation (e.g., `.equal`, `.greater`).
  - `value`: The value to compare against.

##### add (String-specific)

Adds a string-specific condition to the predicate.

```swift
@discardableResult
public func add(
    key: String,
    subKey: String? = nil,
    relation: RelationForString,
    value: String
) -> Self
```

- **Parameters:**
  - `key`: The key path of the property to compare.
  - `subKey`: An optional sub-key for relationships.
  - `relation`: The string-specific relation (e.g., `.contains`, `.beginsWith`).
  - `value`: The string value to compare against.

##### addAggregation<T>

Adds an aggregation condition (e.g., `ANY`, `ALL`) to the predicate.

```swift
@discardableResult
public func addAggregation<T>(
    aggregation: Aggregation = .ANY,
    key: String,
    subKey: String? = nil,
    relation: Relation = .equal,
    value: T?
) -> Self where T: CVarArg
```

- **Parameters:**
  - `aggregation`: The aggregation type (`.ANY`, `.ALL`, etc.).
  - `key`: The key path of the property to compare.
  - `subKey`: An optional sub-key for relationships.
  - `relation`: The comparison relation.
  - `value`: The value to compare against.

##### addRaw

Adds a raw `NSPredicate` to the builder. Use this method as a last resort when other methods do not cover your use case.

```swift
@discardableResult
public func addRaw(_ predicate: NSPredicate) -> Self
```

- **Parameters:**
  - `predicate`: The `NSPredicate` to add.

##### wrapIntoSubquery

Wraps the current predicate into a subquery.

```swift
public func wrapIntoSubquery(
    key: String,
    relation: Relation = .greater,
    count: Int = 0
) -> PredicateBuilder
```

- **Parameters:**
  - `key`: The key path for the subquery.
  - `relation`: The comparison relation for the subquery count.
  - `count`: The count to compare against.

##### wrapIntoNegation

Negates the current predicate.

```swift
public func wrapIntoNegation() -> PredicateBuilder
```

---

### ImmutablePredicateBuilder Class

`ImmutablePredicateBuilder` provides the foundational methods for building and combining predicates.

#### Methods

##### build

Builds and returns the final `NSPredicate`.

```swift
public func build() -> NSPredicate
```

##### combining

Combines the current predicate with another using the specified logical type.

```swift
public func combining(
    conjunction: NSCompoundPredicate.LogicalType,
    with other: ImmutablePredicateBuilder
) -> PredicateBuilder
```

- **Parameters:**
  - `conjunction`: The logical type (`.and` or `.or`) used for combining.
  - `other`: Another `ImmutablePredicateBuilder` instance.

##### Operators

You can use the `+` and `||` operators to combine predicates.

```swift
public static func + (
    lhs: ImmutablePredicateBuilder,
    rhs: ImmutablePredicateBuilder
) -> PredicateBuilder

public static func || (
    lhs: ImmutablePredicateBuilder,
    rhs: ImmutablePredicateBuilder
) -> PredicateBuilder
```

##### combine (Static Method)

Combines multiple builders into one using the specified logical type.

```swift
public static func combine(
    conjunction: NSCompoundPredicate.LogicalType,
    builders: [ImmutablePredicateBuilder]
) -> PredicateBuilder
```

- **Parameters:**
  - `conjunction`: The logical type used for combining.
  - `builders`: An array of `ImmutablePredicateBuilder` instances.

---

## Enums

### Relation

Defines basic comparison relations.

```swift
public enum Relation {
    case equal
    case notEqual
    case less
    case greater
    case lessOrEqual
    case greaterOrEqual
    case `in`

    internal var `operator`: String { get }
}
```

- **Cases:**
  - `.equal`: `==`
  - `.notEqual`: `!=`
  - `.less`: `<`
  - `.greater`: `>`
  - `.lessOrEqual`: `<=`
  - `.greaterOrEqual`: `>=`
  - `.in`: `IN`

### RelationForString

Defines string-specific comparison relations with options for case and diacritic insensitivity.

```swift
public enum RelationForString {
    case contains(caseInsensitive: Bool = false, diacritic: Bool = false)
    case like(caseInsensitive: Bool = false, diacritic: Bool = false)
    case beginsWith(caseInsensitive: Bool = false, diacritic: Bool = false)
    case endsWith(caseInsensitive: Bool = false, diacritic: Bool = false)
    case matches(caseInsensitive: Bool = false, diacritic: Bool = false)

    internal var `operator`: String { get }
}
```

- **Options:**
  - `caseInsensitive`: When `true`, the comparison ignores case.
  - `diacritic`: When `true`, the comparison ignores diacritic marks.

### Aggregation

Defines aggregation operators for collections.

```swift
public enum Aggregation: String {
    case ANY
    case SOME
    case ALL
    case NONE
}
```

- **Cases:**
  - `.ANY`: At least one element satisfies the condition.
  - `.SOME`: Synonym for `.ANY`.
  - `.ALL`: All elements satisfy the condition.
  - `.NONE`: No elements satisfy the condition.

---

## Usage Examples

### Basic Comparison

```swift
let predicate = PredicateBuilder()
    .add(key: "age", relation: .greaterOrEqual, value: 18)
    .build()
```

This creates a predicate that filters for entities where the `age` property is greater than or equal to 18.

### String Comparison with Options

```swift
let predicate = PredicateBuilder()
    .add(
        key: "name",
        relation: .contains(caseInsensitive: true, diacritic: true),
        value: "smith"
    )
    .build()
```

This creates a predicate that filters for entities where the `name` property contains "smith", ignoring case and diacritic marks.

### Aggregation Example

```swift
let predicate = PredicateBuilder()
    .addAggregation(
        aggregation: .ALL,
        key: "orders",
        subKey: "status",
        relation: .equal,
        value: "completed"
    )
    .build()
```

This creates a predicate that filters for entities where all related `orders` have a `status` of "completed".

### Combining Predicates

```swift
let predicate1 = PredicateBuilder()
    .add(key: "age", relation: .greaterOrEqual, value: 18)

let predicate2 = PredicateBuilder()
    .add(key: "country", relation: .equal, value: "USA")

let combinedPredicate = predicate1 + predicate2
let finalPredicate = combinedPredicate.build()
```

This combines two predicates using the logical `AND` operator.

### Negation

```swift
let predicate = PredicateBuilder()
    .add(key: "isActive", relation: .equal, value: true)
    .wrapIntoNegation()
    .build()
```

This creates a predicate that filters for entities where `isActive` is not `true`.

### Subquery

```swift
let predicate = PredicateBuilder()
    .add(key: "category", subKey: "price", relation: .greaterOrEqual, value: 100)
    .wrapIntoSubquery(key: "items")
    .build()
```

This creates a predicate that filters for entities where the count of `items` with a `price` greater than or equal to 100 is greater than 0.
Example: `"SUBQUERY(items, $category, $category.price >= 100).@count > 0"`
---

## License

This library is released under the [MIT License](LICENSE).

---

**Note:** The `PredicateBuilder` library simplifies the creation of `NSPredicate` objects but does not cover every possible use case. For complex predicates not supported by the provided methods, consider using `addRaw(_:)` with caution.
