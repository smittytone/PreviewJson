/*
 *  GenericColorExtension.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 18/06/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation
import Cocoa


extension NSColor {

   /**
     Class function to return an NSColor object that matches the colour supplied as a RGBA hex value.

     - Parameters:
        - colourValue: The colour as a hex string `RRGGBBAA`, eg `FF00AA88`.

     - Returns An NSColor object.
     */
    static func hexToColour(_ colourValue: String) -> NSColor {

        var colourString = colourValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if (colourString.hasPrefix("#")) {
            // The colour is defined by a hex value
            colourString = String(colourString.dropFirst())
        }

        // Colours in hex strings have 3, 6 or 8 (6 + alpha) values
        if ![8, 6, 3].contains(colourString.count) {
            return NSColor.gray
        }

        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 0
        var divisor: CGFloat
        var alpha: CGFloat = 1.0

        if colourString.count == 6 || colourString.count == 8 {
            // Decode a six/eight-character hex string
            let rString = colourString[0..<2]
            let gString = colourString[2..<4]
            let bString = colourString[4..<6]

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)

            divisor = 255.0

            if colourString.count == 8 {
                // Decode the eight-character hex string's alpha value
                let aString = colourString[6..<8]
                Scanner(string: aString).scanHexInt64(&a)
                alpha = CGFloat(a) / divisor
            }
        } else {
            // Decode a three-character hex string
            let rString = colourString[0..<1]
            let gString = colourString[1..<2]
            let bString = colourString[2..<3]

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)
            divisor = 15.0
        }

        return NSColor(red: CGFloat(r) / divisor, green: CGFloat(g) / divisor, blue: CGFloat(b) / divisor, alpha: alpha)
    }


    /**
     Convert a colour's internal representation into an RGB+A hex string.
     */
    var hexString: String {

        guard let rgbColour = usingColorSpace(.sRGB) else {
            return "FF0000FF"
        }

        let red = Int(round(rgbColour.redComponent * 0xFF))
        let green = Int(round(rgbColour.greenComponent * 0xFF))
        let blue = Int(round(rgbColour.blueComponent * 0xFF))
        let alpha = Int(round(rgbColour.alphaComponent * 0xFF))

        let hexString = NSString(format: "%02X%02X%02X%02X", red, green, blue, alpha)
        return hexString as String
    }
}


extension NSAttributedString {

    /**
     Return the width of the rendered string in points.
     */
    var width: CGFloat {
        let rectA = boundingRect(
          with: NSSize(width: Double.infinity, height: Double.infinity),
          options: [.usesLineFragmentOrigin]
        )

        let textStorage = NSTextStorage(attributedString: self)
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0.0
        layoutManager.glyphRange(for: textContainer)

        let rectB = layoutManager.usedRect(for: textContainer)
        return ceil(max(rectA.width, rectB.width))
    }
}


extension CGFloat {

    /**
     Determine if the instance is near enough the specified value as makes no odds.

     - Parameters
        - value: The float value we're comparing the instance to.

     - Returns `true` if the values are proximate, otherwise `false`.
     */
    func isClose(to value: CGFloat) -> Bool {

        let rndA = (self * 100).rounded() / 100
        let rndB = (value * 100).rounded() / 100

        if self == value || rndA == rndB {
            return true
        }

        let absA: CGFloat = abs(self)
        let absB: CGFloat = abs(value)
        let diff: CGFloat = abs(self - value)

        if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}


extension Double {

    /**
     Determine if the instance is near enough the specified value as makes no odds.

     - Parameters
        - value: The float value we're comparing the instance to.

     - Returns `true` if the values are proximate, otherwise `false`.
     */
    func isClose(to value: CGFloat) -> Bool {

        let rndA = (self * 100).rounded() / 100
        let rndB = (value * 100).rounded() / 100

        if self == value || rndA == rndB {
            return true
        }

        let absA: Double = abs(self)
        let absB: Double = abs(value)
        let diff: Double = abs(self - value)

        if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}


extension Data {

    var stringEncoding: String.Encoding? {
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: nil,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


extension NSApplication {

    var inLightMode: Bool {
        // FROM 2.0.3 -- use a better check than string values
        return effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }
}


extension String {

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, self.count)..<self.count]
    }

    func substring(toIndex: Int) -> String {
        return self[0..<max(0, toIndex)]
    }

    subscript(r: Range<Int>) -> String {
        let bounds = (lower: max(0, min(self.count, r.lowerBound)), upper: min(self.count, max(0, r.upperBound)))
        let range = Range(uncheckedBounds:bounds)
        let start = index(self.startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
