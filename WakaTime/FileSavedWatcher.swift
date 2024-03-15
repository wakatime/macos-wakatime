class FileMonitor {
    private let fileURL: URL
    private var dispatchObject: DispatchSourceFileSystemObject?

    public var fileChangedEventHandler: (() -> Void)?

    init?(filePath: URL, queue: DispatchQueue) {
        self.fileURL = filePath
        let folderURL = fileURL.deletingLastPathComponent() // monitor enclosing folder to track changes by Xcode
        let descriptor = open(folderURL.path, O_EVTONLY)
        guard descriptor >= -1 else { Logging.default.log("open failed: \(descriptor)"); return nil }
        dispatchObject = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        dispatchObject?.setEventHandler { [weak self] in
            self?.fileChangedEventHandler?()
        }
        dispatchObject?.setCancelHandler {
            close(descriptor)
        }
        dispatchObject?.activate()
    }

    deinit {
        dispatchObject?.cancel()
    }
}
