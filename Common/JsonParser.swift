//
//  JsonParser.swift
//  PreviewJson
//
//  Created by Tony Smith on 19/03/2026.
//

import Foundation


internal struct JSONParser {

    let scalars: [Unicode.Scalar]
    var pos: Int = 0

    var atEnd: Bool {
        self.pos >= self.scalars.count
    }
    var current: Unicode.Scalar? {
        self.atEnd ? nil : self.scalars[self.pos]
    }

    init(_ string: String) {

        self.scalars = Array(string.unicodeScalars)
    }


    // MARK: Whitespace

    mutating func skipWhitespace() {

        while let c = self.current, c == " " || c == "\t" || c == "\n" || c == "\r" {
            self.pos += 1
        }
    }


    // MARK: Top-level value dispatch

    mutating func parseValue() -> JSONValue? {

        skipWhitespace()
        guard let c = current else {
            return nil
        }

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

    // MARK: Object

    mutating func parseObject() -> JSONValue {

        self.pos += 1  // consume '{'
        var pairs: [(key: String, value: JSONValue)] = []

        while true {
            skipWhitespace()
            guard let c = self.current else { break }    // EOF → return partial result
            if c == "}" {
                self.pos += 1
                break
            }

            if !pairs.isEmpty {
                if self.current == "," { // consume comma (lenient if missing)
                    self.pos += 1
                }
            }

            skipWhitespace()
            guard let peek = self.current else { break }
            if peek == "}" {
                self.pos += 1
                break
            }

            // Key
            guard let key = parseString() else {
                self.pos += 1                             // skip unrecognised character and try again
                continue
            }

            skipWhitespace()
            if self.current == ":" {
                self.pos += 1
            }          // consume ':'

            skipWhitespace()
            let value = parseValue() ?? .null
            pairs.append((key: key, value: value))
        }

        return .object(pairs)
    }


    // MARK: Array

    mutating func parseArray() -> JSONValue {

        self.pos += 1  // consume '['
        var elements: [JSONValue] = []

        while true {
            skipWhitespace()
            guard let c = self.current else { break }    // EOF → return partial result
            if c == "]" {
                self.pos += 1
                break
            }

            if !elements.isEmpty {
                if self.current == "," {
                    self.pos += 1
                }
            }

            skipWhitespace()
            guard let peek = current else { break }
            if peek == "]" {
                self.pos += 1
                break
            }

            if let element = parseValue() {
                elements.append(element)
            } else {
                self.pos += 1 // skip unrecognised character
            }
        }

        return .array(elements)
    }

    // MARK: String

    mutating func parseString() -> String? {

        guard self.current == "\"" else { return nil }
        self.pos += 1  // consume opening quote
        var result = ""

        while let c = self.current {
            if c == "\"" {
                self.pos += 1
                return result
            }   // closing quote

            if c == "\\" {
                self.pos += 1
                guard let escaped = self.current else { return result }  // partial escape → return as-is
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
                        self.pos += 1
                        var hex = ""
                        for _ in 0..<4 {
                            guard let h = self.current else { break }
                            hex.append(Character(h))
                            self.pos += 1
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

            self.pos += 1
        }

        return result  // unterminated string → return what we have
    }

    // MARK: Number

    mutating func parseNumber() -> JSONValue? {
        
        var s = ""

        // Handle a negative value
        if self.current == "-" {
            s.append("-")
            pos += 1
        }

        // Handle numeric characters
        s.append(parseDigits())
        /*
        while let c = self.current, c >= "0" && c <= "9" {
            s.append(Character(c))
            self.pos += 1
        }
         */

        // Handle decimal point
        if self.current == "." {
            s.append(".")
            self.pos += 1
            s.append(parseDigits())
            /*
            while let c = self.current, c >= "0" && c <= "9" {
                s.append(Character(c))
                self.pos += 1
            }
             */
        }

        // Handle exponent values
        if self.current == "e" || self.current == "E" {
            s.append(Character(self.current!))
            self.pos += 1
            if self.current == "+" || self.current == "-" {
                s.append(Character(self.current!))
                self.pos += 1
            }

            s.append(parseDigits())
            /*
             while let c = self.current, c >= "0" && c <= "9" {
                s.append(Character(c))
                self.pos += 1
            }
             */
        }

        guard !s.isEmpty, s != "-", let d = Double(s) else { return nil }
        return .number(d)
    }

    mutating func parseDigits() -> String {

        var s = ""
        while let c = self.current, c >= "0" && c <= "9" {
            s.append(Character(c))
            self.pos += 1
        }

        return s
    }


    // MARK: Literals (true / false / null) — partial-tolerant

    mutating func parseLiteral() -> JSONValue? {

        let candidates: [(String, JSONValue)] = [
            ("true", .bool(true)), ("false", .bool(false)), ("null", .null)
        ]

        for (word, value) in candidates {
            let wordScalars = Array(word.unicodeScalars)
            let available   = min(wordScalars.count, self.scalars.count - self.pos)
            let slice       = Array(self.scalars[self.pos..<self.pos + available])

            // Accept if what we have matches the start of the keyword
            if slice == Array(wordScalars.prefix(available)) {
                self.pos += available
                return value
            }
        }

        // Unknown identifier — skip it
        while let c = self.current, (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_" {
            self.pos += 1
        }
        
        return nil
    }
}
