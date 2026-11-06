import Foundation
import CitadelCore

@main
struct CtdlEntry {
    static func main() async {
        if #available(macOS 14.0, *) {
            await CitadelCLI.main()
        }
    }
}
