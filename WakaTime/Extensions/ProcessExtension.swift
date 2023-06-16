import Foundation

extension Process {
    // Runs process.launch() prior to macOS 13 or process.run() on macOS 13 or newer.
    // Adds Swift exception handling to process.launch().
    func execute() throws {
        if #available(macOS 13.0, *) {
            // Use Process.run() on macOS 13 or newer. Process.run() throws Swift exceptions.
            try self.run()
        } else {
            // Note: Process.launch() can throw ObjC exceptions. For further reference, see
            // https://developer.apple.com/documentation/foundation/process/1414189-launch?changes=_3
            try ObjC.catchException { self.launch() }
        }
    }
}
