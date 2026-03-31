/*
 *  Constants.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 12/08/2020.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation


// Combine the app's various constants into a struct
struct BUFFOON_CONSTANTS {

    struct ERRORS {

        struct CODES {
            static let NONE                     = 0
            static let FILE_INACCESSIBLE        = 400
            static let FILE_WONT_OPEN           = 401
            static let BAD_MD_STRING            = 402
            static let BAD_TS_STRING            = 403
        }

        struct MESSAGES {
            static let NO_ERROR                 = "No error"
            static let FILE_INACCESSIBLE        = "Can't access file"
            static let FILE_WONT_OPEN           = "Can't open file"
            static let BAD_MD_STRING            = "Can't get JSON data"
            static let BAD_TS_STRING            = "Can't access NSTextView's TextStorage"
        }
    }

    struct THUMBNAIL_SIZE {

        static let ORIGIN_X                     = 0
        static let ORIGIN_Y                     = 0
        static let WIDTH                        = 768
        static let HEIGHT                       = 1024
        static let ASPECT                       = 0.75
        static let TAG_HEIGHT                   = 204.8
        static let FONT_SIZE                    = 130.0
    }
    
    struct ITEM_TYPE {
        
        static let KEY                          = 0
        static let VALUE                        = 1
        static let MARK_START                   = 2
        static let MARK_END                     = 3
    }
    
    struct BOOL_STYLE {
        
        static let FULL                         = 0
        static let OUTLINE                      = 1
        static let TEXT                         = 2
    }

    struct APP_URLS {
        
        static let PM                           = "https://apps.apple.com/us/app/previewmarkdown/id1492280469?ls=1"
        static let PC                           = "https://apps.apple.com/us/app/previewcode/id1571797683?ls=1"
        static let PY                           = "https://apps.apple.com/us/app/previewyaml/id1564574724?ls=1"
        static let PJ                           = "https://apps.apple.com/us/app/previewjson/id6443584377?ls=1"
        static let PT                           = "https://apps.apple.com/us/app/previewtext/id1660037028?ls=1"
    }
    
    struct PREFS_IDS {

        static let WHATS_NEW                    = "com-bps-previewjson-do-show-whats-new-"
        static let PREVIEW_BODY_FONT_NAME       = "com-bps-previewjson-base-font-name"
        static let PREVIEW_BODY_FONT_SIZE       = "com-bps-previewjson-base-font-size"
        static let PREVIEW_USE_LIGHT            = "com-bps-previewjson-do-use-light"
        static let PREVIEW_SHOW_MARKS           = "com-bps-previewjson-do-indent-scalars"
        static let PREVIEW_SHOW_RAW             = "com-bps-previewjson-show-bad-json"
        static let PREVIEW_JSON_INDENT          = "com-bps-previewjson-json-indent"
        static let PREVIEW_BOOL_STYLE           = "com-bps-previewjson-bool-style"
        static let PREVIEW_KEYS_COLOUR          = "com-bps-previewjson-code-colour-hex"
        static let PREVIEW_STRINGS_COLOUR       = "com-bps-previewjson-string-colour-hex"
        static let PREVIEW_SPECIALS_COLOUR      = "com-bps-previewjson-special-colour-hex"
        static let PREVIEW_MARKS_COLOUR         = "com-bps-previewjson-mark-colour-hex"
        static let PREVIEW_MARGIN_WIDTH         = "com-bps-previewjson-margin-width"
        static let PREVIEW_WINDOW_SCALE         = "com-bps-previewjson-window-scale"
        static let THUMB_MATCH_FINDER           = "com-bps-previewjson-thumb-match-finder"
        static let THUMB_SIZE                   = "com-bps-previewjson-thumb-font-size"
    }

    struct COLOUR_IDS {

        static let KEYS                         = "keys"
        static let STRINGS                      = "strings"
        static let SPECIALS                     = "specials"
        static let MARKS                        = "marks"
        static let NEW_KEYS                     = "new_keys"
        static let NEW_STRINGS                  = "new_strings"
        static let NEW_SPECIALS                 = "new_specials"
        static let NEW_MARKS                    = "new_marks"
    }

    struct HEX_COLOUR {

        static let KEYS                         = "FF2600FF"
        static let STRINGS                      = "FC6A5DFF"
        static let SPECIALS                     = "D0BF69FF"
        static let MARKS                        = "929292FF"
    }

    struct PREVIEW_SIZE {

        static let FONT_SIZE                    = 16.0
        static let FONT_SIZE_OPTIONS: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        static let LINE_SPACING                 = 1.0
        static let PREVIEW_MARGIN_WIDTH         = 16.0
        static let PREVIEW_MARGIN_WIDTH_MIN     = 0
        static let PREVIEW_MARGIN_WIDTH_MAX     = 256
        static let PREVIEW_MARGIN_SIZE          = NSSize(width: PREVIEW_MARGIN_WIDTH, height: PREVIEW_MARGIN_WIDTH)
    }

    struct THUMB_SIZE {

        static let FONT_SIZE                    = 22.0
    }

    struct SCALERS {

        static let WINDOW_SIZE_L                = 0.75
        static let WINDOW_SIZE_M                = 0.50
        static let WINDOW_SIZE_S                = 0.42
    }

    static let COLOUR_OPTIONS                   = [BUFFOON_CONSTANTS.COLOUR_IDS.KEYS,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.MARKS]

    static let BODY_FONT_NAME                   = "Menlo-Regular"
    static let JSON_INDENT                      = 8     // Can change
    static let TABBED_INDENT                    = 4     // Fixed
    static let TABULATION_INDENT_VALUE          = 999

    static let URL_MAIN                         = "https://smittytone.net/previewjson/index.html"
    static let APP_STORE                        = "https://apps.apple.com/us/app/previewjson/id6443584377?ls"
    static let SUITE_NAME                       = ".suite.preview-previewjson"
    static let APP_CODE_PREVIEWER               = "com.bps.previewjson.JSON-Previewer"

    // FROM 2.0.0
    static let MAX_FEEDBACK_SIZE                = 512
    static let MAX_THUMBNAIL_READ_SIZE          = 1024
    static let BASE_TAB_SIZE_PT                 = CGFloat(20.0)
    static let BASE_PARA_SPACING_PT             = CGFloat(0.15)
    static let MAX_TAB_COL_SIZE_PT              = CGFloat(400.0)
    static let TAB_COL_IMAGE_WIDTH_PT           = CGFloat(120.0)

#if DEBUG2
    static let CR                               = "↵\n"
    static let COLLECTION_SPACER                = "⟼\n"
#else
    static let CR                               = "\n"
    static let COLLECTION_SPACER                = "\n"
#endif
}

