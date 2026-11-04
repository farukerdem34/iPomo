import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter {
    ($0[kCGWindowOwnerName as String] as? String) == "iPomo"
}

for window in matches {
    let bounds = window[kCGWindowBounds as String] ?? ""
    let alpha = window[kCGWindowAlpha as String] ?? ""
    print("iPomo window bounds=\(bounds) alpha=\(alpha)")
}

if matches.isEmpty {
    print("No iPomo windows found")
    exit(1)
}
print("Found \(matches.count) iPomo window(s)")
