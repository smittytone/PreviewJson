/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2022.
 *  Copyright © 2022 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit


final class Common: NSObject {
    
    // MARK: - Public Properties
    
    var doShowLightBackground: Bool   = false
    var doShowTag: Bool               = true
    
    // MARK: - Private Properties
    
    private var doShowRawJson: Bool   = false
    private var doShowFurniture: Bool = true
    private var isThumbnail:Bool      = false
    private var jsonIndent: Int       = BUFFOON_CONSTANTS.JSON_INDENT
    private var maxKeyLengths: [Int]  = []
    private var fontSize: CGFloat     = 0
    
    // JSON string attributes...
    private var keyAtts:     [NSAttributedString.Key: Any] = [:]
    private var valAtts:     [NSAttributedString.Key: Any] = [:]
    private var markAtts:    [NSAttributedString.Key: Any] = [:]
    private var markEndAtts: [NSAttributedString.Key: Any] = [:]
    private var padAtts:     [NSAttributedString.Key: Any] = [:]
    
    // String artifacts...
    private var hr: NSAttributedString      = NSAttributedString.init(string: "")
    private var hr_dark: NSAttributedString = NSAttributedString.init(string: "")
    private var newLine: NSAttributedString = NSAttributedString.init(string: "")
    private var padLine: NSAttributedString = NSAttributedString.init(string: "")

    // MARK:- Lifecycle Functions
    
    init(_ isThumbnail: Bool = false) {
        
        super.init()
        
        var fontBaseSize: CGFloat       = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        var fontBaseName: String        = BUFFOON_CONSTANTS.CODE_FONT_NAME
        var codeColour: String          = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        
        self.isThumbnail = isThumbnail
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let prefs = UserDefaults(suiteName: MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME) {
            self.doShowFurniture        = prefs.bool(forKey: "com-bps-previewjson-do-indent-scalars")
            self.doShowRawJson          = prefs.bool(forKey: "com-bps-previewjson-show-bad-json")
            self.doShowLightBackground  = prefs.bool(forKey: "com-bps-previewjson-do-use-light")
            self.jsonIndent             = isThumbnail ? 2 : prefs.integer(forKey: "com-bps-previewjson-json-indent")
            
            fontBaseSize = CGFloat(isThumbnail
                                   ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE
                                   : prefs.float(forKey: "com-bps-previewjson-base-font-size"))
            fontBaseName                = prefs.string(forKey: "com-bps-previewjson-base-font-name") ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            codeColour                  = prefs.string(forKey: "com-bps-previewjson-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        }
        
        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if fontBaseSize < CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[0]) ||
            fontBaseSize > CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.count - 1]) {
            fontBaseSize = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        }

        // Set the YAML key:value fonts and sizes
        var font: NSFont
        if let chosenFont: NSFont = NSFont.init(name: fontBaseName, size: fontBaseSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: fontBaseSize)
        }
        
        self.fontSize = fontBaseSize
        
        // Set up the attributed string components we may use during rendering
        self.keyAtts = [
            .foregroundColor: NSColor.hexToColour(codeColour),
            .font: font
        ]
        
        self.valAtts = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor),
            .font: font
        ]
        
        let markParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        markParaStyle.paragraphSpacing = fontBaseSize * 0.75
        
        self.markAtts = [
            .foregroundColor: NSColor.hexToColour("FFFF00FF"),
            .font: font
        ]
        
        self.markEndAtts = [
            .foregroundColor: NSColor.hexToColour("FFFF00FF"),
            .font: font,
            .paragraphStyle: markParaStyle
        ]
        
        self.padAtts = [
            .foregroundColor: NSColor.hexToColour(codeColour),
            .font: NSFont.systemFont(ofSize: fontBaseSize * 2.0)
        ]
        
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.white)])
        
        self.hr_dark = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                  .strikethroughColor: NSColor.hexToColour("666666FF")])
        
        self.newLine = NSAttributedString.init(string: "\n",
                                               attributes: valAtts)
        
        self.padLine = NSAttributedString.init(string: "\n",
                                               attributes: padAtts)
    }
    
    
    // MARK:- The Primary Function

    /**
     Render the input JSON as an NSAttributedString.

     - Parameters:
        - jsonFileData: The path to the JSON code.

     - Returns: The rendered source as an NSAttributedString.
     */
    func getAttributedString(_ jsonFileData: Data) -> NSAttributedString {

        // Set up the base string
        var renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                       attributes: self.valAtts)
        
        do {
            // Attempt to parse the JSON data. First, get the data...
            let json: Any = try JSONSerialization.jsonObject(with: jsonFileData, options: [])
            
            // ...then renderr it
            //self.maxKeyLengths.removeAll()
            //self.maxKeyLengths = [0]
            //assembleColumns(json)
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
                                                                      attributes: self.valAtts))
                } else {
                    errorString.append(NSMutableAttributedString.init(string: "Sorry, this JSON file uses an unsupported coding: \(encoding)\n",
                                                                      attributes: self.valAtts))
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
        let spaces = "                                                     "
        let spaceString = String(spaces.suffix(indent))
        
        var attributes: [NSAttributedString.Key: Any]
        switch itemType {
            case BUFFOON_CONSTANTS.ITEM_TYPE.KEY:
                attributes = self.keyAtts
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START:
                attributes = self.markAtts
            case BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END:
                attributes = self.markEndAtts
            default:
                attributes = self.valAtts
        }
        
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString))
        indentedString.append(NSAttributedString.init(string: trimmedString))
        indentedString.setAttributes(attributes,
                                     range: NSMakeRange(0, indentedString.length))
        
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
            insetImage.image!.size = NSMakeSize(self.fontSize, self.fontSize)
            let imageString: NSAttributedString = NSAttributedString(attachment: insetImage)
            
            let spaces = "                                                     "
            let spaceString = String(spaces.suffix(indent))
            
            let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
            indentedString.append(NSAttributedString.init(string: spaceString))
            indentedString.setAttributes(self.valAtts,
                                         range: NSMakeRange(0, indentedString.length))
            indentedString.append(imageString)
            indentedString.append(self.newLine)
            return indentedString
        }
        
        return nil
    }
    
    
    /**
    Iterate through a JSON element to caclulate the current max. key length

     - Parameters:
        - json:     The JSON element.
        - level:    The current level.
     */
    func assembleColumns(_ json: Any, _ level: Int = 0) {
        
        if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            let anyObject: [String: Any] = json as! [String: Any]
            
            // Get the max key length for the current level
            anyObject.forEach { key, value in
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
                    if self.maxKeyLengths.count == level + 1 {
                        self.maxKeyLengths.append(0)
                    }
                    
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
                    assembleColumns(value, level)
                }
            }
        }
    }
    
    /**
     Render a unit of JSON as a NSAttributedString.

     - Parameters:
        - json:     A unit of JSON, type Any.
        - indent:   The number of indent spaces to add.

     - Returns: The indented string as an NSAttributedString.
     */
    func prettify(_ json: Any, _ level: Int = 0, _ indent: Int = 0, _ parentIsObject: Bool = false) -> NSMutableAttributedString {
        
        // Prep an NSMutableAttributedString for this JSON segment
        let renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                        attributes: self.keyAtts)
        
        // Set the indent based on whether we're showing JSON furniture or not
        // let baseIndent: Int = indent
        
        // Generate a string according to the JSON element's underlying type
        // NOTE Booleans are 'Bool' and 'Int', so make sure we do the Bool
        //      check first
        if json is Bool {
            // Attempt to load the true/false symbol, but use a text version as a fallback on error
            if let addString: NSAttributedString = getImageString(indent, json as! Bool ? "true" : "false") {
                renderedString.append(addString)
            } else {
                renderedString.append(getIndentedString(json as! Bool ? "TRUE\n" : "FALSE\n", indent))
            }
        } else if json is NSNull {
            // Attempt to load the null symbol, but use a text version as a fallback on error
            if let addString: NSAttributedString = getImageString(indent, "null") {
                renderedString.append(addString)
            } else {
                renderedString.append(getIndentedString("NULL\n", indent))
            }
        } else if json is Int || json is Float || json is Double {
            // Display the number as is
            renderedString.append(getIndentedString("\(json)\n", indent))
        } else if json is String {
            // Display the string in curly quotes
            // Need to do extra inset work here
            renderedString.append(getIndentedString("“\(json)”\n", indent))
        } else if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            // NOTE Should be only one of each, but value may
            //      be an object or array
            
            if self.doShowFurniture {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialFurnitureIndent: Int = parentIsObject ? BUFFOON_CONSTANTS.BASE_INDENT : indent
                renderedString.append(getIndentedString("{\n",
                                                        initialFurnitureIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START))
            } else {
                if level > 0 { renderedString.append(newLine) }
            }
            
            let anyObject: [String: Any] = json as! [String: Any]
            anyObject.forEach { key, value in
                // Get important value types
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                
                // Print the key
                renderedString.append(getIndentedString(key,
                                                        indent + self.jsonIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.KEY))

                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element on a new line, at the next level
                    renderedString.append(prettify(value,
                                                   level + 1,
                                                   self.isThumbnail ? BUFFOON_CONSTANTS.BASE_INDENT : indent + self.jsonIndent,
                                                   valueIsObject || valueIsArray))
                } else {
                    // Render the scalar value immediately after the key
                    renderedString.append(prettify(value,
                                                   level,
                                                   BUFFOON_CONSTANTS.BASE_INDENT))
                }
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                renderedString.append(getIndentedString("}\n",
                                                        indent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END))
            } else {
                renderedString.append(newLine)
            }
            
            // Add a pale line after base-level items
            if level == 0 {
                renderedString.append(self.hr_dark)
            }
        } else if json is Array<Any> {
            if self.doShowFurniture {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialFurnitureIndent: Int = parentIsObject ? BUFFOON_CONSTANTS.BASE_INDENT : indent
                renderedString.append(getIndentedString("[\n",
                                                        initialFurnitureIndent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_START))
            } else {
                if level > 0 { renderedString.append(newLine) }
            }
            
            // Iterate over the array's items
            let anyArray: [Any] = json as! [Any]
            anyArray.forEach { value in
                // Get important value types
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                
                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element on the next level
                    renderedString.append(prettify(value,
                                                   level + 1,
                                                   self.isThumbnail ? BUFFOON_CONSTANTS.BASE_INDENT : indent + self.jsonIndent))
                } else {
                    // Render the scalar value
                    renderedString.append(prettify(value,
                                                   level,
                                                   indent + self.jsonIndent))
                }
            }
            
            if self.doShowFurniture {
                // Bookend with JSON furniture
                renderedString.append(getIndentedString("]\n",
                                                        indent,
                                                        BUFFOON_CONSTANTS.ITEM_TYPE.MARK_END))
            } else {
                renderedString.append(newLine)
            }
        }
        
        return renderedString
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


