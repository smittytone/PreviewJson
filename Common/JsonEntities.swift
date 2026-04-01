/*
 *  JsonEntities.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 18/03/2026.
 *  Early pre-release assistance on `JSONParser`  provided by Anthropic Claude.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit


public struct Cell {

    var text: NSAttributedString? = nil
    var row: Int = 0
    var col: Int = 0
    var width: CGFloat = 0.0
    var isVal: Bool = false
}


/*
 JSON Marker types. TO REMOVE
 */
public enum JSONMarkType {

    case objectOpen
    case objectClose
    case arrayOpen
    case arrayClose
    case none

    func string() -> String {

        switch self {
            case .objectOpen:
                return "{ "
            case .objectClose:
                return " }"
            case .arrayOpen:
                return "[ "
            case .arrayClose:
                return " ]"
            default:
                return  ""
        }
    }
}


/*
 A Paragraph as extracted from a line of JSON.
 */
public class Paragraph {

    var text: NSMutableAttributedString? = nil      // The paragraph's styled text
    var depth: Int = 0                              // The paragraph's inset level
    var keyLength: CGFloat = 0.0                    // If the paragraph is prefixed with a key, it's length in points

    init(text: NSMutableAttributedString? = nil, depth: Int = 0, keyLength: CGFloat = 0.0) {

        self.text = text
        self.depth = depth
        self.keyLength = keyLength
    }
}


/*
 An order-preserving JSON entity.
 */
public enum JSONValue {

    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])


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


internal struct JSONParser {

    let characters: [Unicode.Scalar]
    var index: Int = 0

    var atEnd: Bool {
        self.index >= self.characters.count
    }

    var current: Unicode.Scalar? {
        self.atEnd ? nil : self.characters[self.index]
    }

    init(_ string: String) {

        self.characters = Array(string.unicodeScalars)
    }


    // MARK: Whitespace

    /**
     Step over whitespace at the cursor.
     */
    mutating func skipWhitespace() {

        while let c = self.current, c == " " || c == "\t" || c == "\n" || c == "\r" {
            self.index += 1
        }
    }


    // MARK: Top-level value dispatch

    mutating func parseValue() -> JSONValue? {

        // Ignore whitespace at the start...
        skipWhitespace()

        // ...then get the first character
        guard let c = self.current else {
            return nil
        }

        // Use the first character as a pointer to the data type
        switch c {
            case "{":
                return parseObject()
            case "[":
                return parseArray()
            case "\"":
                return parseString().map { .string($0) }
            case "t","f","n":
                return parseLiteral()
            case "-", "0"..."9":
                return parseNumber()
            default:
                return nil
        }
    }


    // MARK: - Data-type Parser Functions

    mutating func parseObject() -> JSONValue {

        // Skip the opening mark
        self.index += 1
        var pairs: [(key: String, value: JSONValue)] = []

        while true {
            // Get next valid character or exit
            skipWhitespace()
            guard let c = self.current else { break }

            // End of the object so skip over the mark and exit
            if c == "}" {
                self.index += 1
                break
            }

            // Skip comma (lenient if missing)
            if !pairs.isEmpty {
                if self.current == "," {
                    self.index += 1
                }
            }

            // Backstop after a final comma
            skipWhitespace()
            guard let peek = self.current else { break }
            if peek == "}" {
                self.index += 1
                break
            }

            // Get a key, or skip if it's malformed
            guard let key = parseString() else {
                self.index += 1
                continue
            }

            // Move on past thepair separator
            skipWhitespace()
            if self.current == ":" {
                self.index += 1
            }

            // Get the key's value (or set to NULL if empty)
            skipWhitespace()
            let value = parseValue() ?? .null
            pairs.append((key: key, value: value))
        }

        return .object(pairs)
    }


    mutating func parseArray() -> JSONValue {

        // Skip the opening mark
        self.index += 1
        var elements: [JSONValue] = []

        while true {
           // Get next valid character or exit
           skipWhitespace()
           guard let c = self.current else { break }

           // End of the array so skip over the mark and exit
           if c == "]" {
               self.index += 1
               break
           }

           // Skip comma (lenient if missing)
           if !elements.isEmpty {
               if self.current == "," {
                   self.index += 1
               }
           }

           // Backstop after a terminal comma
           skipWhitespace()
           guard let peek = current else { break }
           if peek == "]" {
               self.index += 1
               break
           }

           // Get the vlue
           if let element = parseValue() {
               elements.append(element)
           } else {
               self.index += 1 // skip unrecognised character
           }
        }

        return .array(elements)
    }

    mutating func parseString() -> String? {

        // Skip the opening quote, if there is one (bail if not)
        guard self.current == "\"" else { return nil }
        self.index += 1
        var result = ""

        // Build up the string
        while let c = self.current {
            // Exit on the closing quote
            if c == "\"" {
                self.index += 1
                return result
            }

            // Handle escaped characters
            if c == "\\" {
                self.index += 1

                // Return the string on a partial escape
                guard let escaped = self.current else { return result }
                switch escaped {
                    case "\"":
                        result.append("\"")
                    case "\\":
                        result.append("\\")
                    case "/":
                        result.append("/")
                    case "n":
                        result.append("\n")
                    case "r":
                        result.append("\r")
                    case "t":
                        result.append("\t")
                    case "b":
                        result.append("\u{08}")
                    case "f":
                        result.append("\u{0C}")
                    case "u":
                        self.index += 1
                        var hex = ""
                        for _ in 0..<4 {
                            guard let h = self.current else { break }
                            hex.append(Character(h))
                            self.index += 1
                        }

                        if hex.count == 4, let cp = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(cp) {
                            result.append(Character(scalar))
                        }

                        continue
                    default:
                        result.append(Character(escaped))
                }
            } else {
                result.append(Character(c))
            }

            self.index += 1
        }

        return result
    }


    mutating func parseNumber() -> JSONValue? {

        var s = ""

        // Handle a negative value
        if self.current == "-" {
            s.append("-")
            index += 1
        }

        // Handle numeric characters
        s.append(parseDigits())

        // Handle decimal point
        if self.current == "." {
            s.append(".")
            self.index += 1
            s.append(parseDigits())
        }

        // Handle exponent values
        if self.current == "e" || self.current == "E" {
            s.append(Character(self.current!))
            self.index += 1
            if self.current == "+" || self.current == "-" {
                s.append(Character(self.current!))
                self.index += 1
            }

            s.append(parseDigits())
        }

        guard !s.isEmpty, s != "-", let d = Double(s) else { return nil }
        return .number(d)
    }


    mutating func parseDigits() -> String {

        var s = ""
        while let c = self.current, c >= "0" && c <= "9" {
            s.append(Character(c))
            self.index += 1
        }

        return s
    }


    mutating func parseLiteral() -> JSONValue? {

        let possibles: [(String, JSONValue)] = [
            ("true", .bool(true)), ("false", .bool(false)), ("null", .null)
        ]

        for (word, value) in possibles {
            let wordCharacters = Array(word.unicodeScalars)
            let available = min(wordCharacters.count, self.characters.count - self.index)
            let slice = Array(self.characters[self.index..<self.index + available])

            // Accept if what we have matches the start of the keyword
            if slice == Array(wordCharacters.prefix(available)) {
                self.index += available
                return value
            }
        }

        // Unknown identifier — skip it
        while let c = self.current, (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_" {
            self.index += 1
        }

        return nil
    }
}
