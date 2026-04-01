/*
 *  Common.swift
 *  PreviewJson
 *  Code common to Json Previewer and Json Thumbnailer
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation
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
    
    private var isThumbnail: Bool                                   = false
    private var maxKeyLengths: [Int]                                = [0,0,0,0,0,0,0,0,0,0,0,0]
    // String artifacts...
    private var hr: NSMutableAttributedString                       = NSMutableAttributedString(string: "")
    private var cr: NSMutableAttributedString                       = NSMutableAttributedString(string: "")
    // FROM 1.0.2
    private var lineCount: Int                                      = 0
    // FROM 1.1.0
    private var displayColours: [String:String]                     = [:]
    // FROM 1.1.1
    private var debugSpacer: String                                 = "."
    // FROM 2.0.0
    private var emptyString: NSMutableAttributedString              = NSMutableAttributedString(string: "*")
    private var maxColumn: Int                                      = 0

    // JSON string attributes...
    private var keyAttributes: [NSAttributedString.Key: Any]        = [:]
    private var scalarAttributes: [NSAttributedString.Key: Any]     = [:]
    private var markAttributes: [NSAttributedString.Key: Any]       = [:]
    // FROM 1.1.0
    private var stringAttributes: [NSAttributedString.Key: Any]     = [:]
    private var specialAttributes: [NSAttributedString.Key: Any]    = [:]
    // FROM 1.1.1
    private var debugAttributes: [NSAttributedString.Key: Any]      = [:]
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

#if DEBUG
        self.debugAttributes = [
            .foregroundColor: NSColor.hexToColour("444444FF"),
            .font: font
        ]
#endif


        // NOTE This no longer provides a full-width rule -- seek a fix

        self.hr = NSMutableAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (useLightMode ? NSColor.black : NSColor.white)])

        // FROM 2.0.0
        // New, TextKit 2-friendly horizontal rule
        self.cr = NSMutableAttributedString(string: BUFFOON_CONSTANTS.CR, attributes: scalarAttributes)

        // FRON 1.1.0
        self.lineAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 6.0)
        ]
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


    // MARK: - The Primary Function

    /**
     Entry point for preview and thumbnail generation. Converts a JSON string onto a
     styled NSAttributedString.

     REDESIGNED 2.0.0

     - Parameters:
        - fromJson: The JSON to render.

     - Returns: A styled attributed string.
     */
    public func getAttributedString(fromJson json: String) -> NSAttributedString {

        let renderString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)

        var parser = JSONParser(json)
        var json = parser.parseValue()
        guard json != nil else { return renderString }

        var colWidths: [Int: CGFloat] = [:]

        if (self.settings.indentSize == BUFFOON_CONSTANTS.TABULATION_INDENT_VALUE && !self.isThumbnail) {
            // Tabluation view path
            // Get each column's max width
            colWidths = measureColumns(json!, 0, colWidths)
#if DEBUG
            print("WIDTHS: \(colWidths)")
#endif
            // Get the populated cells
            let cells = NSMutableArray()
            let maxRow = tabulate(json!, 0, 0, colWidths, cells) - 1
            let maxCol = self.maxColumn
            json = nil
#if DEBUG
            print("MAX: \(maxRow + 1)x\(maxCol + 1)")
#endif

            // Calculate the width of the rendered table
            self.tableWidth = 0.0
            for i in 0...maxCol {
                // Add the column width
                self.tableWidth += ((colWidths[i] == nil || colWidths[i]! == 0.0) ? BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT : colWidths[i]!)

                // Add padding
                self.tableWidth += 10.0
            }

            // Construct the table
            let table = NSTextTable()
            table.numberOfColumns = maxCol + 1
            table.collapsesBorders = true
            table.hidesEmptyCells = false

            // Build the table
            var startCell = 0
            for r in 0...maxRow {
                var lastCellSpans = false
                for c in 0...maxCol {
                    print("\(r),\(c)")
                    var gotCell = false
                    let paraStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
                    paraStyle.alignment = .left
                    paraStyle.lineBreakMode = .byWordWrapping

                    // Don't check cells that have already been processed. We can
                    // do this because we are processing them in the order in
                    // which we added cells to the array
                    for i in startCell..<cells.count {
                        let cell = cells.object(at: i) as! Cell
                        if cell.row == r && cell.col == c {
                            autoreleasepool {
                                let cellBlock: NSTextBlock
                                let cellText: NSMutableAttributedString

                                if cell.isVal, maxCol - c > 0 {
                                    cellBlock = makeBlock(table, r, c, colWidths[c]!, maxCol - c + 1)
                                    lastCellSpans = true
                                } else {
                                    cellBlock = makeBlock(table, r, c, colWidths[c]!)
                                }

                                paraStyle.textBlocks.append(cellBlock)

                                if cell.text != nil {
                                    // Load the text from the Cell record
                                    cellText = NSMutableAttributedString(attributedString: cell.text!)
                                    cellText.append(self.cr)
                                } else {
                                    // Empty cell
                                    cellText = NSMutableAttributedString(string: "\n", attributes: self.scalarAttributes)
                                }

                                cellText.addAttributes([.paragraphStyle: paraStyle], range: NSRange(location: 0, length: cellText.length))
                                renderString.append(cellText)
                                gotCell = true
                            } // Autorelease

                            startCell += 1
                            break
                        }
                    }

                    // No cell at current row,col, so add one if it's not hidden by a span
                    if !gotCell && !lastCellSpans {
                        let cellText = NSMutableAttributedString(string: "\n", attributes: self.scalarAttributes)
                        paraStyle.textBlocks.append(makeBlock(table, r, c, colWidths[c]!))
                        cellText.addAttributes([.paragraphStyle: paraStyle], range: NSRange(location: 0, length: cellText.length))
                        renderString.append(cellText)
                    }
                }
            }
        } else {
            // Convert the JSON string into JSON entities, then convert them
            // into a series of paragraph objects
            let previewParagraphs = NSMutableArray()
            prettify(json!, 0, NSMutableAttributedString(string: "", attributes: self.scalarAttributes), previewParagraphs)
            json = nil

            // Assemble the final attributed string
            // NOTE Do with an autorelease pool?
            for i in 0..<previewParagraphs.count {
                let paragraph = previewParagraphs.object(at: i) as! Paragraph
                if var paragraphText = paragraph.text {
                    let inset: CGFloat = CGFloat(paragraph.depth) * BUFFOON_CONSTANTS.BASE_TAB_SIZE_PT * CGFloat(self.settings.indentSize)

                    if paragraphText.length > 0 {
                        // Instantiate a generic paragraph style
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.firstLineHeadIndent = inset
                        paragraphStyle.alignment = .left
                        paragraphStyle.paragraphSpacing = self.settings.fontSize * BUFFOON_CONSTANTS.BASE_PARA_SPACING_PT

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
        }

        // Hand back the rendered JSON
        return renderString as NSAttributedString
    }


    func makeBlock(_ table: NSTextTable, _ row: Int, _ col: Int, _ minWidth: CGFloat, _ span: Int = 1) -> NSTextTableBlock {

        let block: NSTextTableBlock = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: span)
        block.setValue(minWidth, type: .absoluteValueType, for: .minimumWidth)
        block.setValue(minWidth, type: .absoluteValueType, for: .width)
        block.setValue(minWidth, type: .absoluteValueType, for: .maximumWidth)
        block.setWidth(5.0, type: .absoluteValueType, for: .padding)

        //block.setWidth(0.5, type: .absoluteValueType, for: .border)
        //block.setBorderColor(.labelColor)
        return block
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


    /**
     Assemble an ordered sequence of Paragraphs from a JSON entity.

     FROM 2.0.0

     - Parameters
        - json:       A JSON entity, which may be incomplete.
        - depth:      The level at which the entity is nested.
        - prefix:     Any text to which the rendered JSON entity should be appended.
        - paragraphs: The array of paragraphs to which the generated one will be added.
     */

    private func prettify(_ json: JSONValue, _ depth: Int = 0, _ prefix: NSMutableAttributedString, _ paragraphs: NSMutableArray) {

        // Get the point size of the rendered key if there is one
        let keyLength = prefix.length > 0 ? prefix.width : 0.0

        var inset = depth
        let showMarks = self.settings.showJsonMarks

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

                // First, render the key
                let keyString = NSMutableAttributedString(string: key.description + " ", attributes: self.keyAttributes)
                let keyLength = keyString.width

                // Now render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    paragraphs.add(Paragraph(text: keyString, depth: inset, keyLength: keyLength))
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
                    if prefix.length > 0 {
                        paragraphs.add(Paragraph(text: prefix, depth: inset))
                    }

                    prettify(value, (showMarks ? inset : inset + 1), NSMutableAttributedString(string: "", attributes: self.scalarAttributes), paragraphs)
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
                prefix.append(NSAttributedString(string: json.boolValue!.description, attributes: self.specialAttributes))
            }
        } else if json.numberValue != nil {
            // Display the number as is
            prefix.append(NSAttributedString(string: "\(json.numberValue!.description)", attributes: self.scalarAttributes))
        } else if json.stringValue != nil {
            // Display the string with quotemarks if the user wants to see markers
            let value: String = json.stringValue!.description
            let valueString: String = showMarks ? "“" + value + "”" : value
            prefix.append(NSAttributedString(string: valueString, attributes: self.stringAttributes))
        }

        // Stash the paragraph
        paragraphs.add(Paragraph(text: prefix, depth: depth, keyLength: keyLength))
    }


    // MARK: - Tabulation Functions

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

        if depth > self.maxColumn {
            self.maxColumn = depth
        }

        // Match the JSON entity by type to generate paragraph styled text
        if json.objectValue != nil {
            for (key, value) in json.objectValue! {
                let keyString = NSMutableAttributedString(string: key.description, attributes: self.keyAttributes)
                let keyLength = keyString.width

                if maxLengths[depth] == nil {
                    maxLengths[depth] = keyLength
                } else if keyLength > maxLengths[depth]! {
                    maxLengths[depth] = keyLength
                }

                // Get interior value column widths
                maxLengths = measureColumns(value, depth + 1, maxLengths)
            }
        } else if json.arrayValue != nil {
            for value in json.arrayValue! {
                maxLengths = measureColumns(value, depth, maxLengths)
            }
        } else {
            // For scalar values, set zero as the base, so it widens to match the width
            // of keys in the same column...
            if maxLengths[depth] == nil {
                maxLengths[depth] = 0
            }

            // ...unless the value is a string, in which case use a fixed width if it's
            // long, or the pixel-width of the rendered string
            if json.stringValue != nil {
                let valString = NSMutableAttributedString(string: json.stringValue!.description, attributes: self.stringAttributes)
                let valLength = valString.width
                if valLength > BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT {
                    maxLengths[depth] = BUFFOON_CONSTANTS.MAX_TAB_COL_SIZE_PT
                } else if valLength > maxLengths[depth]! {
                    maxLengths[depth] = valLength
                }
            } else if (json.boolValue != nil || json.isNull) && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                if maxLengths[depth]! < BUFFOON_CONSTANTS.TAB_COL_IMAGE_WIDTH_PT {
                    maxLengths[depth] = BUFFOON_CONSTANTS.TAB_COL_IMAGE_WIDTH_PT
                }
            }
        }

        return maxLengths
    }

    /**
     Generate a Cell object for a JSON entity at given row and column co-ordinates.

     - Parameters:
        - json:      A JSON object, array or scalar value.
        - startRow:  The row on which the entity will appear.
        - startCol:  The column at which the entity is indented.
        - colWidths: A dictionary of column widths mapped to column numbers.
        - cells:     Reference to an array of Cell objects we will populate.

     - Returns: The number of rows created per call.
     */
    func tabulate(_ json: JSONValue, _ startRow: Int, _ startCol: Int, _ colWidths: [Int: CGFloat], _ cells: NSMutableArray) -> Int {

        let colWidth = colWidths[startCol] ?? 0.0
        var currentRow = startRow
        var valueString: NSAttributedString? = nil

        if json.objectValue != nil {
            // Iterate over the object's key:value pairs
            for (key, value) in json.objectValue! {
                // Add the key as a cell
                var cell = Cell()
                cell.text = NSAttributedString(string: key.description, attributes: self.keyAttributes)
                cell.row = currentRow
                cell.col = startCol
                cell.width = colWidth
                cells.add(cell)

                // Add the key's value
                currentRow += tabulate(value, currentRow, startCol + 1, colWidths, cells)
            }

            return currentRow - startRow
        } else if json.arrayValue != nil {
            // Iterate over the array's values
            for value in json.arrayValue! {
                // Add the value
                currentRow += tabulate(value, currentRow, startCol, colWidths, cells)
            }

            return currentRow - startRow
        } else if json.isNull {
            // Attempt to load the `NULL` symbol, but use a text version as a fallback on error
            if !self.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let imageName: String = "null_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    valueString = image
                }
            } else {
                // Can't or won't show an image? Show text
                valueString = NSAttributedString(string: "NULL", attributes: self.specialAttributes)
            }
        } else if json.boolValue != nil {
            // Attempt to load the `TRUE`/`FALSE` symbol, but use a text version as a fallback on error
            if !self.isThumbnail && self.settings.boolStyle != BUFFOON_CONSTANTS.BOOL_STYLE.TEXT {
                let boolType: String = json.boolValue! ? "true" : "false"
                let imageName: String = "\(boolType)_\(self.settings.boolStyle)"
                if let image: NSAttributedString = getImageString(imageName) {
                    valueString = image
                }
            } else {
                // Can't or won't show an image? Show text
                valueString = NSAttributedString(string: json.boolValue!.description, attributes: self.specialAttributes)
            }
        } else if json.numberValue != nil {
            // Display the number as is
            valueString = NSAttributedString(string: "\(json.numberValue!.description)", attributes: self.scalarAttributes)
        } else if json.stringValue != nil {
            // Display the string with quotemarks if the user wants to see markers
            let value: String = json.stringValue!.description
            valueString = NSAttributedString(string: value, attributes: self.stringAttributes)
        }

        // Add the value as a cell
        var cell = Cell()
        cell.text = valueString ?? NSAttributedString(string: "", attributes: self.scalarAttributes)
        cell.row = startRow
        cell.col = startCol
        cell.width = colWidth
        cell.isVal = true
        cells.add(cell)

        // Value count as single rows added
        return 1
    }


    // MARK: - Utility Functions

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
