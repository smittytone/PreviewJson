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
            // as we're not going to read it again any time soon
            //let data: Data = try Data(contentsOf: request.fileURL, options: [.uncached])
            let jsonFileHandle = try FileHandle(forReadingFrom: request.fileURL)
            try jsonFileHandle.seek(toOffset: 0)
            let data = try jsonFileHandle.read(upToCount: BUFFOON_CONSTANTS.MAX_THUMBNAIL_READ_SIZE)
            try jsonFileHandle.close()

            // Get the string's encoding, or fail back to .utf8
            let encoding: String.Encoding = data!.stringEncoding ?? .utf8

            // Check the string's encoding generates a valid string
            // NOTE This may not be necessary and so may be removed
            guard let json: String = String(data: data!, encoding: encoding) else {
                handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                return
            }

            // Instantiate the common code within the closure
            let common: Common = Common(forThumbnail: true)

            // Set the primary drawing frame and a base font size
            let jsonFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

            // Instantiate an NSTextField to display the NSAttributedString render of the JSON
            let jsonTextField: NSTextField = NSTextField(frame: jsonFrame)
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
            guard let bodyImageRep: NSBitmapImageRep = jsonTextField.bitmapImageRepForCachingDisplay(in: jsonFrame) else {
                handler(nil, ThumbnailerError.badGfxBitmap)
                return
            }

            // Draw the code view into the bitmap
            jsonTextField.cacheDisplay(in: jsonFrame, to: bodyImageRep)

            if let image: CGImage = bodyImageRep.cgImage {
                let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                        0.0,
                                                        CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                        request.maximumSize.height)
                let scaleFrame: CGRect = NSMakeRect(20.0,
                                                    20.0,
                                                    thumbnailFrame.width * request.scale - 20.0,
                                                    thumbnailFrame.height * request.scale - 20.0)

                // Pass a QLThumbnailReply and no error to the supplied handler
                handler(QLThumbnailReply(contextSize: thumbnailFrame.size) { (context) -> Bool in
                    // `scaleFrame` and `cgImage` are immutable
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
