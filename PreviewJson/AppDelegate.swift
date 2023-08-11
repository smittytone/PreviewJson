/*
 *  AppDelegate.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 9/08/2023.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


import Cocoa
import CoreServices
import WebKit


@main
final class AppDelegate: NSObject,
                         NSApplicationDelegate,
                         URLSessionDelegate,
                         URLSessionDataDelegate,
                         WKNavigationDelegate {

    // MARK: - Class UI Properies

    // Menu Items
    @IBOutlet var helpMenu: NSMenuItem!
    @IBOutlet var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet var helpMenuAppStoreRating: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewMarkdown: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewCode: NSMenuItem!
    @IBOutlet var helpMenuOtherspreviewYaml: NSMenuItem!
    // FROM 1.0.3
    @IBOutlet var helpMenuWhatsNew: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewText: NSMenuItem!
    @IBOutlet var mainMenuSettings: NSMenuItem!
    
    // Panel Items
    @IBOutlet var versionLabel: NSTextField!
    
    // Windows
    @IBOutlet var window: NSWindow!

    // Report Sheet
    @IBOutlet weak var reportWindow: NSWindow!
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!

    // Preferences Sheet
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!
    @IBOutlet weak var codeIndentPopup: NSPopUpButton!
    @IBOutlet weak var codeColorWell: NSColorWell!
    //@IBOutlet weak var markColorWell: NSColorWell!
    @IBOutlet weak var boolStyleSegment: NSSegmentedControl!
    @IBOutlet weak var useLightCheckbox: NSButton!
    @IBOutlet weak var doShowRawJsonCheckbox: NSButton!
    @IBOutlet weak var doShowJsonFurnitureCheckbox: NSButton!
    // FROM 1.1.0
    @IBOutlet var colourSelectionPopup: NSPopUpButton!

    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!
    

    // MARK: - Private Properies

    internal var whatsNewNav: WKNavigation?     = nil
    private  var feedbackTask: URLSessionTask?  = nil
    private  var indentDepth: Int               = BUFFOON_CONSTANTS.JSON_INDENT
    private  var boolStyle: Int                 = BUFFOON_CONSTANTS.BOOL_STYLE.FULL
    private  var fontSize: CGFloat              = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
    private  var fontName: String               = BUFFOON_CONSTANTS.BODY_FONT_NAME
    //private  var codeColourHex: String        = BUFFOON_CONSTANTS.KEY_COLOUR_HEX
    //private  var markColourHex: String        = BUFFOON_CONSTANTS.MARK_COLOUR_HEX
    private  var appSuiteName: String           = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    private  var feedbackPath: String           = MNU_SECRETS.ADDRESS.B
    private  var doShowLightBackground: Bool    = false
    private  var doShowTag: Bool                = false
    private  var doShowRawJson: Bool            = false
    private  var doShowFurniture: Bool          = true
    internal var isMontereyPlus: Bool           = false
    internal var codeFonts: [PMFont]            = []
    // FROM 1.0.3
    private var havePrefsChanged: Bool = false
    // FROM 1.1.0
    private var displayColours: [String:String] = [:]
    

    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Asynchronously get the list of code fonts
        DispatchQueue.init(label: "com.bps.previewjson.async-queue").async {
            self.asyncGetFonts()
        }

        // Set application group-level defaults
        registerPreferences()
        recordSystemState()
        
        // Add the app's version number to the UI
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Version \(version) (\(build))"

        // Disable the Help menu Spotlight features
        let dummyHelpMenu: NSMenu = NSMenu.init(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu
        
        // Watch for macOS UI mode changes
        DistributedNotificationCenter.default.addObserver(self,
                                                          selector: #selector(interfaceModeChanged),
                                                          name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
                                                          object: nil)
        
        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // Show the 'What's New' panel if we need to
        // NOTE Has to take place at the end of the function
        doShowWhatsNew(self)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions

    /**
     Called from **File > Close** and the various Quit controls.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doClose(_ sender: Any) {
        
        // Reset the QL thumbnail cache... just in case it helps
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // FROM 1.0.3
        // Check for open panels
        if self.preferencesWindow.isVisible {
            if self.havePrefsChanged {
                let alert: NSAlert = showAlert("You have unsaved settings",
                                               "Do you wish to cancel and save these, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.preferencesWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.preferencesWindow.close()
        }
        
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
        
        if self.reportWindow.isVisible {
            if self.feedbackText.stringValue.count > 0 {
                let alert: NSAlert = showAlert("You have unsent feedback",
                                               "Do you wish to cancel and send it, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.reportWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.reportWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.reportWindow.close()
        }
        
        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    /**
     Called from various **Help** items to open various websites.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doShowSites(sender: Any) {
        
        // Open the websites for contributors, help and suc
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN
        
        // Depending on the menu selected, set the load path
        if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.helpMenuOnlineHelp {
            path += "#how-to-use-previewjson"
        } else if item == self.helpMenuOthersPreviewMarkdown {
            path = BUFFOON_CONSTANTS.APP_URLS.PM
        } else if item == self.helpMenuOthersPreviewCode {
            path = BUFFOON_CONSTANTS.APP_URLS.PC
        } else if item == self.helpMenuOtherspreviewYaml {
            path = BUFFOON_CONSTANTS.APP_URLS.PY
        } else if item == self.helpMenuOthersPreviewText {
            path = BUFFOON_CONSTANTS.APP_URLS.PT
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }

    
    /**
     Open the System Preferences app at the Extensions pane.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doOpenSysPrefs(sender: Any) {

        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    // MARK: - Report Functions

    /**
     Display a window in which the user can submit feedback, or report a bug.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doShowReportWindow(sender: Any?) {
        
        // FROM 1.0.3
        // Hide menus we don't want used while panel is open
        hidePanelGenerators()
        
        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""

        // Present the window
        self.window.beginSheet(self.reportWindow,
                               completionHandler: nil)
    }


    /**
     User has clicked the Report window's **Cancel** button, so just close the sheet.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doCancelReportWindow(sender: Any) {

        // User has clicked the Report window's 'Cancel' button,
        // so just close the sheet

        self.connectionProgress.stopAnimation(self)
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.0.3
        // Restore menus
        showPanelGenerators()
    }

    
    /**
     User has clicked the Report window's **Send** button.

     Get the message (if there is one) from the text field and submit it.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doSendFeedback(sender: Any) {

        // User has clicked the Report window's 'Send' button,
        // so get the message (if there is one) from the text field and submit it
        
        let feedback: String = self.feedbackText.stringValue

        if feedback.count > 0 {
            // Start the connection indicator if it's not already visible
            self.connectionProgress.startAnimation(self)
            
            self.feedbackTask = submitFeedback(feedback)
            
            if self.feedbackTask != nil {
                // We have a valid URL Session Task, so start it to send
                self.feedbackTask!.resume()
                return
            } else {
                // Report the error
                sendFeedbackError()
            }
        }
        
        // No feedback, so close the sheet
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.0.3
        // Restore menus
        showPanelGenerators()
        
        // NOTE sheet closes asynchronously unless there was no feedback to send,
        //      or an error occured with setting up the feedback session
    }
    

    // MARK: - Preferences Functions

    /**
     Initialise and display the **Preferences** sheet.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doShowPreferences(sender: Any) {

        // FROM 1.0.3
        // Hide menus we don't want used while panel is open
        hidePanelGenerators()
        
        // FROM 1.0.3
        // Reset changes prefs flag
        self.havePrefsChanged = false

        // The suite name is the app group name, set in each the entitlements file of
        // the host app and of each extension
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.fontSize                   = CGFloat(defaults.float(forKey: "com-bps-previewjson-base-font-size"))
            self.fontName                   = defaults.string(forKey: "com-bps-previewjson-base-font-name") ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            self.indentDepth                = defaults.integer(forKey: "com-bps-previewjson-json-indent")
            self.doShowLightBackground      = defaults.bool(forKey: "com-bps-previewjson-do-use-light")
            self.doShowRawJson              = defaults.bool(forKey: "com-bps-previewjson-show-bad-json")
            /* REMOVED 1.1.0
            self.codeColourHex            = defaults.string(forKey: "com-bps-previewjson-code-colour-hex") ?? BUFFOON_CONSTANTS.KEY_COLOUR_HEX
            self.markColourHex            = defaults.string(forKey: "com-bps-previewjson-mark-colour-hex") ?? BUFFOON_CONSTANTS.MARK_COLOUR_HEX
             */
            self.doShowFurniture            = defaults.bool(forKey: "com-bps-previewjson-do-indent-scalars")
            self.boolStyle                  = defaults.integer(forKey: "com-bps-previewjson-bool-style")

            // FROM 1.1.0
            self.displayColours["key"]      = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.KEY_COLOUR)
            self.displayColours["string"]   = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR) ?? BUFFOON_CONSTANTS.STRING_COLOUR_HEX
            self.displayColours["special"]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR) ?? BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX
            self.displayColours["mark"]     = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.MARK_COLOUR) ?? BUFFOON_CONSTANTS.MARK_COLOUR_HEX
        }

        // Get the menu item index from the stored value
        // NOTE The index is that of the list of available fonts (see 'Common.swift') so
        //      we need to convert this to an equivalent menu index because the menu also
        //      contains a separator and two title items
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.fontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        
        // Set the checkboxes
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        self.doShowRawJsonCheckbox.state = self.doShowRawJson ? .on : .off
        self.doShowJsonFurnitureCheckbox.state = self.doShowFurniture ? .on : .off
        
        // Set the indents popup
        let indents: [Int] = [1, 2, 4, 8]
        self.codeIndentPopup.selectItem(at: indents.firstIndex(of: self.indentDepth)!)
        
        // Set the colour panel's initial view
        NSColorPanel.setPickerMode(.RGB)
        self.codeColorWell.color = NSColor.hexToColour(self.displayColours["key"] ?? BUFFOON_CONSTANTS.KEY_COLOUR_HEX)
        //self.markColorWell.color = NSColor.hexToColour(self.markColourHex)
        
        // Set the font name popup
        // List the current system's monospace fonts
        self.codeFontPopup.removeAllItems()
        for i: Int in 0..<self.codeFonts.count {
            let font: PMFont = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }
        
        // Set the font style
        self.codeStylePopup.isEnabled = false
        selectFontByPostScriptName(self.fontName)
        
        // Set the style for JSON bools and null
        self.boolStyleSegment.selectedSegment = self.boolStyle
        
        // Check for the OS mode
        let appearance: NSAppearance = NSApp.effectiveAppearance
        if let appearName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
            self.useLightCheckbox.isHidden = (appearName == .aqua)
        }

        // FROM 1.1.0
        self.colourSelectionPopup.selectItem(at: 0)
        
        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
    }


    /**
        When the font size slider is moved and released, this function updates the font size readout.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doMoveSlider(sender: Any) {
        
        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        self.havePrefsChanged = false
    }


    /**
     Called when the user selects a font from either list.

     FROM 1.1.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doUpdateFonts(sender: Any) {
        
        self.havePrefsChanged = false
        setStylePopup()
    }

    
    /**
        Close the **Preferences** sheet without saving.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doClosePreferences(sender: Any) {

        if self.havePrefsChanged {
            let alert: NSAlert = showAlert("You have made changes",
                                           "Do you wish to go back and save them, or ignore them? ",
                                           false)
            alert.addButton(withTitle: "Go Back")
            alert.addButton(withTitle: "Ignore Changes")
            alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                if response != NSApplication.ModalResponse.alertFirstButtonReturn {
                    // The user clicked 'Cancel'
                    self.closePrefsWindow()
                }
            }
        } else {
            closePrefsWindow()
        }
    }


    /**
        Follow-on function to close the **Preferences** sheet without saving.
        FROM 1.1.0

        - Parameters:
            - sender: The source of the action.
     */
    private func closePrefsWindow() {

        // Close the colour selection panel(s) if they're open
        if self.codeColorWell.isActive {
            NSColorPanel.shared.close()
            self.codeColorWell.deactivate()
        }

        /* REMOVED 1.1.0
        if self.markColorWell.isActive {
            NSColorPanel.shared.close()
            self.markColorWell.deactivate()
        }
        */

       // Shut the window
        self.window.endSheet(self.preferencesWindow)

        // FROM 1.0.3
        // Restore menus
        self.showPanelGenerators()

        // FROM 1.1.0
        self.clearNewColours()
        self.havePrefsChanged = false
    }


    /**
        Close the **Preferences** sheet and save any settings that have changed.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doSavePreferences(sender: Any) {

        // Close the colour selection panel(s) if they're open
        if self.codeColorWell.isActive {
            NSColorPanel.shared.close()
            self.codeColorWell.deactivate()
        }

        /* REMOVED 1.1.0
        if self.markColorWell.isActive {
            NSColorPanel.shared.close()
            self.markColorWell.deactivate()
        }
        */

        // Save any changed preferences
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            /* REMOVED 1.1.0
            // Check for and record a JSON key colour change
            var newColour: String = self.codeColorWell.color.hexString
            if newColour != self.codeColourHex {
                self.codeColourHex = newColour
                defaults.setValue(newColour,
                                  forKey: "com-bps-previewjson-code-colour-hex")
            }
            
            // Check for and record a JSON marker colour change
            newColour = self.markColorWell.color.hexString
            if newColour != self.markColourHex {
                self.markColourHex = newColour
                defaults.setValue(newColour,
                                  forKey: "com-bps-previewjson-mark-colour-hex")
            }
            */

            // Check for and record a use light background change
            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewjson-do-use-light")
            }
            
            // Check for and record a raw JSON presentation change
            state = self.doShowRawJsonCheckbox.state == .on
            if self.doShowRawJson != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewjson-show-bad-json")
            }
            
            // Check for and record a JSON marker presentation change
            state = self.doShowJsonFurnitureCheckbox.state == .on
            if self.doShowFurniture != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewjson-do-indent-scalars")
            }
            
            // Check for and record an indent change
            let indents: [Int] = [1, 2, 4, 8]
            let indent: Int = indents[self.codeIndentPopup.indexOfSelectedItem]
            if self.indentDepth != indent {
                defaults.setValue(indent,
                                  forKey: "com-bps-previewjson-json-indent")
            }
            
            // Check for and record a font and style change
            if let fontName: String = getPostScriptName() {
                if fontName != self.fontName {
                    self.fontName = fontName
                    defaults.setValue(fontName,
                                      forKey: "com-bps-previewjson-base-font-name")
                }
            }
            
            // Check for and record a font size change
            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.fontSize {
                defaults.setValue(newValue,
                                  forKey: "com-bps-previewjson-base-font-size")
            }
            
            // Check for and record a JSON bool style change
            let selectedStyle = self.boolStyleSegment.selectedSegment
            if self.boolStyle != selectedStyle {
                self.boolStyle = selectedStyle
                defaults.setValue(selectedStyle,
                                  forKey: "com-bps-previewjson-bool-style")
            }

            // FROM 1.1.0
            if let newColour: String = self.displayColours["new_key"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.KEY_COLOUR)
            }

            if let newColour: String = self.displayColours["new_string"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            }

            if let newColour: String = self.displayColours["new_special"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            }

            if let newColour: String = self.displayColours["new_mark"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.MARK_COLOUR)
            }

            // Sync any changes
            defaults.synchronize()
        }
        
        // Remove the sheet now we have the data
        self.window.endSheet(self.preferencesWindow)
        
        // FROM 1.0.3
        // Restore menus
        showPanelGenerators()

        // FROM 1.1.0
        clearNewColours()
    }


    /**
        Zap any temporary colour values.
        FROM 1.1.0
     
     */
    private func clearNewColours() {

        let keys: [String] = ["key", "string", "special", "mark"]
        for key in keys {
            if let _: String = self.displayColours["new_" + key] {
                self.displayColours["new_" + key] = nil
            }
        }
    }
    
    /**
        Generic IBAction for any Prefs control to register it has been used.
     
        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func checkboxClicked(sender: Any) {
        
        self.havePrefsChanged = true
    }


    /**
        Update the colour preferences dictionary with a value from the
        colour well when a colour is chosen.
        FROM 1.1.0

        - Parameters:
            - sender: The source of the action.
     */
    @objc @IBAction private func colourSelected(sender: Any) {

        let keys: [String] = ["key", "string", "special", "mark"]
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.displayColours[key] = self.codeColorWell.color.hexString
        self.havePrefsChanged = true
    }


    /**
        Update the colour well with the stored colour: either a new one, previously
        chosen, or the loaded preference.
        FROM 1.1.0

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doChooseColourType(sender: Any) {

        let keys: [String] = ["key", "string", "special", "mark"]
        let key: String = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        if let colour: String = self.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.codeColorWell.color = NSColor.hexToColour(colour)
                return
            }
        }

        // Set the colourwell with the stored colour
        if let colour: String = self.displayColours[key] {
            self.codeColorWell.color = NSColor.hexToColour(colour)
        }
    }


    // MARK: - What's New Sheet Functions

    /**
        Show the **What's New** sheet.

        If we're on a new, non-patch version, of the user has explicitly
        asked to see it with a menu click See if we're coming from a menu click
        (`sender != self`) or directly in code from *appDidFinishLoading()*
        (`sender == self`)

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doShowWhatsNew(_ sender: Any) {

        // See if we're coming from a menu click (sender != self) or
        // directly in code from 'appDidFinishLoading()' (sender == self)
        var doShowSheet: Bool = type(of: self) != type(of: sender)
        
        if !doShowSheet {
            // We are coming from the 'appDidFinishLoading()' so check
            // if we need to show the sheet by the checking the prefs
            if let defaults = UserDefaults(suiteName: self.appSuiteName) {
                // Get the version-specific preference key
                let key: String = BUFFOON_CONSTANTS.PREFS_KEYS.WHATS_NEW + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }
      
        // Configure and show the sheet
        if doShowSheet {
            // FROM 1.0.3
            // Hide menus we don't want used while panel is open
            hidePanelGenerators()
            
            // First, get the folder path
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"
            
            // Set up the WKWebBiew: no elasticity, horizontal scroller
            self.whatsNewWebView.enclosingScrollView?.hasHorizontalScroller = false
            self.whatsNewWebView.enclosingScrollView?.horizontalScrollElasticity = .none
            self.whatsNewWebView.enclosingScrollView?.verticalScrollElasticity = .none
            
            // Just in case, make sure we can load the file
            if FileManager.default.fileExists(atPath: htmlFolderPath) {
                let htmlFileURL = URL.init(fileURLWithPath: htmlFolderPath + "/new.html")
                let htmlFolderURL = URL.init(fileURLWithPath: htmlFolderPath)
                self.whatsNewNav = self.whatsNewWebView.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFolderURL)
            }
        }
    }


    /**
        Close the **What's New** sheet.

        Make sure we clear the preference flag for this minor version, so that
        the sheet is not displayed next time the app is run (unless the version changes)

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doCloseWhatsNew(_ sender: Any) {

        // Close the sheet
        self.window.endSheet(self.whatsNewWindow)
        
        // Scroll the web view back to the top
        self.whatsNewWebView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)

        // Set this version's preference
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let key: String = BUFFOON_CONSTANTS.PREFS_KEYS.WHATS_NEW + getVersion()
            defaults.setValue(false, forKey: key)

#if DEBUG
            print("\(key) reset back to true")
            defaults.setValue(true, forKey: key)
#endif

            defaults.synchronize()
        }
        
        // FROM 1.0.3
        // Restore menus
        showPanelGenerators()
    }


    // MARK: - Misc Functions

    /**
     Called by the app at launch to register its initial defaults.
     */
    private func registerPreferences() {

        // Check if each preference value exists -- set if it doesn't
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            let bodyFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE)
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE)
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 28.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.THUMB_SIZE)
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.THUMB_SIZE)
            }
            
            // Colour of JSON keys in the preview, stored as a hex string
            // Default: #CA0D0E
            var colourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.KEY_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.KEY_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.KEY_COLOUR)
            }
            
            // Colour of JSON markers in the preview, stored as a hex string
            // Default: #0096FF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.MARK_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.MARK_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.MARK_COLOUR)
            }
            
            // Font for previews and thumbnails
            // Default: Courier
            let fontName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_FONT)
            if fontName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BODY_FONT_NAME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_FONT)
            }
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = BUFFOON_CONSTANTS.PREFS_KEYS.WHATS_NEW + getVersion()
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // Record the preferred indent depth in spaces
            // Default: 8
            let indentDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            if indentDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.JSON_INDENT,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            }
            
            // Despite var names, should we show JSON furniture?
            // Default: true
            let indentScalarsDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            if indentScalarsDefault == nil {
                defaults.setValue(true,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            }
            
            // Present malformed JSON on error?
            // Default: false
            let presentBadJsonDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            if presentBadJsonDefault == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            }
            
            // Set the boolean presentation style
            // Default: false
            let boolStyle: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BOOL_STYLE)
            if boolStyle == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BOOL_STYLE.FULL,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BOOL_STYLE)
            }

            // FROM 1.1.0
            // Colour of strings in the preview, stored as a hex string
            // Default: #FC6A5DFF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.STRING_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            }

            // Colour of special values (Bools, NULL, etc) in the preview, stored as a hex string
            // Default: #FC6A5DFF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            }

            // Sync any additions
            defaults.synchronize()
        }

    }
    

    /**
     Send the feedback string etc.

     - Parameters:
        - feedback: The text of the user's comment.

     - Returns: A URLSessionTask primed to send the comment, or `nil` on error.
     */
    private func submitFeedback(_ feedback: String) -> URLSessionTask? {

        // First get the data we need to build the user agent string
        let userAgent: String = getUserAgentForFeedback()
        let endPoint: String = MNU_SECRETS.ADDRESS.A

        // Get the date as a string
        let dateString: String = getDateForFeedback()

        // Assemble the message string
        let dataString: String = """
         *FEEDBACK REPORT*
         *Date:* \(dateString)
         *User Agent:* \(userAgent)
         *FEEDBACK:*
         \(feedback)
         """

        // Build the data we will POST:
        let dict: NSMutableDictionary = NSMutableDictionary()
        dict.setObject(dataString,
                        forKey: NSString.init(string: "text"))
        dict.setObject(true, forKey: NSString.init(string: "mrkdwn"))

        // Make and return the HTTPS request for sending
        if let url: URL = URL.init(string: self.feedbackPath + endPoint) {
            var request: URLRequest = URLRequest.init(url: url)
            request.httpMethod = "POST"

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: dict,
                                                              options:JSONSerialization.WritingOptions.init(rawValue: 0))

                request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.addValue("application/json", forHTTPHeaderField: "Content-type")

                let config: URLSessionConfiguration = URLSessionConfiguration.ephemeral
                let session: URLSession = URLSession.init(configuration: config,
                                                          delegate: self,
                                                          delegateQueue: OperationQueue.main)
                return session.dataTask(with: request)
            } catch {
                // NOP
            }
        }

        return nil
    }
    
    
    /**
     Handler for macOS UI mode change notifications
     */
    @objc private func interfaceModeChanged() {
        
        if self.preferencesWindow.isVisible {
            // Prefs window is up, so switch the use light background checkbox
            // on or off according to whether the current mode is light
            // NOTE For light mode, this checkbox is irrelevant, so the
            //      checkbox should be disabled
            let appearance: NSAppearance = NSApp.effectiveAppearance
            if let appearName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
                // NOTE Appearance it this point seems to reflect the mode
                //      we're coming FROM, not what it has changed to
                self.useLightCheckbox.isHidden = (appearName != .aqua)
            }
        }
    }

}


