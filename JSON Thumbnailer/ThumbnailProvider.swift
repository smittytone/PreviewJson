/*
 *  ThumbnailProvider.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 01/09/2023.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {

    // MARK: - Private Properties

    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badFileUnsupportedEncoding(String)
        case badFileUnsupportedFile(String)
        case badGfxBitmap
        case badGfxDraw
    }


    // MARK: - QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for macOS' thumbnailing system
         */

        do {
            // Get the file contents as a string, making sure it's not cached
            // as we're not going to read it again any time soon.
            // NOTE 'FileHandle(forReadingFrom)' throws if the file does not exist
            let jsonFileHandle = try FileHandle(forReadingFrom: request.fileURL)
            try jsonFileHandle.seek(toOffset: 0)
            // FROM 2.0.1 -- make sure `data` is not `nil`
            guard let data = try jsonFileHandle.read(upToCount: BUFFOON_CONSTANTS.MAX_THUMBNAIL_READ_SIZE) else {
                // No data in the file? Close the file handle, call the handler and bail
                try jsonFileHandle.close()
                handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
                return
            }

            // Close the file handle
            try jsonFileHandle.close()

            // Get the string's encoding, or fail back to .utf8
            let encoding: String.Encoding = data.stringEncoding ?? .utf8

            // Check the string's encoding generates a valid string
            // NOTE This may not be necessary and so may be removed
            guard let json = String(data: data, encoding: encoding) else {
                handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                return
            }

            // Instantiate the common code within the closure
            let common = Common(forThumbnail: true)

            // Set the primary drawing frame and a base font size
            let jsonTextFieldFrame = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

            // Instantiate an NSTextField to display the NSAttributedString render of the JSON
            let jsonTextField: NSTextField = NSTextField(frame: jsonTextFieldFrame)
            jsonTextField.attributedStringValue = common.getThumbnailString(fromJson: json)

            // FROM 2.0.0
            // From macOS 26.1, make sure thumbnail backgrounds remain white
            // NOTE This may become a setting in future, but for now retain the styling
            //      we have always presented.
            if #available(macOS 26.1, *) {
                if !common.settings.thumbnailMatchFinderMode {
                    jsonTextField.isBezeled = false
                    jsonTextField.drawsBackground = true
                    jsonTextField.backgroundColor = .white
                }
            }

            // Generate the bitmap from the rendered JSON text view
            guard let bodyImageRep = jsonTextField.bitmapImageRepForCachingDisplay(in: jsonTextFieldFrame) else {
                handler(nil, ThumbnailerError.badGfxBitmap)
                return
            }

            // Draw the code view into the bitmap
            jsonTextField.cacheDisplay(in: jsonTextFieldFrame, to: bodyImageRep)

            if let image = bodyImageRep.cgImage {
                // Calculate image scaling, frame size, etc.
                let thumbnailFrame = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)
                let scaleFrame = NSMakeRect(16.0,
                                            24.0,
                                            thumbnailFrame.width * request.scale - 16.0,
                                            thumbnailFrame.height * request.scale - 24.0)

                // Pass a QLThumbnailReply and no error to the supplied handler
                handler(QLThumbnailReply(contextSize: thumbnailFrame.size) { (context) -> Bool in
                    // `scaleFrame` and `image` are immutable
                    context.draw(image, in: scaleFrame, byTiling: false)
                    return true
                }, nil)

                return
            }

            handler(nil, ThumbnailerError.badGfxDraw)
            return
        } catch {
            // NOP: fall through to error
        }

        // We didn't draw anything because of 'can't find file' error
        handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
    }
}
