/*
 *  PreviewViewController.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 29/08/2023.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Cocoa
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {
    
    
    // MARK: - Class UI Properties

    @IBOutlet var renderTextView: NSTextView!
    @IBOutlet var renderTextScrollView: NSScrollView!
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
       /*
         * Main entry point for the macOS preview system
         */
        
        // Get an error message ready for use
        var reportError: NSError? = nil
        
        // Hide the error message field
        self.renderTextScrollView.isHidden = false
        
        // Instantiate the common renderer
        let common: Common = Common.init()
        
        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        if FileManager.default.isReadableFile(atPath: url.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: url, options: [.uncached])
                let encoding: String.Encoding = data.stringEncoding ?? .utf8
                
                if let jsonString: String = String.init(data: data, encoding: encoding) {
                    // FROM 1.0.4
                    // Scan for JSON booleans and replace with a marker string.
                    // This is to deal with the issue with NSJsonSerialization which causes
                    // booleans to be replaced with 1 or 0 and therefore indistinguishable
                    // from integer 1 or 0. Maybe there is a better option?
                    let regexTrue = try! NSRegularExpression(pattern: ":[\\s]*true")
                    let jsonStringTrue: String = regexTrue.stringByReplacingMatches(in: jsonString,
                                                                                    options: [],
                                                                                    range: NSMakeRange(0, jsonString.count),
                                                                                    withTemplate: ": \"PREVIEW-JSON-TRUE\"")

                    let regexFalse = try! NSRegularExpression(pattern: ":[\\s]*false")
                    let jsonStringFalse: String = regexFalse.stringByReplacingMatches(in: jsonStringTrue,
                                                                                      options: [],
                                                                                      range: NSMakeRange(0, jsonStringTrue.count),
                                                                                      withTemplate: ": \"PREVIEW-JSON-FALSE\"")
                    
                    // Get the key string first
                    let jsonDataCoded: Data = jsonStringFalse.data(using: encoding) ?? data
                    let jsonAttString: NSAttributedString = common.getAttributedString(jsonDataCoded)
                    
                    // Knock back the light background to make the scroll bars visible in dark mode
                    // NOTE If !doShowLightBackground,
                    //              in light mode, the scrollers show up dark-on-light, in dark mode light-on-dark
                    //      If doShowLightBackground,
                    //              in light mode, the scrollers show up light-on-light, in dark mode light-on-dark
                    // NOTE Changing the scrollview scroller knob style has no effect
                    self.renderTextView.backgroundColor = common.doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                    self.renderTextScrollView.scrollerKnobStyle = common.doShowLightBackground ? .dark : .light

                    if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                        /*
                         * NSTextStorage subclasses that return true from the fixesAttributesLazily
                         * method should avoid directly calling fixAttributes(in:) or else bracket
                         * such calls with beginEditing() and endEditing() messages.
                         */
                        renderTextStorage.beginEditing()
                        renderTextStorage.setAttributedString(jsonAttString)
                        renderTextStorage.endEditing()
                        
                        // Add the subview to the instance's own view and draw
                        self.view.display()

                        // Call the QLPreviewingController indicating no error
                        // (argument is nil)
                        handler(nil)
                        return
                    }
                    
                    // We can't access the preview NSTextView's NSTextStorage
                    reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
                } else {
                    // We couldn't convert to data to a valid encoding
                    let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                    reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: errDesc])
                }
            } catch {
                // We couldn't read the file so set an appropriate error to report back
                reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
            }
        } else {
            // We couldn't access the file so set an appropriate error to report back
            reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE)
        }

        // Display the error locally in the window
        showError(reportError!.userInfo[NSLocalizedDescriptionKey] as! String)

        // Call the QLPreviewingController indicating an error
        // (argumnet is not nil)
        handler(reportError)
    }
    

    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
     *
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
        // Perform any setup necessary in order to prepare the view.

        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        handler(nil)
    }
     */


    // MARK: - Utility Functions
    
    /**
     Place an error message in its various outlets.
     
     - parameters:
        - errString: The error message.
     */
    func showError(_ errString: String) {

        NSLog("BUFFOON \(errString)")
        self.renderTextScrollView.isHidden = true
        self.view.display()
    }
    
    
    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func setError(_ code: Int) -> NSError {
        
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
    
}
