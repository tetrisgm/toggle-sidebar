// Prints the base64 BTTIfConditionData for a BetterTouchTool "IF Condition" (action 330) format string.
// usage: swiftc -O pred.swift -o pred && ./pred "focused_window_width > 100"
import Foundation
let p = NSPredicate(format: CommandLine.arguments[1])
print(try! NSKeyedArchiver.archivedData(withRootObject: p, requiringSecureCoding: false).base64EncodedString())
