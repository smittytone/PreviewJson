/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit


final class Common {

    // MARK: - Definitions

    // String attribute categories
    enum AttributeType {
        case Key
        case Scalar
        case String
        case Special
        case Debug
        case MarkStart
        case MarkEnd
        case Custom
    }


    // MARK: - Public Properties

    var doShowLightBackground: Bool                 = false
    // FROM 1.1.0
    var doUseSpecialIndentChar: Bool                = false
    // FROM 2.0.0
    var settings: PJSettings                        = PJSettings()


    // MARK: - Private Properties
    
    private var isThumbnail:Bool                    = false
    private var maxKeyLengths: [Int]                = [0,0,0,0,0,0,0,0,0,0,0,0]
    // String artifacts...
    private var hr: NSMutableAttributedString       = NSMutableAttributedString(string: "")
    private var cr: NSAttributedString              = NSAttributedString(string: "")
    // FROM 1.0.2
    private var lineCount: Int                      = 0
    // FROM 1.1.0
    private var sortKeys: Bool                      = true
    private var spacer: String                      = " "
    private var displayColours: [String:String]     = [:]
    // FROM 1.1.1
    private var debugSpacer: String                 = "."
    // FROM 2.0.0
    private var emptyString: NSMutableAttributedString = NSMutableAttributedString(string: "*")

    // JSON string attributes...
    private var keyAttributes:          [NSAttributedString.Key: Any] = [:]
    private var scalarAttributes:       [NSAttributedString.Key: Any] = [:]
    private var markStartAttributes:    [NSAttributedString.Key: Any] = [:]
    private var markEndAttributes:      [NSAttributedString.Key: Any] = [:]
    // FROM 1.1.0
    private var stringAttributes:       [NSAttributedString.Key: Any] = [:]
    private var specialAttributes:      [NSAttributedString.Key: Any] = [:]
    // FROM 1.1.1
    private var debugAttributes:        [NSAttributedString.Key: Any] = [:]
    private var lineAttributes:         [NSAttributedString.Key: Any] = [:]


    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions
    
    init(forThumbnail isThumbnail: Bool) {
        
        self.settings.loadSettings(self.appSuiteName)
        self.isThumbnail = isThumbnail

        if self.settings.fontSize < BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[0] ||
            self.settings.fontSize > BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.count - 1] {
            self.settings.fontSize = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
        }

        // Set the JSON key:value fonts and sizes
        var font: NSFont
        if let chosenFont: NSFont = NSFont(name: self.settings.fontName, size: self.settings.fontSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: self.settings.fontSize)
        }

        // Use a light theme?
        let useLightMode: Bool = isThumbnail || self.settings.doReverseMode

        // Set up the attributed string components we may use during rendering
        let endMarkParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        endMarkParaStyle.paragraphSpacing = self.settings.fontSize * 0.25
        endMarkParaStyle.tabStops = []
        for i in stride(from: 10.0, through: 120.0, by: 10.0) {
            endMarkParaStyle.tabStops.append(NSTextTab(type: .leftTabStopType, location: i))
        }

        endMarkParaStyle.defaultTabInterval = CGFloat(self.settings.indentSize * 10) // ASSUME NO TABLULATION!!!!

        self.keyAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.KEYS),
            .font: font
        ]
        
        self.scalarAttributes = [
            .foregroundColor: (useLightMode ? NSColor.black : NSColor.labelColor),
            .font: font
        ]

        self.markStartAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.MARKS),
            .font: font
        ]

        self.markEndAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.MARKS),
            .font: font
        ]

        // NOTE This no longer provides a full-width rule -- seek a fix

        self.hr = NSMutableAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (useLightMode ? NSColor.black : NSColor.white)])

        // FROM 2.0.0
        // New, TextKit 2-friendly horizontal rule



        self.cr = NSAttributedString(string: BUFFOON_CONSTANTS.CR, attributes: scalarAttributes)

        // FRON 1.1.0
        let stringParaStyle = endMarkParaStyle
        stringParaStyle.headIndent = CGFloat(self.settings.indentSize) * 20.0
        self.stringAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.STRINGS),
            .font: font
        ]

        self.specialAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.SPECIALS),
            .font: font
        ]

        self.lineAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 6.0)
        ]

#if DEBUG
        self.debugAttributes = [
            .foregroundColor: NSColor.hexToColour("444444FF"),
            .font: font,
            .paragraphStyle: endMarkParaStyle
        ]
#endif
    }


    /**
     Update certain style variables on a UI mode switch.
     FROM 1.1.0

     This is used by render demo app.
     */
    func resetStylesOnModeChange() {

        // Set up the attributed string components we may use during rendering
        /*
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: self.doShowLightBackground ? NSColor.black : NSColor.white])
         */

        self.scalarAttributes[.foregroundColor]  = self.doShowLightBackground ? NSColor.black : NSColor.labelColor
        self.spacer = self.doUseSpecialIndentChar ? "-" : " "
    }


    // MARK: - The Primary Function

    /*

     */
    public func getAttStr(fromJson json: String) -> NSAttributedString {

        // Convert the JSON string into JSON entities, then convert them
        // into a series of paragraph objects
        let previewParagraphs = NSMutableArray()
        let renderString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        var parser = JSONParser(json)
        prettify(parser.parseValue()!, 0, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), previewParagraphs)

        // These are required for tabulation
        var maxDepth = -1
        var maxKeyWidths: [Int: CGFloat] = [:]
        for i in 0..<previewParagraphs.count {
            let paragraph = previewParagraphs.object(at: i) as! Paragraph
            if paragraph.depth > maxDepth {
                maxDepth = paragraph.depth
            }

            if maxKeyWidths[paragraph.depth] == nil {
                maxKeyWidths[paragraph.depth] = paragraph.keyLength
            } else if paragraph.keyLength > maxKeyWidths[paragraph.depth]! {
                maxKeyWidths[paragraph.depth] = paragraph.keyLength
            }
        }

        // Assemble the final attributed string
        // NOTE Do with an autorelease pool?
        for i in 0..<previewParagraphs.count {
            let paragraph = previewParagraphs.object(at: i) as! Paragraph
            if var paragraphText = paragraph.text {
                let inset: CGFloat = CGFloat(paragraph.depth) * 20.0 * CGFloat(self.settings.indentSize)

                if self.settings.showJsonMarks && paragraph.marker != .none {
                    let marker = paragraph.marker.string()
                    let attrMarker = NSMutableAttributedString(string: marker, attributes: self.markStartAttributes)

                    if i == 0 {
                        attrMarker.append(paragraphText)
                        paragraphText = attrMarker
                    } else {
                        paragraphText.append(attrMarker)
                    }
                }

                if paragraphText.length > 0 {
                    // Instantiate a generic paragraph style
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.firstLineHeadIndent = inset
                    paragraphStyle.alignment = .left

                    if paragraphText.string.hasPrefix("*") {
                        // Render an empty spacer line
                        // Set the spacer line paragraph style
                        paragraphStyle.paragraphSpacing = 0.0
                        paragraphStyle.headIndent = inset

                        // Add a fixed-text paragraph, then apply the spacer paragraph style
                        paragraphText = NSMutableAttributedString(string: BUFFOON_CONSTANTS.COLLECTION_SPACER, attributes: self.lineAttributes)
                    } else {
                        // Define a text paragraph style that's indented
                        paragraphStyle.headIndent = inset + paragraph.keyLength

                        // Add a paragraph terminator, then apply the text paragraph style
                        paragraphText.append(self.cr)
                    }

                    // Add the paragraph attributed string to the main store
                    paragraphText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphText.length))
                    renderString.append(paragraphText)
                }
            }
        }

        // Hand back the rendered JSON
        return renderString as NSAttributedString
    }


    /**
     Return a space-prefix NSAttributedString formed from an image in the app Bundle

     - Parameters:
        - indent:     The number of indent spaces to add.
        - imageName:  The name of the image to load and insert.
     
     - Returns: The indented string as an optional NSAttributedString. Nil indicates an error
     */
    private func getImageString(_ imageName: String) -> NSAttributedString? {

        let insetImage: NSTextAttachment = NSTextAttachment()
        insetImage.image = NSImage(named: imageName)
        guard let image = insetImage.image else {
            return nil
        }

        image.size = NSMakeSize(image.size.width * self.settings.fontSize / image.size.height, self.settings.fontSize)
        let imageAsString = NSMutableAttributedString(string: " ")
        imageAsString.append(NSMutableAttributedString(attachment: insetImage))
        imageAsString.addAttributes(self.scalarAttributes, range: NSRange(location: 0, length: imageAsString.length))
        return imageAsString
    }
    

    /**
     Assemble an ordered sequence of Paragraphs from a JSON entity.

     FROM 2.0.0

     - Parameters
        - json:       A JSON entity, which may be incomplete.
        - depth:      The level at which the entity is nested.
        - prefix:     Any text to which the rendered JSON entity should be appended.
        - paragraphs: The array of paragraphs to which the generated one will be added.
        - marker:     A key-assigned JSON marker type.
     */

    private func prettify(_ json: JSONValue, _ depth: Int = 0, _ prefix: NSMutableAttributedString, _ paragraphs: NSMutableArray, _ marker: JSONMarkType = .none) {

        // Get the point size of the rendered key if there is one
        let keyLength = prefix.length > 0 ? prefix.width : 0.0

        // Match the JSON entity by type to generate paragraph styled text
        if json.objectValue != nil {
            // For an object (dictionary), enumerate the keys and their values
            for (index, keyValuePair) in json.objectValue!.enumerated() {
                let key = keyValuePair.0
                let value = keyValuePair.1

                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool  = value.arrayValue != nil

                // First, render the key
                let keyString = NSMutableAttributedString(string: key.description + " ", attributes: self.keyAttributes)
                let keyLength = keyString.width

                // Set the JSON marker type
                var marker: JSONMarkType = .none
                if index == 0 {
                    // First value in the list
                    marker = .objectOpen
                } else if index == json.objectValue!.count - 1 {
                    // Last value in the list
                    marker = .objectClose
                }

                // Now render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    marker = valueIsArray ? .arrayOpen : .objectOpen
                    paragraphs.add(Paragraph(text: keyString, depth: depth, keyLength: keyLength, marker: marker))
                    prettify(value, depth + 1, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)
                } else {
                    // The value is a scalar
                    // NOTE The key has a trailing space, so no extra indent is required for the scalar value
                    prettify(value, depth, keyString, paragraphs, marker)
                }
            }

            return
        } else if json.arrayValue != nil {
            // For aan array, enumerate the values
            // NOTE Should be only one of each, but value may be an object or array
            for (index, value) in json.arrayValue!.enumerated() {
                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool = value.arrayValue != nil

                // Set the JSON marker type
                var marker: JSONMarkType = .none
                if index == 0 {
                    marker = .arrayOpen
                } else if index == json.arrayValue!.count - 1 {
                    marker = .arrayClose
                }

                // Render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    marker = valueIsArray ? .arrayOpen : .objectOpen
                    if prefix.length > 0 {
                        paragraphs.add(Paragraph(text: prefix, depth: depth, marker: marker))
                    }

                    prettify(value, depth + 1, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)

                    // Grab the most tail-end paragraph and add a close marker
                    let lastPara = paragraphs.lastObject as! Paragraph
                    lastPara.marker = valueIsArray ? .arrayClose : .objectClose
                } else {
                    // The value is a scalar
                    prettify(value, depth, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs, marker)
                }

                // Add a narrow spacer line after all collections except the last one in the array
                if index < json.arrayValue!.count - 1 && (valueIsArray || valueIsObject) {
                    paragraphs.add(Paragraph(text: self.emptyString, depth: depth))
                }
            }

            return
        } else if json.isNull {
            // Attempt to load the `NULL` symbol, but use a text version as a fallback on error
            if !self.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let imageName: String = "null_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    prefix.append(image)
                }
            } else {
                // Can't or won't show an image? Show text
                prefix.append(NSAttributedString(string: "NULL", attributes: self.specialAttributes))
            }
        } else if json.boolValue != nil {
            // Attempt to load the `TRUE`/`FALSE` symbol, but use a text version as a fallback on error
            if !self.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let boolType: String = json.boolValue! ? "true" : "false"
                let imageName: String = "\(boolType)_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    prefix.append(image)
                }
            } else {
                // Can't or won't show an image? Show text
                prefix.append(NSAttributedString(string: json.boolValue!.description.uppercased(), attributes: self.specialAttributes))
            }
        } else if json.numberValue != nil {
            // Display the number as is
            prefix.append(NSAttributedString(string: "\(json.numberValue!.description)", attributes: self.scalarAttributes))
        } else if json.stringValue != nil {
            // Display the string with quotemarks if the user wants to see markers
            let value: String = json.stringValue!.description
            let valueString: String = self.settings.showJsonMarks ? "“" + value + "”" : value
            prefix.append(NSAttributedString(string: valueString, attributes: self.stringAttributes))
        }

        // Stash the paragraph
        paragraphs.add(Paragraph(text: prefix, depth: depth, keyLength: keyLength, marker: marker))
    }


    /**
     Render a unit of JSON as an NSAttributedString using Tabulation.
     FROM 1.1.1

     - Parameters:
        - json:           A unit of JSON, type Any.
        - currentLevel:   The current element depth.
        - currentIndent:  How much a subsequent value should be indented.
        - parentIsObject: If and only if the parent is an object.

     - Returns: The indented string as an NSAttributedString.

    private func tabulate(_ json: Any, _ currentLevel: Int = 0, _ currentIndent: Int = 0, _ parentIsObject: Bool = false) -> NSMutableAttributedString {

        // Prep an NSMutableAttributedString for this JSON segment
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.keyAttributes)

        // Generate a string according to the JSON element's underlying type
        // Booleans are 'Bool' and 'Int', so remove the old bool check
        // and rely on the earlier string encoding in PreviewViewController
        if json is NSNull {
            // Attempt to load the null symbol, but use a text version as a fallback on error
            if self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                // Display NULL as an image
                let name: String = "null_\(self.settings.boolStyle)"
                if !self.isThumbnail, let addString: NSAttributedString = getImageString(currentIndent, name) {
                    renderedString.append(addString)
                    return renderedString
                }
            }

            // Can't or won't show an image? Show text
#if DEBUG
            renderedString.append(getIndentedAttributedString("NULL", currentIndent, .Special))
            renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
            renderedString.append(getIndentedAttributedString("NULL\n", currentIndent, .Special))
#endif
        } else if json is Int || json is Float || json is Double {
            // Display the number as is
#if DEBUG2
            renderedString.append(getIndentedAttributedString("\(json)", currentIndent, .Scalar))
            renderedString.append(getIndentedAttributedString(" \(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
            renderedString.append(getIndentedAttributedString("\(json)\n", currentIndent, .Scalar))
#endif
        } else if json is String {
            let value: String = json as! String

            // Is this a shimmed boolean?
            if value == "PREVIEW-JSON-TRUE" || value == "PREVIEW-JSON-FALSE" {
                if self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                    // Render the bool as an image
                    let name: String = value == "PREVIEW-JSON-TRUE" ? "true_\(self.settings.boolStyle)" : "false_\(self.settings.boolStyle)"
                    if !self.isThumbnail, let addString: NSAttributedString = getImageString(currentIndent, name) {
                        renderedString.append(addString)
                        return renderedString
                    }
                }

                // Can't or won't show an image? Show text
#if DEBUG2
                renderedString.append(getIndentedAttributedString(value == "PREVIEW-JSON-TRUE" ? "TRUE" : "FALSE", currentIndent, .Special))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
                renderedString.append(getIndentedAttributedString(value == "PREVIEW-JSON-TRUE" ? "TRUE\n" : "FALSE\n", currentIndent, .Special))
#endif
            } else {
                // Regular string value; add quotes if necessary
#if DEBUG2
                let stringText: String = self.doShowFurniture ? "“" + (json as! String) + "”" : (json as! String)
                renderedString.append(getIndentedAttributedString(stringText[...], currentIndent, .String))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
                let stringText: String = self.settings.showJsonMarks ? "“" + (json as! String) + "”\n" : (json as! String) //+ "\n"
                renderedString.append(getIndentedAttributedString(stringText[...], currentIndent, .String))
#endif
            }
        } else if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            // NOTE Should be only one of each, but value may
            //      be an object or array

            if self.settings.showJsonMarks {
                // Add JSON furniture
                // If the parent is an object too, don't indent (we have already indented)
                let initialIndent: Int = parentIsObject ? 0 : currentIndent
#if DEBUG2
                renderedString.append(getIndentedAttributedString("{", initialIndent, .MarkStart))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)/\(initialIndent)\n", 1, .Debug))
#else
                renderedString.append(getIndentedAttributedString("{\n", initialIndent, .MarkStart))
#endif
            }

            let anyObject: [String: Any] = json as! [String: Any]

            // FROM 1.1.0 -- sort dictionaries alphabetically by key
            var keys: [String] = Array(anyObject.keys)
            if self.sortKeys {
                keys = keys.sorted(by: { (a, b) -> Bool in
                    return (a.lowercased() < b.lowercased())
                })
            }

            // Indent slightly
            let keyIndent: Int = self.settings.showJsonMarks ? currentIndent + BUFFOON_CONSTANTS.TABBED_INDENT : currentIndent
            for key in keys {
                // Get important value types
                let value: Any = anyObject[key]!
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool  = (value is Array<Any>)

                // Print the key
                renderedString.append(getIndentedAttributedString(key[...], keyIndent, .Key))
                // Space after
                renderedString.append(NSAttributedString(string: String(repeating: self.spacer, count: self.maxKeyLengths[currentLevel] - key.count + 1), attributes: getAttributes(.Key)))

                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element at the next level
                    let nextIndent: Int = keyIndent + self.maxKeyLengths[currentLevel] + 1
                    if !self.settings.showJsonMarks {
                        renderedString.append(self.cr)
                    }

                    renderedString.append(tabulate(value,
                                                   currentLevel + (valueIsObject ? 1 : 0),      // Next level
                                                   nextIndent,                                  // This level's base indent
                                                   true))
                } else {
                    renderedString.append(tabulate(value,
                                                   currentLevel,                   // Same level
                                                   0))
                }
            }

            if self.settings.showJsonMarks {
                // Bookend with JSON furniture
#if DEBUG2
                renderedString.append(getIndentedAttributedString("}", currentIndent, .MarkEnd))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
                renderedString.append(getIndentedAttributedString("}\n", currentIndent, .MarkEnd))
#endif
            }
        } else if json is Array<Any> {
            if self.settings.showJsonMarks {
                // Add JSON furniture
                // NOTE Parent is an object, so add furniture after key
                let initialIndent: Int = parentIsObject ? 0 : currentIndent

#if DEBUG2
                renderedString.append(getIndentedAttributedString("[", initialIndent, .MarkStart))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)/\(initialIndent)\n", 1, .Debug))
#else
                renderedString.append(getIndentedAttributedString("[\n", initialIndent, .MarkStart))
#endif
            }

            // Iterate over the array's items
            // Array items are always rendered at the same level
            let anyArray: [Any] = json as! [Any]
            var count: Int = 0
            anyArray.forEach { value in
                // Get important value types
                let valueIsObject: Bool = (value is Dictionary<String, Any>)
                let valueIsArray: Bool = (value is Array<Any>)
                let nextIndent: Int = self.settings.showJsonMarks ? currentIndent + BUFFOON_CONSTANTS.TABBED_INDENT : currentIndent

                // Is the value non-scalar?
                if valueIsObject || valueIsArray {
                    // Render the element on the next level
                    renderedString.append(tabulate(value,
                                                   currentLevel + (valueIsObject ? 1 : 0),
                                                   nextIndent))

                    // Separate all but the last item with a blank line
                    if count < anyArray.count - 1 && !self.settings.showJsonMarks {
                        renderedString.append(self.cr)
                    }
                } else {
                    // Render the scalar value
                    renderedString.append(tabulate(value,
                                                   0,
                                                   nextIndent))
                }

                count += 1
            }

            if self.settings.showJsonMarks {
                // Bookend with JSON furniture
#if DEBUG2
                renderedString.append(getIndentedAttributedString("]", currentIndent, .MarkEnd))
                renderedString.append(getIndentedAttributedString("\(currentLevel)/\(currentIndent)\n", 1, .Debug))
#else
                renderedString.append(getIndentedAttributedString("]\n", currentIndent, .MarkEnd))
#endif
            }
        }

        return renderedString
    }
     */
    

    /**
     Iterate through a JSON element to caclulate the current max. key length.
     FROM 1.1.0

     - Parameters:
        - json:     The JSON element.
        - level:    The current level.
     */
    private func assembleColumns(_ json: Any, _ level: Int = 0) {

        // FROM 1.1.1
        if level > (self.maxKeyLengths.count - 1) {
            let count = level - self.maxKeyLengths.count + 1
            for _ in 0...count {
                self.maxKeyLengths.append(0)
            }
        }
         
        if json is Dictionary<String, Any> {
            // For a dictionary, enumerate the key and value
            let anyObject: [String: Any] = json as! [String: Any]
            
            // Get the max key length for the current level
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
                    // Process object values on the next level,
                    // but array values on the same level
                    assembleColumns(value, level + (valueIsObject ? 1 : 0))
                }
            }
        } else if json is Array<Any> {
            // For an array, enumerate the elements
            let anyArray: [Any] = json as! [Any]
            anyArray.forEach { value in
                let valueIsObject: Bool = value is Dictionary<String, Any>
                let valueIsArray: Bool = value is Array<Any>
                
                if valueIsObject || valueIsArray {
                    // Process container - objects or array - values on the next level
                    assembleColumns(value, level + (valueIsObject ? 1 : 0))
                }
            }
        }
    }


    /**
     Determine whether the host Mac is in light mode.
     FROM 1.1.0

     - Returns: `true` if the Mac is in light mode, otherwise `false`.
     */
    internal func isMacInLightMode() -> Bool {

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
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: nil,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


