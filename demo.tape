# Records images/prompt.gif from the SimpleExample target.
# Requires VHS: brew install vhs
# Run from the repo root: vhs demo.tape

Output images/prompt.gif

Set Shell "bash"
Set FontFamily "Menlo"
Set FontSize 20
Set LineHeight 1.25
Set Width 1000
Set Height 820
Set Padding 28
Set Margin 24
Set MarginFill "#F4E1E6"
Set WindowBar Colorful
Set BorderRadius 12
Set Theme "Catppuccin Mocha"
Set TypingSpeed 70ms
Set Framerate 30

# Build first so compiler output stays out of the recording
Hide
Type "swift build --product SimpleExample >/dev/null 2>&1 && clear && .build/debug/SimpleExample" Enter
Wait+Screen@180s /Project name/
Show
Sleep 600ms

# Project name
Type "super-rover" Sleep 500ms Enter
Sleep 700ms

# Project type: move to Library
Down Sleep 350ms Down Sleep 350ms Up Sleep 500ms Enter
Sleep 700ms

# Extras: Tests and README are preselected, add SwiftLint
Down Sleep 300ms Down Sleep 300ms Down Sleep 400ms Space Sleep 600ms Enter
Sleep 700ms

# License: filter by typing
Type "apa" Sleep 800ms Enter
Sleep 700ms

# Multiline description, Ctrl+D to submit
Type "A tiny rover that" Sleep 300ms Enter
Type "goes to Mars." Sleep 600ms Ctrl+D
Sleep 700ms

# Confirm
Left Sleep 500ms Right Sleep 500ms Enter

# Tasks, progress bar, note, outro
Sleep 4.5s
Sleep 3s
