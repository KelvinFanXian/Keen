import Foundation

final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var pending: DispatchWorkItem?

    init(url: URL, callback: @escaping () -> Void) {
        self.url = url
        self.callback = callback
        start()
    }

    deinit { stop() }

    private func start() {
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.scheduleRefresh(events: self.source?.data ?? [])
        }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        self.source = source
        source.resume()
    }

    private func scheduleRefresh(events: DispatchSource.FileSystemEvent) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.callback()
            if events.contains(.rename) || events.contains(.delete) {
                self.stop()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.start() }
            }
        }
        pending = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    private func stop() {
        pending?.cancel()
        source?.cancel()
        source = nil
        descriptor = -1
    }
}
