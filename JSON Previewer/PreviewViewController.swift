/*
 *  PreviewViewController.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Cocoa
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {
    
    
    // MARK: - Class UI Properties

    @IBOutlet weak var renderTextView: NSTextView!
    @IBOutlet weak var renderTextScrollView: NSScrollView!

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK: - QLPreviewingController Required Functions

    // FROM 2.0.0
    // Update to use Swift Concurrency
    func preparePreviewOfFile(at url: URL) async throws {

        /*
         * Main entry point for the macOS preview system
         * FROM 2.0.0 -- Use the Swift Concurrency version
         */
        
        // Get an error message ready for use
        var reportError: NSError? = nil
        
        // Show the
        self.renderTextScrollView.isHidden = false

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        do {
            // Get the file contents as a string
            let data: Data = try Data(contentsOf: url, options: [.uncached])
            let encoding: String.Encoding = data.stringEncoding ?? .utf8

            if let jsonString: String = String(data: data, encoding: encoding) {
                // Instantiate the common renderer
                let common: Common = Common(forThumbnail: false)

                // FROM 2.0.0
                // Set the parent window's size
                setPreviewWindowSize(common.settings)

                // FROM 2.0.0
                // The force-light-mode-preview-in-dark-mode setting is now a general
                // preview-colours-should-be-opposite-the-mode setting.
                var renderPreviewLight = NSApplication.shared.inLightMode
                if common.settings.doReverseMode {
                    // Invert the colour scheme based on the current mode
                    renderPreviewLight = !renderPreviewLight
                }

                // Set the view's mode
                self.view.appearance = renderPreviewLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)

                // Update the NSTextView
                self.renderTextView.backgroundColor = renderPreviewLight ? NSColor.white : NSColor.textBackgroundColor
                self.renderTextScrollView.scrollerKnobStyle = renderPreviewLight ? .dark : .light

                // FROM 2.0.0
                // Add margin if required
                if common.settings.previewMarginWidth > 0.0 {
                    let previewSize = NSSize(width: common.settings.previewMarginWidth, height: common.settings.previewMarginWidth)
                    self.renderTextView.textContainerInset = previewSize
                }

                // Get the preview string
                var jsonAttString: NSAttributedString = await common.getPreviewString(fromJson: jsonString)
                if jsonAttString.length == 0 && common.settings.showRawJsonOnError {
                    jsonAttString = await common.getPreviewString(fromJson: "{\"Could not parse the JSON\":\"\(jsonString)\"}")
                }

                // Rescale the text view to match the width of a tabluted view
                if common.tableWidth > self.renderTextView.frame.width {
                    self.renderTextView.setFrameSize(NSSize(width: common.tableWidth, height: self.renderTextView.frame.size.height))
                }

                if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                    /*
                     * NSTextStorage subclasses that return true from the fixesAttributesLazily
                     * method should avoid directly calling fixAttributes(in:) or else bracket
                     * such calls with beginEditing() and endEditing() messages.
                     */
                    renderTextStorage.beginEditing()
                    renderTextStorage.setAttributedString(jsonAttString)
                    renderTextStorage.endEditing()
                    return
                }

                // We can't access the preview NSTextView's NSTextStorage
                reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
            } else {
                // We couldn't convert to data to a valid encoding (custom error message)
                let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) unexpected encoding: \(encoding)"
                reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING,
                                      userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
        } catch {
            // We couldn't read the file so set an appropriate error to report back
            reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        // FROM 2.0.0
        // Throw to indicate an error
        throw reportError!
    }


    // MARK: - Utility Functions
    
    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func makeError(_ code: Int) -> NSError {

        var errDesc: String
        
        switch(code) {
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING
        default:
            errDesc = "UNKNOWN ERROR"
        }

        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }


    /**
     Specify the content size of the parent view.
    */
    private func setPreviewWindowSize(_ settings: PJSettings) {

        var screen: NSScreen = NSScreen.screens[0]

        // We've set `screen` to the primary, ie. menubar-displaying,
        // screen, but ideally we should pick the screen with user focus.
        // They may be one and the same, of course...
        if let mainScreen = NSScreen.main, mainScreen != screen {
            screen = mainScreen
        }

        let height: CGFloat = screen.frame.size.height * settings.previewWindowScale
        let width: CGFloat = screen.frame.size.width * settings.previewWindowScale
        self.preferredContentSize = NSSize(width: width, height: height)
    }

}
