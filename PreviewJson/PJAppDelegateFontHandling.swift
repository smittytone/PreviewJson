/*
 *  PJAppDelegateFontHandling.swift
 *  PreviewJson
 *  Extension for AppDelegate providing font processing functionality.
 *
*  Created by Tony Smith on 18/06/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit
import WebKit


extension AppDelegate {

    // MARK: - Font Management

    /**
     Build a list of available fonts.

     Should be called asynchronously. Two sets created: monospace fonts and regular fonts.
     Requires 'bodyFonts' and 'codeFonts' to be set as instance properties.
     Comment out either of these, as required.

     The final font lists each comprise pairs of strings: the font's PostScript name
     then its display name.
     */
    internal func asyncGetFonts() {

        var cf: [PAFont] = []

        let fm = NSFontManager.shared
        let families = fm.availableFontFamilies
        for family in families {
            // Remove known unwanted fonts
            if family.hasPrefix(".") || family == "Apple Braille" || family == "Apple Color Emoji" {
                continue
            }

            // For each family, examine its fonts for suitable ones
            if let fonts = fm.availableMembers(ofFontFamily: family) {
                // This will hold a font family: individual fonts will be added to
                // the 'styles' array
                var familyRecord = PAFont()
                familyRecord.displayName = family

                for font in fonts {
                    var fontRecord = PAFont()
                    fontRecord.postScriptName = font[0] as? String ?? "error"
                    fontRecord.styleName = font[1] as? String ?? "error"
                    fontRecord.traits = font[3] as? UInt ?? 0

                    if familyRecord.styles == nil {
                        familyRecord.styles = []
                    }

                    familyRecord.styles!.append(fontRecord)
                }

                if familyRecord.styles != nil && familyRecord.styles!.count > 0 {
                    cf.append(familyRecord)
                }
            }
        }

        // All done, update the main stores and begin to load
        // settings (which immediately updates the UI, via `displaySettings()`,
        // which itself requires the font store to be populated
        // FROM 2.0.0 -- Use Swift Concurrency
        Task { @MainActor in
            // Run task on main thread (See notes in PreviewCode)
            self.fonts = cf
            self.loadSettings()
        }
    }


    /**
     Build and enable the font style popup.

     - Parameters:
        - styleName: The name of currently selected style, or nil to select the first one.
     */
    internal func setStylePopup(_ styleName: String? = nil) {

        if let selectedFamily = self.fontPopup.titleOfSelectedItem {
            self.stylePopup.removeAllItems()
            for family in self.fonts {
                if selectedFamily == family.displayName {
                    if let styles = family.styles {
                        self.stylePopup.isEnabled = true
                        for style in styles {
                            self.stylePopup.addItem(withTitle: style.styleName)
                        }

                        if styleName != nil {
                            self.stylePopup.selectItem(withTitle: styleName!)
                        }
                    }
                }
            }
        }
    }


    /**
     Select the font popup using the stored PostScript name
     of the user's chosen font.

     - Parameters:
        - postScriptName: The PostScript name of the font.
     */
    internal func selectFontByPostScriptName(_ postScriptName: String) {

        for family in self.fonts {
            if let styles = family.styles {
                for style in styles {
                    if style.postScriptName == postScriptName {
                        self.fontPopup.selectItem(withTitle: family.displayName)
                        setStylePopup(style.styleName)
                    }
                }
            }
        }
    }


    /**
     Get the PostScript name from the selected family and style.

     - Returns: The PostScript name as a string, or nil.
     */
    internal func getPostScriptName() -> String? {

        if let selectedFont = self.fontPopup.titleOfSelectedItem {
            let selectedStyle = self.stylePopup.indexOfSelectedItem

            // FROM 2.0.3 -- bail if there's no popup selection
            guard selectedStyle >= 0 else { return nil }

            for family in self.fonts {
                if family.displayName == selectedFont {
                    if let styles = family.styles {
                        if selectedStyle < styles.count {
                            let font = styles[selectedStyle]
                            return font.postScriptName
                        }
                    }
                }
            }
        }

        return nil
    }
}
