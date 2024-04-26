# PreviewJson 1.1.2 #

QuickLook JSON preview and icon thumbnailing app extensions for macOS Catalina and beyond

![PreviewJson App Store QR code](qr-code.jpg)

## Installation and Usage ##

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview markdown documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Previewer and Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The colour of object keys, strings, `true`/`false`/`null` when displayed as text, and JSON tags.
- The colour of JSON object and array delimiters, if they are displayed.
- Whether to include JSON object and array delimiters in previews.
- Whether to show raw JSON if it cannot be parsed without error.
- The preview’s monospaced font and text size.
- The body text font.
- Whether preview should be display white-on-black even in Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnail until you open a folder that has not been previously opened in the current login session.

## Source Code #

The source code is provided here for inspection and inspiration. The code will not build as is: graphical, other non-code resources and some code components are not included in the source release. To build *PreviewJson* from scratch, you will need to add these files yourself or remove them from your fork.

The files `REPLACE_WITH_YOUR_FUNCTIONS` and `REPLACE_WITH_YOUR_CODES` must be replaced with your own files. The former will contain your `sendFeedback(_ feedback: String) -> URLSessionTask?` function. The latter your Developer Team ID, used as the App Suite identifier prefix.

You will need to generate your own `Assets.xcassets` file containing the app icon and an `app_logo.png` file and `style_x.png` where x is 1-3 and are, respectively, the solid, outline and textual options presented by the **Preferences** window as True/False/Null styles.

You will need to create your own `new` directory containing your own `new.html` file.

## Contributions ##

Contributions are welcome, but pull requests can only be accepted when they target the `develop` branch. PRs targetting `main` will be rejected.

Contributions will only be accepted if the code they contain is licensed under the terms of [the MIT Licence](#LICENSE.md)

## Release Notes

- 1.1.2 *Unreleased*
    - Fix 'white flash' on opening What's New sheet.
- 1.1.1 *2 March 2024*
    - Correct indentation.
    - Make tabulated preview optional.
    - Fix for crashes caused by very deeply nested JSON files.
- 1.1.0 *25 August 2023*
    - Allow the user to choose the colours of strings and special values (`NaN`, `±INF`).
    - New columnar layout.
- 1.0.4 *12 May 2023*
    - Fix incorrect presentation of integers `1` and `0` as booleans (thanks, anonymous).
- 1.0.3 *21 January 2023*
    - Add link to [PreviewText](https://smittytone.net/previewtext/index.html).
    - Better menu handling when panels are visible.
    - Better app exit management.
- 1.0.2 *14 December 2022*
    - Reduce thumbnail rendering load.
    - Handle dark-to-light UI mode switches.
    - Add App Store link.
- 1.0.1 *4 October 2022*
    - Correct some text style discrepancies.
- 1.0.0 *2 October 2022*
    - Initial public release.

## Copyright and Credits

Primary app code and UI design &copy; 2024, Tony Smith.
