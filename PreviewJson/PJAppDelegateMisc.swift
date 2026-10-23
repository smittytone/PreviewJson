/*
 *  PJAppDelegateMisc.swift
 *  PreviewJson
 *
 *  Created by Tony Smith on 121/08/2026.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit

extension AppDelegate {

    /**
     Disable all panel-opening menu items.
     */
    internal func localHides() {

        self.helpMenuReportBug.isEnabled = false
    }


    /**
     Enable all panel-opening menu items.
     */
    internal func localShows() {

        self.helpMenuReportBug.isEnabled = true
    }

}
