/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit


final class Common: NSObject {

    // MARK: - Definitions

    // String attribute categories
    enum AttributeType {
        case Key
        case Scalar
        case String
        case Special
        case MarkStart
        case MarkEnd
    }


    // MARK: - Public Properties
    
    var doShowLightBackground: Bool   = false
    // FROM 1.1.0
    var doUseSpecialIndentChar: Bool  = false


    // MARK: - Private Properties
    
    private var doShowRawJson: Bool                 = false
    private var doShowFurniture: Bool               = true
    private var isThumbnail:Bool                    = false
    private var jsonIndent: Int                     = BUFFOON_CONSTANTS.JSON_INDENT
    private var boolStyle: Int                      = BUFFOON_CONSTANTS.BOOL_STYLE.FULL
    private var maxKeyLengths: [Int]                = [0,0,0,0,0,0,0,0,0,0,0,0]
    private var fontSize: CGFloat                   = 0
    // String artifacts...
    private var hr: NSAttributedString              = NSAttributedString.init(string: "")
    private var cr: NSAttributedString              = NSAttributedString.init(string: "")
    // FROM 1.0.2
    private var lineCount: Int                      = 0
    // FROM 1.1.0
    private var sortKeys: Bool                      = true
    private var spacer: String                      = " "
    private var displayColours: [String:String]     = [:]

    // JSON string attributes...
    private var keyAttributes:     [NSAttributedString.Key: Any] = [:]
    private var scalarAttributes:  [NSAttributedString.Key: Any] = [:]
    private var markStartAttributes:    [NSAttributedString.Key: Any] = [:]
    private var markEndAttributes: [NSAttributedString.Key: Any] = [:]
    // FROM 1.1.0
    private var stringAttributes:  [NSAttributedString.Key: Any] = [:]
    private var specialAttributes: [NSAttributedString.Key: Any] = [:]

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions
    
    init(_ isThumbnail: Bool = false) {
        
        super.init()
        
        self.fontSize                   = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        var fontName: String            = BUFFOON_CONSTANTS.BODY_FONT_NAME
        var keyColour: String           = BUFFOON_CONSTANTS.KEY_COLOUR_HEX
        var markColour: String          = BUFFOON_CONSTANTS.MARK_COLOUR_HEX
        var stringColour: String        = BUFFOON_CONSTANTS.STRING_COLOUR_HEX
        var specialColour: String       = BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX

        self.isThumbnail = isThumbnail
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let prefs = UserDefaults(suiteName: appSuiteName) {
            self.doShowFurniture        = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            self.doShowRawJson          = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            self.doShowLightBackground  = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            self.jsonIndent             = isThumbnail ? 2 : prefs.integer(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            self.boolStyle              = isThumbnail ? BUFFOON_CONSTANTS.BOOL_STYLE.TEXT : prefs.integer(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BOOL_STYLE)
            
            self.fontSize               = CGFloat(isThumbnail
                                                  ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE
                                                  : prefs.float(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE))

            fontName                    = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_FONT) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            keyColour                   = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.KEY_COLOUR) ?? BUFFOON_CONSTANTS.KEY_COLOUR_HEX
            markColour                  = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.MARK_COLOUR) ?? BUFFOON_CONSTANTS.MARK_COLOUR_HEX
            // FROM 1.1.0
            stringColour                = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR) ?? BUFFOON_CONSTANTS.STRING_COLOUR_HEX
            specialColour               = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR) ?? BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX
        }
        
        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if self.fontSize < CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[0]) ||
            self.fontSize > CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.count - 1]) {
            self.fontSize = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        }

        // Set the YAML key:value fonts and sizes
        var font: NSFont
        if let chosenFont: NSFont = NSFont.init(name: fontName, size: self.fontSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: self.fontSize)
        }

        // Use a light theme?
        let useLightMode: Bool = isThumbnail || self.doShowLightBackground || isMacInLightMode()

        // Set up the attributed string components we may use during rendering
        self.keyAttributes = [
            .foregroundColor: NSColor.hexToColour(keyColour),
            .font: font
        ]
        
        self.scalarAttributes = [
            .foregroundColor: (useLightMode ? NSColor.black : NSColor.labelColor),
            .font: font
        ]

        self.markStartAttributes = [
            .foregroundColor: NSColor.hexToColour(markColour),
            .font: font
        ]

        let endMarkParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        endMarkParaStyle.paragraphSpacing = self.fontSize * 0.85
        self.markEndAttributes = [
            .foregroundColor: NSColor.hexToColour(markColour),
            .font: font,
            .paragraphStyle: endMarkParaStyle
        ]

        // NOTE This no longer provides a full-width rule -- seek a fix
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (useLightMode ? NSColor.black : NSColor.white)])
        
        self.cr = NSAttributedString.init(string: "\n",
                                          attributes: scalarAttributes)

        // FRON 1.1.0
        self.stringAttributes = [
            .foregroundColor: NSColor.hexToColour(stringColour),
            .font: font
        ]

        self.specialAttributes = [
            .foregroundColor: NSColor.hexToColour(specialColour),
            .font: font
        ]
    }


    /**
     Update certain style variables on a UI mode switch.
     FROM 1.1.0

     This is used by render demo app.
     */
    func resetStylesOnModeChange() {

        // Set up the attributed string components we may use during rendering
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: self.doShowLightBackground ? NSColor.black : NSColor.white])

        self.scalarAttributes[.foregroundColor]  = self.doShowLightBackground ? NSColor.black : NSColor.labelColor
        self.spacer = self.doUseSpecialIndentChar ? "-" : " "
    }


    // MARK: - The Primary Function

    /**
     Render the input JSON as an NSAttributedString.

     - Parameters:
        - jsonFileData: The path to the JSON code.

     - Returns: The rendered source as an NSAttributedString.
     */
    func getAttributedString(_ jsonFileData: Data) -> NSAttributedString {
        
        var renderedString: NSMutableAttributedString

        do {
            // Attempt to parse the JSON data. First, get the data...
            let json: Any = try JSONSerialization.jsonObject(with: jsonFileData, options: [ .fragmentsAllowed ])

            // Calculate column widths based on key sizes
            // FROM 1.1.1 -- Check indent setting
            if (self.jsonIndent == BUFFOON_CONSTANTS.TABULATION_INDENT_VALUE) {
                assembleColumns(json)
            } else {
                for i in 0..<self.maxKeyLengths.count {
                    self.maxKeyLengths[i] = self.jsonIndent
                }
            }


            // ***************************************
            var mString: String = ""
            for i in 0..<self.maxKeyLengths.count {
                mString += "\(self.maxKeyLengths[i]) "
            }

            mString += "\n"
            let maString = NSAttributedString.init(string: mString, attributes: self.keyAttributes)
            // ***************************************



            // ...then render it
            renderedString = prettify(json)


            // ***************************************
            renderedString.insert(maString, at: 0)
            // ***************************************


            // Just in case...
            if renderedString.length == 0 {
                renderedString = NSMutableAttributedString.init(string: "Could not render the JSON.\n\(json)\n",
                                                                attributes: self.keyAttributes)
            }
        } catch {
            // No JSON to render, or the JSON was mis-formatted
            // Assemble the error string
            let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the JSON. ",
                                                                                        attributes: self.keyAttributes)

            // Should we include the raw Json?
            // At least the user can see the data this way
            if self.doShowRawJson {
                errorString.append(NSMutableAttributedString.init(string: "Here is its raw form:",
                                                                  attributes: self.keyAttributes))
                errorString.append(self.hr)
                
                let encoding: String.Encoding = jsonFileData.stringEncoding ?? .utf8
                
                if let jsonFileString: String = String.init(data: jsonFileData, encoding: encoding) {
                    errorString.append(NSMutableAttributedString.init(string: "\(jsonFileString)\n",
                                                                      attributes: self.scalarAttributes))
                } else {
                    errorString.append(NSMutableAttributedString.init(string: "Sorry, this JSON file uses an unsupported coding: \(encoding)\n",
                                                                      attributes: self.scalarAttributes))
                }
            }

            renderedString = errorString
        }
        
        return renderedString as NSAttributedString
    }


    /** REMOVED 1.1.0
     Return a space-prefix NSAttributedString.

     - Parameters:
        - baseString: The string to be indented.
        - indent:     The number of indent spaces to add.
        - isKey:      Are we rendering an inset key (`true`) or value (`false`).

     - Returns: The indented string as an NSAttributedString.

    func getIndentedString(_ baseString: String, _ indent: Int = 0, _ itemType: Int = BUFFOON_CONSTANTS.ITEM_TYPE.VALUE) -> NSAttributedString {
        
        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: self.spacer, count: indent)
        
        var attributes: [NSAttributedString.Key: Any]
        switch itemType {
            case BUFFOON_CONSTANTS.ITEM_TYPE.KEY:
                attributes = self.keyAttributes
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START:
                attributes = self.markStartAttributes
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END:
                attributes = self.markEndAttributes

            default:
                attributes = self.scalarAttributes
        }
        
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString, attributes: self.scalarAttributes))
        indentedString.append(NSAttributedString.init(string: trimmedString, attributes: attributes))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }
     */

    
    /**
     Return a space-prefix NSAttributedString.
     FROM 1.1.0

     - Parameters:
        - baseString:    The string to be indented.
        - indent:        The number of indent spaces to add.
        - attributeType: The attribute to apply.

     - Returns: The indented string as an NSAttributedString.
     */
    private func getIndentedAttributedString(_ baseString: String, _ indent: Int, _ attributeType: AttributeType) -> NSAttributedString {

        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        let spaceString = indent > 0 ? String(repeating: self.spacer, count: indent) : ""
        indentedString.append(NSAttributedString.init(string: spaceString, attributes: getAttributes(.Scalar)))

        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        indentedString.append(NSAttributedString.init(string: trimmedString, attributes: getAttributes(attributeType)))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }


    /**
     Return an attribute dictionary from a passed attribute type.
     FROM 1.1.0

     - Parameters:
        - attributeType: The requested attribute type.

     - Returns: The attributes as a dictionary.
     */
    private func getAttributes(_ attributeType: AttributeType) -> [NSAttributedString.Key: Any] {

        switch attributeType {
            case .Key:
                return self.keyAttributes
            case .MarkStart:
                return self.markStartAttributes
            case .MarkEnd:
                return self.markEndAttributes
            case .String:
                return self.stringAttributes
            case .Special:
                return self.specialAttributes
            default:
                return self.scalarAttributes
        }
    }


    /**
     Return a space-prefix NSAttributedString formed from an image in the app Bundle

     - Parameters:
        - indent:     The number of indent spaces to add.
        - imageName:  The name of the image to load and insert.
     
     - Returns: The indented string as an optional NSAttributedString. Nil indicates an error
     */
    private func getImageString(_ indent: Int = 1, _ imageName: String) -> NSAttributedString? {

        let insetImage: NSTextAttachment = NSTextAttachment()
        insetImage.image = NSImage(named: imageName)
        if insetImage.image != nil {
            insetImage.image!.size = NSMakeSize(insetImage.image!.size.width * self.fontSize / insetImage.image!.size.height, self.fontSize)
            let imageString: NSAttributedString = NSAttributedString(attachment: insetImage)
            let spaceString = String(repeating: self.spacer, count: indent)
            let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
            indentedString.append(NSAttributedString.init(string: spaceString, attributes: self.scalarAttributes))
            indentedString.append(imageString)
            indentedString.append(self.cr)
            return indentedString
        }
        
        return nil
    }
    
    
    /**
     Render a unit of JSON as an NSAttributedString.

     - Parameters:
        - json:           A unit of JSON, type Any.
        - currentLevel:   The current element depth.
        - currentIndent:  How much a subsequent value should be indented.
        - parentIsObject: If the parent is an object.

     - Returns: The indented string as an NSAttributedString.
     */
    private func prettify(_ json: Any, _ currentLevel: Int = 0, _ currentIndent: Int = 0, _ parentIsObject: Bool = false) -> NSMutableAttributedString {

        // Prep an NSMutableAttributedString for this JSON segment
        let renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.keyAttributes)
        
        // FROM 1.0.2
        // Break early at a sensible location, ie. one that
        // leaves us with a valid subset of the source JSON
        // NOTE This can be done better with checks on the returned string
        self.lineCount += 1;
        if self.isThumbnail && (self.lineCount > BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT) {
            return renderedString
        }
        
        // Set the indent based on the current level
        // This will be used for rendering keys and calculating
        // next-level indents. It's just a multiple of the level
        var indent: Int = currentIndent
        if self.isThumbnail {
            indent = currentLevel * BUFFOON_CONSTANTS.BASE_INDENT
        }
        
        // Generate a string according to the JSON element's underlying type
        // FROM 1.0.4 Booleans are 'Bool' and 'Int', so remove the old bool check
        //            and rely on the earlier string encoding in PreviewViewController
        if json is NSNull {
            // Attempt to load the null symbol, but use a text version as a fallback on error
            if self.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                // Display NULL as an image
                let name: String = "null_\(self.boolStyle)"
                if !self.isThumbnail, let addString: NSAttributedString = getImageString(indent, name) {
                    renderedString.append(addString)
                    return renderedString
                }
            }
            
            // Can't or won't show an image? Show text
            renderedString.append(getIndentedAttributedString("NULL\n", indent, .Special))
        } else if json is Int || json is Float || json is Double {
            // Display the number as is
            renderedString.append(getIndentedAttributedString("\(json)\n", indent, .Scalar))
        } else if json is String {
            let value: String = json as! String

            // Is this a shimmed boolean?
            if value == "PREVIEW-JSON-TRUE" || value == "PREVIEW-JSON-FALSE" {
                if self.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                    // Render the bool as an image
                    let name: String = value == "PREVIEW-JSON-TRUE" ? "true_\(self.boolStyle)" : "false_\(self.boolStyle)"
                    if !self.isThumbnail, let addString: NSAttributedString = getImageString(indent, name) {
                        renderedString.append(addString)
                        return renderedString
                    }
                }

                // Can't or won't show an image? Show text
                renderedString.append(getIndentedAttributedString(value == "PREVIEW-JSON-TRUE" ? "TRUE\n" : "FALSE\n", indent, .Special))
            } else {
                // Regular string value; add quotes if necessary
                let stringText: String = self.doShowFurniture ? "“" + (json as! String) + "”\n" : (json as! String) + "\n"
                renderedString.append(getIndentedAttributedString(stringText, indent, .String))
            }
        } else if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            // NOTE Should be only one of each, but value may
            //      be an object or array
            
            if self.doShowFurniture {
                // Add JSON furniture
                renderedString.append(getIndentedAttributedString("{\n", indent, .MarkStart))
            }
            
            let anyObject: [String: Any] = json as! [String: Any]

            // FROM 1.1.0 -- sort dictionaries alphabetically by key
            var keys: [String] = Array(anyObject.keys)
            if self.sortKeys {
                keys = keys.sorted(by: { (a, b) -> Bool in
                    return (a.lowercased() < b.lowercased())
                })
            }

            for key in keys {
                // Get important value types
                let value: Any = anyObject[key]!
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool  = (value is Array<Any>)

                // Print the key
                let keyIndent: Int = self.doShowFurniture ? indent + self.jsonIndent : indent
                renderedString.append(getIndentedAttributedString(key, keyIndent, .Key))

                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element at the next level
                    var nextIndent: Int = indent + self.maxKeyLengths[currentLevel] // + BUFFOON_CONSTANTS.BASE_INDENT
                    if self.doShowFurniture {
                        nextIndent += self.jsonIndent
                    } else {
                        // Next item is on a new line
                        renderedString.append(self.cr)
                    }

                    renderedString.append(prettify(value,
                                                   currentLevel + 1,    // Next level
                                                   nextIndent,
                                                   true))
                } else {
                    // Render the scalar value immediately after the key
                    var scalarIndent: Int = self.jsonIndent == BUFFOON_CONSTANTS.TABULATION_INDENT_VALUE ? self.maxKeyLengths[currentLevel] - key.count : 1
                    //scalarIndent = scalarIndent < 0 ? BUFFOON_CONSTANTS.BASE_INDENT : scalarIndent + BUFFOON_CONSTANTS.BASE_INDENT
                    scalarIndent = scalarIndent < 0 ? 1 : scalarIndent
                    renderedString.append(prettify(value,
                                                   0,                   // Same level
                                                   scalarIndent))
                }
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                renderedString.append(getIndentedAttributedString("}\n", indent, .MarkEnd))
            }
        } else if json is Array<Any> {
            if self.doShowFurniture {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialFurnitureIndent: Int = parentIsObject ? BUFFOON_CONSTANTS.BASE_INDENT : indent
                renderedString.append(getIndentedAttributedString("[\n", initialFurnitureIndent, .MarkStart))
            }
            
            // Iterate over the array's items
            // Array items are always rendered at the same level
            let anyArray: [Any] = json as! [Any]
            var count: Int = 0
            anyArray.forEach { value in
                // Get important value types
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                
                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element on the next level
                    renderedString.append(prettify(value,
                                                   currentLevel + 1,
                                                   indent,
                                                   false))

                    // Separate all but the last item with a blank line
                    if count < anyArray.count - 1 && !self.doShowFurniture {
                        renderedString.append(self.cr)
                    }
                } else {
                    // Render the scalar value
                    renderedString.append(prettify(value,
                                                   0,
                                                   indent))
                }

                count += 1
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                let markIndent: Int = indent - (currentLevel > 0 ? self.maxKeyLengths[currentLevel - 1] : 0)
                renderedString.append(getIndentedAttributedString("]\n", markIndent, .MarkEnd))
            }
        }
        
        return renderedString
    }
    
    
    /**
    Iterate through a JSON element to caclulate the current max. key length.

     - Parameters:
        - json:     The JSON element.
        - level:    The current level.
     */
    private func assembleColumns(_ json: Any, _ level: Int = 0) {

        if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            let anyObject: [String: Any] = json as! [String: Any]
            
            // Get the max key length for the current level
            let keys: [String] = Array(anyObject.keys)
            for key in keys {
                if key.count > self.maxKeyLengths[level] {
                    self.maxKeyLengths[level] = key.count + 1
                }
            }
            
            // Iterate through the keys to run this code for higher levels
            anyObject.forEach { key, value in
                // Check for non-scalar elements
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                
                if valueIsObject || valueIsArray {
                    // Process container values on the next level
                    assembleColumns(value, level + 1)
                }
            }
        } else if json is Array<Any> {
            // For an array, enumerate the elements
            let anyArray: [Any] = json as! [Any]
            anyArray.forEach { value in
                let valueIsObject: Bool = value is Dictionary<String, Any>
                let valueIsArray: Bool = value is Array<Any>
                
                if valueIsObject || valueIsArray {
                    // Process container values on the next level
                    assembleColumns(value, level + 1)
                }
            }
        }
    }


    /**
     Determine whether the host Mac is in light mode.
     FROM 1.1.0

     - Returns: `true` if the Mac is in light mode, otherwise `false`.
     */
    private func isMacInLightMode() -> Bool {

        let appearNameString: String = NSApp.effectiveAppearance.name.rawValue
        return (appearNameString == "NSAppearanceNameAqua")
    }

}


/**
Get the encoding of the string formed from data.

- Returns: The string's encoding or nil.
*/

extension Data {
    
    var stringEncoding: String.Encoding? {
        var nss: NSString? = nil
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: &nss,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


