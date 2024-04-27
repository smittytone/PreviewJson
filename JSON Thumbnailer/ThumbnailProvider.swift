/*
 *  ThumbnailProvider.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 01/09/2023.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {

    // MARK:- Private Properties

    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badFileUnsupportedEncoding(String)
        case badFileUnsupportedFile(String)
        case badGfxBitmap
        case badGfxDraw
    }


    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for macOS' thumbnailing system
         */

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string, making sure it's not cached
                // as we're not going to read it again any time soon
                let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                // Check the string's encoding generates a valid string
                // NOTE This may not be necessary and so may be removed
                guard let _: String = String.init(data: data, encoding: encoding) else {
                    handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                    return
                }

                // Instantiate the common code within the closure
                let common: Common = Common.init(true)

                // Set the primary drawing frame and a base font size
                let jsonFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                   CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                // Instantiate an NSTextField to display the NSAttributedString render of the JSON
                let jsonTextField: NSTextField = NSTextField.init(frame: jsonFrame)
                jsonTextField.attributedStringValue = common.getAttributedString(data)

                // Generate the bitmap from the rendered JSON text view
                guard let bodyImageRep: NSBitmapImageRep = jsonTextField.bitmapImageRepForCachingDisplay(in: jsonFrame) else {
                    handler(nil, ThumbnailerError.badGfxBitmap)
                    return
                }

                // Draw the code view into the bitmap
                jsonTextField.cacheDisplay(in: jsonFrame, to: bodyImageRep)

                if let image: CGImage = bodyImageRep.cgImage {
                    // Just in case, make a copy of the cgImage, in case
                    // `bodyImageReg` is freed
                    if let cgImage: CGImage = image.copy() {
                        // Calculate image scaling, frame size, etc.
                        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                                0.0,
                                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                                request.maximumSize.height)
                        let scaleFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            thumbnailFrame.width * request.scale,
                                                            thumbnailFrame.height * request.scale)

                        // Pass a QLThumbnailReply and no error to the supplied handler
                        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
                            // `scaleFrame` and `cgImage` are immutable
                            context.draw(cgImage, in: scaleFrame, byTiling: false)
                            return true
                        }, nil)
                        return
                    }
                }

                handler(nil, ThumbnailerError.badGfxDraw)
                return
            } catch {
                // NOP: fall through to error
            }
        }

        // We didn't draw anything because of 'can't find file' error
        handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
    }
}
