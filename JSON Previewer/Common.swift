/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit


final class Common: NSObject {
    
    // MARK: - Public Properties
    
    var doShowLightBackground: Bool   = false


    // MARK: - Private Properties
    
    private var doShowRawJson: Bool         = false
    private var doShowFurniture: Bool       = true
    private var isThumbnail:Bool            = false
    private var jsonIndent: Int             = BUFFOON_CONSTANTS.JSON_INDENT
    private var boolStyle: Int              = BUFFOON_CONSTANTS.BOOL_STYLE.FULL
    private var maxKeyLengths: [Int]        = [0,0,0,0,0,0,0,0,0,0,0,0]
    private var fontSize: CGFloat           = 0
    // String artifacts...
    private var hr: NSAttributedString      = NSAttributedString.init(string: "")
    private var cr: NSAttributedString      = NSAttributedString.init(string: "")
    // FROM 1.0.2
    private var lineCount: Int              = 0
    // FROM 1.0.5
    private var sortKeys: Bool              = true

    // JSON string attributes...
    private var keyAtts:     [NSAttributedString.Key: Any] = [:]
    private var scalarAtts:  [NSAttributedString.Key: Any] = [:]
    private var markAtts:    [NSAttributedString.Key: Any] = [:]
    private var markEndAtts: [NSAttributedString.Key: Any] = [:]


    // MARK: - Lifecycle Functions
    
    init(_ isThumbnail: Bool = false) {
        
        super.init()
        
        self.fontSize           = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        var fontName: String    = BUFFOON_CONSTANTS.CODE_FONT_NAME
        var codeColour: String  = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        var markColour: String  = BUFFOON_CONSTANTS.MARK_COLOUR_HEX
        
        self.isThumbnail = isThumbnail
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let prefs = UserDefaults(suiteName: MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME) {
            self.doShowFurniture        = prefs.bool(forKey: "com-bps-previewjson-do-indent-scalars")
            self.doShowRawJson          = prefs.bool(forKey: "com-bps-previewjson-show-bad-json")
            self.doShowLightBackground  = prefs.bool(forKey: "com-bps-previewjson-do-use-light")
            self.jsonIndent             = isThumbnail ? 2 : prefs.integer(forKey: "com-bps-previewjson-json-indent")
            self.boolStyle              = isThumbnail ? BUFFOON_CONSTANTS.BOOL_STYLE.TEXT : prefs.integer(forKey: "com-bps-previewjson-bool-style")
            
            self.fontSize = CGFloat(isThumbnail
                                     ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE
                                   : prefs.float(forKey: "com-bps-previewjson-base-font-size"))

            fontName    = prefs.string(forKey: "com-bps-previewjson-base-font-name") ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            codeColour  = prefs.string(forKey: "com-bps-previewjson-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            markColour  = prefs.string(forKey: "com-bps-previewjson-mark-colour-hex") ?? BUFFOON_CONSTANTS.MARK_COLOUR_HEX
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
        
        // Set up the attributed string components we may use during rendering
        self.keyAtts = [
            .foregroundColor: NSColor.hexToColour(codeColour),
            .font: font
        ]
        
        self.scalarAtts = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor),
            .font: font
        ]
        
        self.markAtts = [
            .foregroundColor: NSColor.hexToColour(markColour),
            .font: font
        ]
        
        let markParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        markParaStyle.paragraphSpacing = self.fontSize * 0.85
        
        self.markEndAtts = [
            .foregroundColor: NSColor.hexToColour(markColour),
            .font: font,
            .paragraphStyle: markParaStyle
        ]
        
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.white)])
        
        self.cr = NSAttributedString.init(string: "\n",
                                               attributes: scalarAtts)
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

            assembleColumns(json)

            // ...then render it
            renderedString = prettify(json)
            
            // Just in case...
            if renderedString.length == 0 {
                renderedString = NSMutableAttributedString.init(string: "Could not render the JSON.\n\(json)\n",
                                                                attributes: self.keyAtts)
            }
        } catch {
            // No JSON to render, or the JSON was mis-formatted
            // Assemble the error string
            let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the JSON. ",
                                                                                        attributes: self.keyAtts)

            // Should we include the raw Json?
            // At least the user can see the data this way
            if self.doShowRawJson {
                errorString.append(NSMutableAttributedString.init(string: "Here is its raw form:",
                                                                  attributes: self.keyAtts))
                errorString.append(self.hr)
                
                let encoding: String.Encoding = jsonFileData.stringEncoding ?? .utf8
                
                if let jsonFileString: String = String.init(data: jsonFileData, encoding: encoding) {
                    errorString.append(NSMutableAttributedString.init(string: "\(jsonFileString)\n",
                                                                      attributes: self.scalarAtts))
                } else {
                    errorString.append(NSMutableAttributedString.init(string: "Sorry, this JSON file uses an unsupported coding: \(encoding)\n",
                                                                      attributes: self.scalarAtts))
                }
            }

            renderedString = errorString
        }
        
        return renderedString as NSAttributedString
    }


    /**
     Return a space-prefix NSAttributedString.

     - Parameters:
        - baseString: The string to be indented.
        - indent:     The number of indent spaces to add.
        - isKey:      Are we rendering an inset key (`true`) or value (`false`).

     - Returns: The indented string as an NSAttributedString.
     */
    func getIndentedString(_ baseString: String, _ indent: Int = 0, _ itemType: Int = BUFFOON_CONSTANTS.ITEM_TYPE.VALUE) -> NSAttributedString {
        
        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: "-", count: indent)
        
        var attributes: [NSAttributedString.Key: Any]
        switch itemType {
            case BUFFOON_CONSTANTS.ITEM_TYPE.KEY:
                attributes = self.keyAtts
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START:
                attributes = self.markAtts
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END:
                attributes = self.markEndAtts
            default:
                attributes = self.scalarAtts
        }
        
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString, attributes: self.scalarAtts))
        indentedString.append(NSAttributedString.init(string: trimmedString, attributes: attributes))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }


    /**
     Return a space-prefix NSAttributedString formed from an image in the app Bundle

     - Parameters:
        - indent:     The number of indent spaces to add.
        - imageName:  The name of the image to load and insert.
     
     - Returns: The indented string as an optional NSAttributedString. Nil indicates an error
     */
    func getImageString(_ indent: Int = 1, _ imageName: String) -> NSAttributedString? {
        
        let insetImage: NSTextAttachment = NSTextAttachment()
        insetImage.image = NSImage(named: imageName)
        if insetImage.image != nil {
            insetImage.image!.size = NSMakeSize(insetImage.image!.size.width * self.fontSize / insetImage.image!.size.height, self.fontSize)
            let imageString: NSAttributedString = NSAttributedString(attachment: insetImage)
            let spaceString = String(repeating: " ", count: indent)
            let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
            indentedString.append(NSAttributedString.init(string: spaceString, attributes: scalarAtts))
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
    func prettify(_ json: Any, _ currentLevel: Int = 0, _ currentIndent: Int = 0, _ parentIsObject: Bool = false) -> NSMutableAttributedString {
        
        // Prep an NSMutableAttributedString for this JSON segment
        let renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                       attributes: self.keyAtts)
        
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
        // var currentIndent: Int = currentLevel * self.jsonIndent
        if self.isThumbnail {
            //currentIndent = currentLevel * BUFFOON_CONSTANTS.BASE_INDENT
        }
        
        // Generate a string according to the JSON element's underlying type
        // FROM 1.0.4 Booleans are 'Bool' and 'Int', so remove the old bool check
        //            and rely on the earlier string encoding in PreviewViewController
        if json is NSNull {
            // Attempt to load the null symbol, but use a text version as a fallback on error
            if self.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let name: String = "null_\(self.boolStyle)"
                if !self.isThumbnail, let addString: NSAttributedString = getImageString(currentIndent, name) {
                    renderedString.append(addString)
                    return renderedString
                }
            }
            
            // Can't or won't show an image? Show text
            renderedString.append(getIndentedString(getStringOutput(currentLevel, "NULL") + "\n", currentIndent))
        } else if json is Int || json is Float || json is Double {
            // Display the number as is
            renderedString.append(getIndentedString(getStringOutput(currentLevel, json) + "\n", currentIndent))
        } else if json is String {
            // Display the string in curly quotes
            // Need to do extra inset work here
            let value: String = json as! String
            if value == "JSON-TRUE" || value == "JSON-FALSE" {
                // We have a string-encoded boolean
                if self.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                    let name: String = value == "JSON-TRUE"
                    ? "true_\(self.boolStyle)"
                    : "false_\(self.boolStyle)"
                    
                    if !self.isThumbnail, let addString: NSAttributedString = getImageString(currentIndent, name) {
                        renderedString.append(addString)
                        return renderedString
                    }
                }
                
                renderedString.append(getIndentedString(value == "JSON-TRUE"
                                                        ? getStringOutput(currentLevel, "TRUE") + "\n"
                                                        : getStringOutput(currentLevel, "FALSE") + "\n", currentIndent))
            } else {
                renderedString.append(getIndentedString("“" + getStringOutput(currentLevel, json) + "”\n", currentIndent))
            }
        } else if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            // NOTE Should be only one of each, but value may
            //      be an object or array
            
            if self.doShowFurniture {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialFurnitureIndent: Int = parentIsObject ? BUFFOON_CONSTANTS.BASE_INDENT : currentIndent
                renderedString.append(getIndentedString("{\n",
                                                        currentIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START))
            }
            
            let anyObject: [String: Any] = json as! [String: Any]

            // FROM 1.0.5 -- sort dictionaries alphabetically by key
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
                let valueIsArray: Bool = (value is Array<Any>)

                // Print the key
                renderedString.append(getIndentedString(getStringOutput(currentLevel, key),
                                                        self.doShowFurniture ? currentIndent + self.jsonIndent : currentIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.KEY))

                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element at the next level
                    var nextIndent: Int = currentIndent + BUFFOON_CONSTANTS.BASE_INDENT + self.maxKeyLengths[currentLevel]
                    if self.doShowFurniture { nextIndent += self.jsonIndent }
                    if !self.doShowFurniture { renderedString.append(cr) }
                    renderedString.append(prettify(value,
                                                   currentLevel + 1,    // Next level
                                                   nextIndent,
                                                   true))
                } else {
                    // Render the scalar value immediately after the key
                    var scalarIndent: Int = self.maxKeyLengths[currentLevel] - key.count
                    if scalarIndent < 0 { scalarIndent = 0 }
                    scalarIndent += BUFFOON_CONSTANTS.BASE_INDENT
                    renderedString.append(prettify(value,
                                                   0,                   // Same level
                                                   scalarIndent))
                }
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                renderedString.append(getIndentedString("}\n",
                                                        currentIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END))
            }
        } else if json is Array<Any> {
            if self.doShowFurniture {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialFurnitureIndent: Int = parentIsObject ? BUFFOON_CONSTANTS.BASE_INDENT : currentIndent
                renderedString.append(getIndentedString("[\n",
                                                        initialFurnitureIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START))
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
                                                   currentIndent,
                                                   false))

                    if count < anyArray.count - 1 && !self.doShowFurniture { renderedString.append(cr) }
                } else {
                    // Render the scalar value
                    renderedString.append(prettify(value,
                                                   0,
                                                   currentIndent))
                }

                count += 1
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                renderedString.append(getIndentedString("]\n",
                                                        currentIndent - self.jsonIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END))
            }
        }
        
        return renderedString
    }
    
    
    /**
    Present a string with or without the level displayed for debugging.

     - Parameters:
        - level:    The current level.
        - json:     The JSON element.
     */
    func getStringOutput(_ level: Int, _ source: Any) -> String {
        
        if BUFFOON_CONSTANTS.RENDER_DEBUG {
            return "\(level)-\(source)"
        }
        
        return "\(source)"
    }
    
    
    /**
    Iterate through a JSON element to caclulate the current max. key length.

     - Parameters:
        - json:     The JSON element.
        - level:    The current level.
     */
    func assembleColumns(_ json: Any, _ level: Int = 0) {
        
        if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            let anyObject: [String: Any] = json as! [String: Any]
            
            // Get the max key length for the current level
            /*
            anyObject.forEach { key, value in
                if key.count > self.maxKeyLengths[level] {
                    self.maxKeyLengths[level] = key.count
                }
            }
             */
            let keys: [String] = Array(anyObject.keys)
            for key in keys {
                if key.count > self.maxKeyLengths[level] {
                    self.maxKeyLengths[level] = key.count
                }
            }
            
            // Iterate through the keys to run this code for higher levels
            anyObject.forEach { key, value in
                // Check for non-scalar elements
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                
                if valueIsObject || valueIsArray {
                    // Prepare the next level
                    //if self.maxKeyLengths.count == level + 1 { self.maxKeyLengths.append(0) }
                    
                    // Process the next level
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
                    // Process the array contents on the current level
                    assembleColumns(value, level + 1)
                }
            }
        }
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


