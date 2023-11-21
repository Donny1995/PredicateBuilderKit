//
//  PredicateBuilder.swift
//  Core
//
//  Created by Sivash Alexander Alexeevich on 15.11.2021.
//

import CoreData

typealias PB = PredicateBuilder
/// Это класс, способный на генерацию NSPredicate. см add(), build() и combine()
public class PredicateBuilder: ImmutablePredicateBuilder {
    
    public override init(conjuction: NSCompoundPredicate.LogicalType = .and) {
        super.init(conjuction: conjuction)
    }
    
    public enum Relation {
        case equal, notEqual, less, greater, lessOrEqual, greaterOrEqual
        case `in`
        
        var `operator`: String {
            switch self {
                case .equal: return "=="
                case .notEqual: return "!="
                case .less: return "<"
                case .greater: return ">"
                case .lessOrEqual: return "<="
                case .greaterOrEqual: return ">="
                case .in: return "IN"
            }
        }
    }
    
    public enum RelationForString {
        
        case contains(caseInsensitive: Bool = false, diacritic: Bool = false) //%K CONTAINS[cd] %@
        case like(caseInsensitive: Bool = false, diacritic: Bool = false) //%K LIKE[cd] %@
        case beginsWith(caseInsensitive: Bool = false, diacritic: Bool = false) //%K BEGINSWITH[cd] %@
        case endsWith(caseInsensitive: Bool = false, diacritic: Bool = false) //%K ENDSWITH[cd] %@
        case matches(caseInsensitive: Bool = false, diacritic: Bool = false) //%K MATCHES[cd] %@
        
        var `operator`: String {
            switch self {
                case .contains(let caseInSensitive, let diacritic): return "CONTAINS" + cdPostfix(caseInSensitive, diacritic)
                case .like(let caseInSensitive, let diacritic): return "LIKE" + cdPostfix(caseInSensitive, diacritic)
                case .beginsWith(let caseInsensitive, let diacritic): return "BEGINSWITH" + cdPostfix(caseInsensitive, diacritic)
                case .endsWith(let caseInsensitive, let diacritic): return "ENDSWITH" + cdPostfix(caseInsensitive, diacritic)
                case .matches(let caseInsensitive, let diacritic): return "MATCHES" + cdPostfix(caseInsensitive, diacritic)
            }
        }
        
        /// - Parameters:
        ///   - c: [c] case insensitive: lower & uppercase values are treated the same
        ///   - d: [d] diacritic insensitive: special characters treated as the base character. ё == е
        ///   - n: [n] supersedes c and d, is a performance optimization option
        ///   - l: [l] localized insensetive "straße" == "strasse" and etc
        /// - Returns: "[cd]" or nothing or [c] or [d]
        func cdPostfix(_ c: Bool, _ d: Bool) -> String {
            var temp = ""
            if c { temp += "c" }
            if d { temp += "d" }
            if !temp.isEmpty {
                temp = String(format: "[%@]", temp)
            }
            return temp
        }
    }
    
    public enum Aggregation: String {
        case ANY
        case SOME
        case ALL
        case NONE
    }
    
    /// Добавить expression в цепочку условий предиката, которые скрепляются через `self.currentConjuction`.
    @discardableResult public func add<T: CVarArg>(key: String, subKey: String? = nil, relation: Relation = .equal, value: T?) -> Self {
        var argumentsArray: [CVarArg] = []
        
        let (shouldAddValueToArgsList, valueFormatter, _value) = valueFormatter(for: value)
        let format = ["%K" + (subKey == nil ? "" : ".%K"), relation.operator, valueFormatter].joined(separator: " ")
        
        argumentsArray.append(key)
        if let subkey = subKey {
            argumentsArray.append(subkey)
        }
        
        if shouldAddValueToArgsList {
            argumentsArray.append(_value!)
        }
        
        expressionsArray.append(NSPredicate(format: format, argumentArray: argumentsArray))
        
        return self
    }
    
    ///%K LIKE[cd] "hell?"
    /// - Parameters:
    ///   - key: ключ
    ///   - subKey: второй ключ через . для связей ONE-to-whatever
    ///   - relation: .like, .beginsWith, .endsWith, .matches
    ///   - value: значение
    @discardableResult public func add(key: String, subKey: String? = nil, relation: RelationForString, value: String) -> Self {
        var argumentsArray: [CVarArg] = []
        
        let format = ["%K" + (subKey == nil ? "" : ".%K"), relation.operator, "%@"].joined(separator: " ")
        
        argumentsArray.append(key)
        if let subkey = subKey {
            argumentsArray.append(subkey)
        }
        argumentsArray.append(value)
        
        expressionsArray.append(NSPredicate(format: format, argumentArray: argumentsArray))
        
        return self
    }
    
    ///(ANY SOME ALL NONE) %K.%K == %@
    @discardableResult public func addAggregation<T: CVarArg>(aggregation: Aggregation = .ANY, key: String, subKey: String? = nil, relation: Relation = .equal, value: T?) -> Self {
        var argumentsArray: [CVarArg] = []
        
        let (shouldAddValueToArgsList, valueFormatter, _value) = valueFormatter(for: value)
        
        let format = subKey == nil
            ? "\(aggregation.rawValue) %K " + relation.operator + " " + valueFormatter
            : "\(aggregation.rawValue) %K.%K " + relation.operator + " " + valueFormatter
        
        argumentsArray.append(key)
        if let subKey = subKey {
            argumentsArray.append(subKey)
        }
        
        if shouldAddValueToArgsList {
            argumentsArray.append(_value!)
        }
        
        expressionsArray.append(NSPredicate(format: format, argumentArray: argumentsArray))
        
        return self
    }
    
    /// Использовать в самом крайнем случае
    @discardableResult public func addRaw(_ predicate: NSPredicate) -> Self {
        expressionsArray.append(predicate)
        return self
    }
    
    ///~~Не работает с сложносоставленными предикатами типа "(...) AND (...) ..." полученными путем обращений к .combine.~~
    ///Работает с любыми предикатами. Наверное.
    public func wrapIntoSubquery(key: String, relation: Relation = .greater, count: Int = 0) -> PredicateBuilder {
        let newPredicate = PredicateBuilder()
        var bakedPredicate = "\(build())"
        
        var indexCorrection = 0
        let regex = try! NSRegularExpression(pattern: #"(\w+(?:\.[\w]+)*)\s+(>|>=|<|<=|!=|==|=|IN)"#, options: [])
        for match in regex.matches(in: bakedPredicate, options: [], range: NSRange(location: 0, length: bakedPredicate.count)) {
            if match.numberOfRanges > 0 {
                let insertionIndex = bakedPredicate.index(bakedPredicate.startIndex, offsetBy: match.range(at: 0).location + indexCorrection)
                bakedPredicate.insert(contentsOf: "$s.", at: insertionIndex)
                indexCorrection += 3
            }
        }
        
        newPredicate.expressionsArray.append(NSPredicate(
            format: "SUBQUERY(%K, $s, \(bakedPredicate)).@count \(relation.operator) %d",
            argumentArray: [key, count]
        ))
        
        return newPredicate
    }
    
    //NOT(...)
    public func wrapIntoNegation() -> PredicateBuilder {
        let builder = PredicateBuilder()
        builder.compoundExpression = NSCompoundPredicate(type: .not, subpredicates: [ build() ])
        return builder
    }
    
    func valueFormatter<T: CVarArg>(for value: T?) -> (shouldAddValueToArgsList: Bool, valueFormatter: String, value: CVarArg?) {
        
        var valueFormatter: String! = "%@"
        var shouldAddValueToArgsList = true
        var _value: CVarArg? = value
        
        if value == nil || (value as? NSNull != nil) {
            shouldAddValueToArgsList = false
            valueFormatter = "NULL"         // %K == NULL
            
        } else if let array = value as? [CVarArg] { //This somehow works for Set<Something> too, and there is no difference.
            valueFormatter = "%@"
            _value = NSArray(array: array)
            
        } else if let value = value {
            if value is Int64 {
                valueFormatter = "%lld"     //%K == %lld
                
            } else if let value = value as? Bool {
                _value = NSNumber(booleanLiteral: value)
                valueFormatter = "%@"
                
            } else {
                valueFormatter = "%@"       // %K == %@
            }
        }
        
        return (shouldAddValueToArgsList, valueFormatter, _value)
    }
}

public class ImmutablePredicateBuilder {
    
    fileprivate var expressionsArray: [NSPredicate] = []
    fileprivate var compoundExpression: NSCompoundPredicate?
    fileprivate let currentConjuction: NSCompoundPredicate.LogicalType
    
    fileprivate init(conjuction: NSCompoundPredicate.LogicalType) {
        self.currentConjuction = conjuction
    }
    
    public func build() -> NSPredicate {
        if expressionsArray.isEmpty {
            return compoundExpression ?? NSPredicate(value: true)
                
        } else {
            let basePredicate = NSCompoundPredicate(type: currentConjuction, subpredicates: expressionsArray)
            
            if let compoundExpression {
                return NSCompoundPredicate(type: currentConjuction, subpredicates: [basePredicate, compoundExpression])
            } else {
                return basePredicate
            }
        }
    }
    
    public func combining(conjunction: NSCompoundPredicate.LogicalType, with: ImmutablePredicateBuilder) -> PredicateBuilder {
        if compoundExpression == nil && self.expressionsArray.isEmpty {
            let newBuilder = PredicateBuilder()
            newBuilder.compoundExpression = with.compoundExpression
            newBuilder.expressionsArray = with.expressionsArray
            return newBuilder
            
        } else if with.compoundExpression == nil && with.expressionsArray.isEmpty {
            let newBuilder = PredicateBuilder()
            newBuilder.compoundExpression = self.compoundExpression
            newBuilder.expressionsArray = self.expressionsArray
            return newBuilder
            
        } else {
            return PredicateBuilder.combine(conjunction: conjunction, builders: [self, with])
        }
    }
    
    public static func + (_ lhs: ImmutablePredicateBuilder, _ rhs: ImmutablePredicateBuilder) -> PredicateBuilder {
        return lhs.combining(conjunction: .and, with: rhs)
    }
    
    public static func || (_ lhs: ImmutablePredicateBuilder, _ rhs: ImmutablePredicateBuilder) -> PredicateBuilder {
        return lhs.combining(conjunction: .or, with: rhs)
    }
    
    public static func combine(conjunction: NSCompoundPredicate.LogicalType, builders: [ImmutablePredicateBuilder]) -> PredicateBuilder {
        let newBuilder = PredicateBuilder()
        newBuilder.compoundExpression = NSCompoundPredicate(type: conjunction, subpredicates: builders.map { $0.build() })
        return newBuilder
    }
}
