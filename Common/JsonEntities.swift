//
//  Entities.swift
//  PreviewJson
//
//  Created by Tony Smith on 19/03/2026.
//

import Foundation


// MARK: - JSONValue

public enum JSONValue {

    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])  // Array of pairs preserves order


    // Accessors
    public var stringValue: String? {
        if case .string(let v) = self {
            return v
        }

        return nil
    }

    public var numberValue: Double? {
        if case .number(let v) = self {
            return v
        }

        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self {
            return v
        }

        return nil
    }

    public var isNull: Bool {
        if case .null = self {
            return true
        }

        return false
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let v) = self {
            return v
        }

        return nil
    }

    public var objectValue: [(key: String, value: JSONValue)]? {
        if case .object(let v) = self {
            return v
        }

        return nil
    }

    // Subscript objects by key (first match).
    public subscript(key: String) -> JSONValue? {
        objectValue?.first(where: { $0.key == key })?.value
    }

    // Subscript arrays by index.
    public subscript(index: Int) -> JSONValue? {
        guard let arr = arrayValue, arr.indices.contains(index) else {
            return nil
        }

        return arr[index]
    }
}


// MARK: - CustomStringConvertible

extension JSONValue: CustomStringConvertible {

    public var description: String {

        switch self {
            case .string(let s):
                return "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\""
            case .number(let n):
                return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
            case .bool(let b):    
                return b ? "TRUE" : "FALSE"
            case .null:           
                return "NULL"
            case .array(let a):   
                return "[\(a.map(\.description).joined(separator: ", "))]"
            case .object(let ps): 
                return "{\(ps.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", "))}"
        }
    }
}
