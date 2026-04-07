/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit


final class Common {

    // MARK: - Definitions

    /* String attribute categories

     UNUSED FROM 2.0.0
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
     */


    // MARK: - Public Properties

    public var doShowLightBackground: Bool          = false
    // FROM 2.0.0
    public var settings: PJSettings                 = PJSettings()
    public var tableWidth: CGFloat                  = 384.0


    // MARK: - Private Properties

    private var hr: NSMutableAttributedString                       = NSMutableAttributedString(string: "")
    private let cr: NSMutableAttributedString                       = NSMutableAttributedString(string: BUFFOON_CONSTANTS.CR)
    // FROM 2.0.0
    private var emptyString: NSMutableAttributedString              = NSMutableAttributedString(string: "*")
    private var maxDepth: Int                                       = 0

    // JSON string attributes...
    private var keyAttributes: [NSAttributedString.Key: Any]        = [:]
    private var scalarAttributes: [NSAttributedString.Key: Any]     = [:]
    private var markAttributes: [NSAttributedString.Key: Any]       = [:]
    private var stringAttributes: [NSAttributedString.Key: Any]     = [:]
    private var specialAttributes: [NSAttributedString.Key: Any]    = [:]
    private var lineAttributes: [NSAttributedString.Key: Any]       = [:]

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions

    init(forThumbnail isThumbnail: Bool) {

        self.settings.loadSettings(self.appSuiteName)
        self.settings.isThumbnail = isThumbnail

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
        self.keyAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.KEYS),
            .font: font
        ]

        self.scalarAttributes = [
            .foregroundColor: (useLightMode ? NSColor.black : NSColor.labelColor),
            .font: font
        ]

        self.markAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.MARKS),
            .font: font
        ]

        self.stringAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.STRINGS),
            .font: font
        ]

        self.specialAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.SPECIALS),
            .font: font
        ]

        // FRON 1.1.0
        self.lineAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 6.0)
        ]

        self.cr.setAttributes(self.scalarAttributes, range: NSRange(location: 0, length: self.cr.length))

        // FROM 2.0.0
        // New, TextKit 2-friendly horizontal rule
        let hrTable = NSTextTable()
        hrTable.numberOfColumns = 1
        let hrBlock = NSTextTableBlock(table: hrTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        hrBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxY)
        hrBlock.setBorderColor(NSApplication.shared.inLightMode ? NSColor.hexToColour("eeeeeeff") : NSColor.hexToColour("222222ff"))
        let hrParaStyle = NSMutableParagraphStyle()
        hrParaStyle.alignment = .center
        hrParaStyle.textBlocks = [hrBlock]
        let hrFont = font
        self.hr = NSMutableAttributedString(string: BUFFOON_CONSTANTS.CR,
                                            attributes: [.foregroundColor: NSColor.labelColor,
                                                         .paragraphStyle: hrParaStyle,
                                                         .font: hrFont])
    }


    /**
     Update certain style variables on a UI mode switch.
     FROM 1.1.0

     THIS IS USED SOLELY BY THE RENDER DEMO APP.
     */
    func resetStylesOnModeChange() {

        // Set up the attributed string components we may use during rendering
        self.scalarAttributes[.foregroundColor]  = self.doShowLightBackground ? NSColor.black : NSColor.labelColor
    }


    // MARK: - The Primary Functions

    /**
     Standalone thumbnail generator.

     - NOTE This is a separate function while `QLThumbnailProvider.provideThumbnail()`
            does not support Swift Concurrency.

     - Parameters:
        - json: The loaded JSON data as a string.

     - Returns: The rendered JSON as an attributed string.
     */
    public func getThumbnailString(fromJson json: String) -> NSAttributedString {

        // Parse the JSON data, bailing if this fails
        let renderedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        guard let json = parse(string: json)else {
            return renderedString
        }

        // Assemble the paragraphs (rows) to be rendered
        let thumbnailParagraphs = NSMutableArray()
        prettify(json, 0, nil, thumbnailParagraphs)

        // Generate the attributed string from the paras
        for i in 0..<thumbnailParagraphs.count {
            let paragraph = thumbnailParagraphs.object(at: i) as! Paragraph
            if var paragraphText = paragraph.text {
                let inset: CGFloat = CGFloat(paragraph.depth) * BUFFOON_CONSTANTS.BASE_TAB_SIZE_PT

                if paragraphText.length > 0 {
                    // Instantiate a generic paragraph style
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.firstLineHeadIndent = inset
                    paragraphStyle.alignment = .left
                    paragraphStyle.paragraphSpacing = self.settings.fontSize * BUFFOON_CONSTANTS.BASE_PARA_SPACING_PT

                    if paragraphText.string.hasPrefix("*") {
                        // Add a fixed-text paragraph, then apply the spacer paragraph style
                        paragraphText = NSMutableAttributedString(string: BUFFOON_CONSTANTS.COLLECTION_SPACER, attributes: self.lineAttributes)
                        paragraphStyle.paragraphSpacing = 0.0
                        paragraphStyle.headIndent = inset
                    } else {
                        // Add a paragraph terminator, then apply the text paragraph style
                        paragraphText.append(self.cr)
                        paragraphStyle.headIndent = inset + paragraph.keyLength
                    }

                    // Add the paragraph attributed string to the main store
                    paragraphText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphText.length))
                    renderedString.append(paragraphText)
                }
            }
        }

        return renderedString as NSAttributedString
    }


    /**
     Entry point for preview and thumbnail generation. Converts a JSON string onto a
     styled NSAttributedString.

     REDESIGNED 2.0.0

     - NOTE This should be the main entry point for all rendering (see `getThumbnailString()`).

     - Parameters:
        - fromJson: The JSON to render.

     - Returns: The rendered JSON as an attributed string.
     */
    public func getPreviewString(fromJson json: String) async -> NSAttributedString {

        // Just in case...
        if self.settings.isThumbnail {
            return getThumbnailString(fromJson: json)
        }

        // Parse the JSON data, bailing if this fails
        guard let json = parse(string: json) else {
            return NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        }

        // Render the preview by the chosen indentation/tabulation
        if (self.settings.indentSize == BUFFOON_CONSTANTS.TABULATION_INDENT_VALUE) {
            return tabulate(json) as NSAttributedString
        } else {
            return indent(json) as NSAttributedString
        }
    }


    // MARK: - Indentation Functions

    /**
     Process and render JSON in indented style.

     - FROM 2.0.0

     - Parameters:
        - json: A JSON entity to render.

     - Returns: An attributed string.
     */
    private func indent(_ json: JSONValue) -> NSMutableAttributedString {

        // Assemble the paragraphs (rows) to be rendered
        let previewParagraphs = NSMutableArray()
        prettify(json, 0, nil, previewParagraphs)

        // Generate the attributed string from the para
        let renderedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        for i in 0..<previewParagraphs.count {
            let paragraph = previewParagraphs.object(at: i) as! Paragraph
            if var paragraphText = paragraph.text {
                let inset: CGFloat = CGFloat(paragraph.depth) * BUFFOON_CONSTANTS.BASE_TAB_SIZE_PT * CGFloat(self.settings.indentSize)

                if paragraphText.length > 0 {
                    // Instantiate a generic paragraph style
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = self.settings.fontSize * BUFFOON_CONSTANTS.BASE_PARA_SPACING_PT
                    paragraphStyle.firstLineHeadIndent = inset
                    paragraphStyle.headIndent = inset
                    paragraphStyle.alignment = .left

                    if paragraphText.string.hasPrefix("*") {
                        // Add a fixed-text paragraph, then apply the spacer paragraph style
                        paragraphText = NSMutableAttributedString(string: BUFFOON_CONSTANTS.COLLECTION_SPACER, attributes: self.scalarAttributes)
                        paragraphStyle.paragraphSpacing = 0.0
                    } else {
                        // Add a paragraph terminator, then apply the text paragraph style
                        paragraphText.append(self.cr)
                        paragraphStyle.headIndent += paragraph.keyLength
                    }

                    // Add the paragraph attributed string to the main store
                    paragraphText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphText.length))
                    renderedString.append(paragraphText)
                }
            }
        }

        return renderedString
    }


    /**
     Assemble an ordered sequence of Paragraphs from a JSON entity.

     UPDATED 2.0.0

     - Parameters
        - json:       A JSON entity, which may be incomplete.
        - depth:      The level at which the entity is nested.
        - prefix:     Any text to which the rendered JSON entity should be appended.
        - paragraphs: The array of paragraphs to which the generated one will be added.
     */
    private func prettify(_ json: JSONValue, _ depth: Int = 0, _ prefix: NSMutableAttributedString?, _ paragraphs: NSMutableArray) {

        // Get the point size of the rendered key if there is one
        let thePrefix = prefix ?? NSMutableAttributedString(string: "", attributes: self.markAttributes)
        let showMarks = self.settings.showJsonMarks
        var inset = depth

        // Match the JSON entity by type to generate paragraph styled text
        if json.objectValue != nil {
            if showMarks {
                // Start of an object, so mark open on a fresh line
                let markString = NSMutableAttributedString(string: "{", attributes: self.markAttributes)
                paragraphs.add(Paragraph(text: markString, depth: inset, keyLength: 0.0))

                // And show collection's contents on next column
                inset += 1
            }

            // For an object (dictionary), enumerate the keys and their values
            for (key, value) in json.objectValue! {
                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool  = value.arrayValue != nil

                // First, render the key plus a separator
                let keyString = NSMutableAttributedString(string: key.description + " ", attributes: self.keyAttributes)

                // Now render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    paragraphs.add(Paragraph(text: keyString, depth: inset, keyLength: keyString.width))
                    prettify(value, (showMarks ? inset : inset + 1), NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)
                } else {
                    // The value is a scalar
                    // NOTE The key has a trailing space, so no extra indent is required for the scalar value
                    prettify(value, inset, keyString, paragraphs)
                }
            }

            if showMarks {
                // Start of an object, so mark open on a fresh line
                let markString = NSMutableAttributedString(string: "}", attributes: self.markAttributes)
                paragraphs.add(Paragraph(text: markString, depth: inset - 1 , keyLength: 0.0))
            }

            return
        } else if json.arrayValue != nil {
            if showMarks {
                // Start of an object, so mark open on a fresh line
                let markString = NSMutableAttributedString(string: "[", attributes: self.markAttributes)
                paragraphs.add(Paragraph(text: markString, depth: inset, keyLength: 0.0))

                // Show array contents on next column
                inset += 1
            }

            // For an array, enumerate the values
            // NOTE Should be only one of each, but value may be an object or array
            for (index, value) in json.arrayValue!.enumerated() {
                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool = value.arrayValue != nil

                // Render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    if thePrefix.length > 0 {
                        paragraphs.add(Paragraph(text: prefix, depth: inset))
                    }

                    prettify(value, (showMarks ? inset + 1 : inset), NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)
                } else {
                    // The value is a scalar
                    prettify(value, inset, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)
                }

                // Add a narrow spacer line after all collections except the last one in the array
                if index < json.arrayValue!.count - 1 && (valueIsArray || valueIsObject) {
                    paragraphs.add(Paragraph(text: self.emptyString, depth: inset))
                }
            }

            if showMarks {
                // Start of an object, so mark open on a fresh line
                let markString = NSMutableAttributedString(string: "]", attributes: self.markAttributes)
                paragraphs.add(Paragraph(text: markString, depth: inset - 1 , keyLength: 0.0))
            }

            return
        } else {
            // Process the scalar value
            let keyLength = thePrefix.length > 0 ? thePrefix.width : 0.0
            paragraphs.add(Paragraph(text: renderScalarValue(json, thePrefix), depth: depth, keyLength: keyLength))
        }
    }


    // MARK: - Tabulation Functions

    /**
     Render a JSON entity as a tabulated attributed string.

     FROM 2.0.0

     - Parameters:
        - json: The JSON entity.

     - Returns: The attributed string.
     */
    private func tabulate(_ json: JSONValue) -> NSMutableAttributedString {

        // Get each column's max width
        let colWidths = measureColumns(json, 0, [:])

        // Assemble the paragraphs (rows) to be rendered
        let previewParagraphs = NSMutableArray()
        generateTabParagraphs(json, 0, nil, previewParagraphs)

        // Determine the tabulation settings and
        // estimate the full width of the table
        var tabStops: [NSTextTab] = []
        var tabLocation: CGFloat = 0.0
        self.tableWidth = 10.0

        for i in 0...self.maxDepth {
            // Set the tabs
            let colWidth = colWidths[i] ?? 400.0
            tabLocation += (colWidth + 20.0) // Add a little extra for spacing (10.0pt either side, notionally)
            let tabStop = NSTextTab(type: .leftTabStopType, location: tabLocation)
            tabStops.append(tabStop)

            // Total the table width
            self.tableWidth += (colWidths[i]! == 0.0 ? BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT : colWidths[i]!)

        }
#if DEBUG
        print("WIDTHS: \(colWidths).\nTABLE: \(self.tableWidth)\nTABS: \(tabStops)")
#endif

        // Render the paragraphs
        let renderedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        for i in 0..<previewParagraphs.count {
            let paragraph = previewParagraphs.object(at: i) as! Paragraph
            if var paragraphText = paragraph.text, paragraphText.length > 0 {
                // Instantiate a generic paragraph style
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = self.settings.fontSize * BUFFOON_CONSTANTS.BASE_PARA_SPACING_PT
                paragraphStyle.tabStops = tabStops
                paragraphStyle.alignment = .left

                if paragraphText.string.hasPrefix("*") {
                    // Render an empty spacer line
                    paragraphText = NSMutableAttributedString(string: BUFFOON_CONSTANTS.COLLECTION_SPACER, attributes: self.scalarAttributes)
                    paragraphStyle.paragraphSpacing = 0.0
                } else {
                    // Add a paragraph terminator, then apply the text paragraph style
                    let initialTabs = NSMutableAttributedString(string: String(repeating: BUFFOON_CONSTANTS.TAB, count: paragraph.depth), attributes: self.scalarAttributes)
                    initialTabs.append(paragraphText)
                    initialTabs.append(self.cr)
                    paragraphText = initialTabs

                    // Set the column indents: the column's tab stop, and the textual
                    // backstop (20.0 points less than the next tab)
                    paragraphStyle.headIndent = tabStops[paragraph.depth].location
                    if paragraph.depth < tabStops.count - 1 {
                        paragraphStyle.tailIndent = tabStops[paragraph.depth + 1].location - 20.0
                    } else {
                        paragraphStyle.tailIndent = tabStops[paragraph.depth].location + 400.0
                    }
                }

                // Add the paragraph attributed string to the main store
                paragraphText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphText.length))
                renderedString.append(paragraphText)
            }
        }

        return renderedString
    }


    /**
     Determine the max. width of each column. We only measure key lengths, as values are expected to wrap to
     the column width, or `MAX_TAB_COL_SIZE_PT` points, whichever is greater.

     - Parameters:
        - json:  A JSON object, array or value.
        - depth: The column inset of the JSON.
        - length: A dictionary mapping column number to current max. column width.

     - Returns: An updated `length` dictionary.
     */
    private func measureColumns(_ json: JSONValue, _ depth: Int, _ lengths: [Int: CGFloat]) -> [Int: CGFloat] {

        var maxLengths = lengths
        if maxLengths[depth] == nil {
            maxLengths[depth] = 0
        }

        if depth > self.maxDepth {
            self.maxDepth = depth
        }

        // Match the JSON entity by type to generate paragraph styled text
        if json.objectValue != nil {
            for (key, value) in json.objectValue! {
                let keyString = NSMutableAttributedString(string: key.description, attributes: self.keyAttributes)
                let keyLength = keyString.width

                if keyLength > maxLengths[depth]! {
                    maxLengths[depth] = keyLength
                }

                // Get interior value column widths
                maxLengths = measureColumns(value, depth + 1, maxLengths)
            }
        } else if json.arrayValue != nil {
            for value in json.arrayValue! {
                //let nextDepth = depth == 0 ? 0 : depth + 1
                maxLengths = measureColumns(value, depth, maxLengths)
            }
        } else {
            // For scalar values, set zero as the base, so it widens to match the width
            // of keys in the same column unless the value is a string, in which case use a fixed width if it's
            // long, or the pixel-width of the rendered string
            if json.stringValue != nil {
                let value = json.stringValue!
                let valString = NSMutableAttributedString(string: value.description, attributes: self.stringAttributes)

                // Get the width of the the value string, including curly quotes if they're included
                let valWidth = valString.width + (self.settings.showJsonMarks ? NSMutableAttributedString(string: "“”", attributes: self.stringAttributes).width : 0.0)
                if valWidth > BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT {
                    // Set a max width for the column
                    maxLengths[depth] = BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT
                } else if valWidth > maxLengths[depth]! {
                    maxLengths[depth] = valWidth
                }
            } else if (json.boolValue != nil || json.isNull) && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                if maxLengths[depth]! < BUFFOON_CONSTANTS.TAB_COL_IMAGE_WIDTH_PT {
                    maxLengths[depth] = BUFFOON_CONSTANTS.TAB_COL_IMAGE_WIDTH_PT
                }
            } else if json.numberValue != nil {
                let value = json.numberValue!.description
                let valString = NSMutableAttributedString(string: value.description, attributes: self.stringAttributes)
                let valWidth = valString.width
                if valWidth > maxLengths[depth]! {
                    maxLengths[depth] = valWidth
                }
            }
        }

        return maxLengths
    }


    /**
     Assemble an ordered sequence of Paragraphs from a JSON entity.

     FROM 2.0.0

     - Parameters
        - json:       A JSON entity, which may be incomplete.
        - depth:      The level at which the entity is nested.
        - prefix:     Any (optional) text to which the rendered JSON entity should be appended.
        - paragraphs: The array of paragraphs to which the generated one will be added.
     */
    private func generateTabParagraphs(_ json: JSONValue, _ depth: Int = 0, _ prefix: NSMutableAttributedString?, _ paragraphs: NSMutableArray) {

        // Get the point size of the rendered key if there is one
        let thePrefix = prefix ?? NSMutableAttributedString(string: "", attributes: self.scalarAttributes)

        // Match the JSON entity by type to generate paragraph styled text
        if json.objectValue != nil {
            // For an object (dictionary), enumerate the keys and their values
            for (key, value) in json.objectValue! {
                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool  = value.arrayValue != nil

                // First, render the key
                let followingChar = !valueIsObject && !valueIsArray ? BUFFOON_CONSTANTS.TAB : " "
                let keyString = NSMutableAttributedString(string: key.description + followingChar, attributes: self.keyAttributes)

                // Now render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type: start it on a new line, ie. in a new paragraph (so no prefix)
                    paragraphs.add(Paragraph(text: keyString, depth: depth, keyLength: keyString.width))
                    generateTabParagraphs(value, depth + 1, nil, paragraphs)
                } else {
                    // The value is a scalar
                    // NOTE The key has a trailing space, so no extra indent is required for the scalar value
                    generateTabParagraphs(value, depth, keyString, paragraphs)
                }
            }

            return
        } else if json.arrayValue != nil {
            // For an array, enumerate the values
            // NOTE Should be only one of each, but value may be an object or array
            for (index, value) in json.arrayValue!.enumerated() {
                // Is the value a collection?
                let valueIsObject: Bool = value.objectValue != nil
                let valueIsArray: Bool = value.arrayValue != nil

                // Render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    if thePrefix.length > 0 {
                        paragraphs.add(Paragraph(text: prefix, depth: depth))
                    }
                }

                generateTabParagraphs(value, depth, nil, paragraphs)

                // Add a narrow spacer line after all collections except the last one in the array
                if index < json.arrayValue!.count - 1 && (valueIsArray || valueIsObject) {
                    paragraphs.add(Paragraph(text: self.emptyString, depth: depth))
                }
            }

            return
        } else {
            // Process the scalar value
            let keyLength = thePrefix.length > 0 ? thePrefix.width : 0.0
            paragraphs.add(Paragraph(text: renderScalarValue(json, thePrefix), depth: depth, keyLength: keyLength))
        }
    }


    // MARK: - Common Functions

    /**
     Render a JSON scalar value as an attributed string.

     FROM: 2.0.0

     - Parameters:
        - scalar: The scalar JSON value.
        - prefix: Any existing string (eg. a rendered key) we need to include.

     - Returns: Any prefix plus the scalar value as an attributed string.
     */
    private func renderScalarValue(_ scalar: JSONValue, _ prefix: NSMutableAttributedString? = nil) -> NSMutableAttributedString {

        let renderedString = prefix ?? NSMutableAttributedString(string: "", attributes: self.scalarAttributes)

        if scalar.isNull {
            // Attempt to load the `NULL` symbol, but use a text version as a fallback on error
            if !self.settings.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let imageName: String = "null_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    renderedString.append(image)
                }
            } else {
                // Can't or won't show an image? Show text
                renderedString.append(NSAttributedString(string: "NULL", attributes: self.specialAttributes))
            }
        } else if scalar.boolValue != nil {
            // Attempt to load the `TRUE`/`FALSE` symbol, but use a text version as a fallback on error
            if !self.settings.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let boolType: String = scalar.boolValue! ? "true" : "false"
                let imageName: String = "\(boolType)_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    renderedString.append(image)
                }
            } else {
                // Can't or won't show an image? Show text
                renderedString.append(NSAttributedString(string: scalar.boolValue!.description, attributes: self.specialAttributes))
            }
        } else if scalar.numberValue != nil {
            // Display the number as is
            renderedString.append(NSAttributedString(string: "\(scalar.numberValue!.description)", attributes: self.scalarAttributes))
        } else if scalar.stringValue != nil {
            // Display the string with quotemarks if the user wants to see markers
            let value: String = scalar.stringValue!.description
            let valueString: String = self.settings.showJsonMarks ? "“" + value + "”" : value
            renderedString.append(NSAttributedString(string: valueString, attributes: self.stringAttributes))
        }

        return renderedString
    }


    /**
     Return a space-prefix NSAttributedString formed from an image in the app Bundle

     - Parameters:
        - indent:     The number of indent spaces to add.
        - imageName:  The name of the image to load and insert.

     - Returns: The indented string as an optional NSAttributedString. Nil indicates an error
     */
    private func getImageString(_ imageName: String) -> NSAttributedString? {

        // Get the image
        let insetImage: NSTextAttachment = NSTextAttachment()
        insetImage.image = NSImage(named: imageName)
        guard let image = insetImage.image else {
            return nil
        }

        // Size the font to fit and shift it to the text cap height (ie. more centred)
        image.size = NSMakeSize(image.size.width * self.settings.fontSize / image.size.height, self.settings.fontSize)
        let font = self.scalarAttributes[.font] as! NSFont
        insetImage.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height).rounded() / 2, width: image.size.width, height: image.size.height)

        // Add the attachment and return the attributed string
        let imageAsString = NSMutableAttributedString(string: " ")
        imageAsString.append(NSMutableAttributedString(attachment: insetImage))
        imageAsString.addAttributes(self.scalarAttributes, range: NSRange(location: 0, length: imageAsString.length))
        return imageAsString
    }


    // MARK: - JSON Parsing Functions

    /**
     Convert the specified JSON string to a structured JSON entity.


     */
    private func parse(string json: String) -> JSONValue? {

        var parser = JSONParser(json)
        return parser.parseValue()
    }

}
