import Foundation
import CitadelCore

@main
struct CitadelEntry {
    static func main() async {
        if #available(macOS 14.0, *) {
            await CitadelCLI.main()
        }
    }
}
