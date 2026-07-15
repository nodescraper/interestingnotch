import AppKit
import Combine
import Foundation
import Darwin

@MainActor
final class CustomPeekWatcher: ObservableObject {
    static let shared = CustomPeekWatcher()

    @Published private(set) var currentPeek: CustomPeek?
    @Published private(set) var activePeeks: [CustomPeek] = []
    @Published private(set) var availablePeeks: [CustomPeek] = []
    @Published private(set) var isWatching = false
    @Published private(set) var lastEventDate: Date?
    @Published private(set) var parseErrors: [String: String] = [:]

    let folderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".interestingnotch/peeks", isDirectory: true)

    private var source: DispatchSourceFileSystemObject?
    private var directoryDescriptor: Int32 = -1
    private var expiryTasks: [String: Task<Void, Never>] = [:]
    private var popUpTasks: [String: Task<Void, Never>] = [:]
    private var hiddenPopUps: Set<String> = []
    private var fileDates: [String: Date] = [:]

    private init() {}

    func enable() {
        guard !isWatching else { rescan(); return }
        do { try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true) }
        catch { parseErrors["folder"] = "Could not create peeks folder: \(error.localizedDescription)"; return }

        directoryDescriptor = open(folderURL.path, O_EVTONLY)
        guard directoryDescriptor >= 0 else { parseErrors["folder"] = "Could not watch the peeks folder."; return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryDescriptor, eventMask: [.write, .extend, .attrib, .rename, .delete], queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.lastEventDate = Date()
                self?.rescan()
            }
        }
        let descriptor = directoryDescriptor
        source.setCancelHandler { close(descriptor) }
        self.source = source
        isWatching = true
        source.resume()
        rescan()
    }

    func disable() {
        source?.cancel(); source = nil
        directoryDescriptor = -1
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
        popUpTasks.values.forEach { $0.cancel() }
        popUpTasks.removeAll()
        hiddenPopUps.removeAll()
        isWatching = false
        activePeeks = []; availablePeeks = []; currentPeek = nil; parseErrors = [:]; fileDates = [:]
    }

    func preferencesDidChange() {
        for peek in availablePeeks {
            if CustomPeekPreferences.shared.preference(for: peek).displayMode == .popUp {
                hiddenPopUps.remove(peek.id)
                schedulePopUpExpiry(for: peek)
            } else {
                popUpTasks.removeValue(forKey: peek.id)?.cancel()
                hiddenPopUps.remove(peek.id)
            }
        }
        rescan()
    }

    func rescan() {
        guard isWatching else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        var next: [String: CustomPeek] = [:]
        var nextErrors: [String: String] = [:]
        var nextDates: [String: Date] = [:]
        for file in files where file.pathExtension.lowercased() == "json" {
            let id = file.deletingPathExtension().lastPathComponent
            do {
                let data = try Data(contentsOf: file)
                let peek = try CustomPeek.parse(data: data, id: id)
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                next[id] = peek; nextDates[id] = date
                if fileDates[id] != date {
                    hiddenPopUps.remove(id)
                    scheduleExpiry(for: peek)
                    schedulePopUpExpiry(for: peek)
                }
            } catch let error as CustomPeek.ParseError { nextErrors[id] = error.localizedDescription }
            catch { nextErrors[id] = "Could not read JSON: \(error.localizedDescription)" }
        }
        expiryTasks.keys.filter { next[$0] == nil }.forEach { expiryTasks.removeValue(forKey: $0)?.cancel() }
        popUpTasks.keys.filter { next[$0] == nil }.forEach { popUpTasks.removeValue(forKey: $0)?.cancel() }
        fileDates = nextDates
        parseErrors = nextErrors
        hiddenPopUps = hiddenPopUps.intersection(next.keys)
        availablePeeks = next.values.sorted { (nextDates[$0.id] ?? .distantPast) > (nextDates[$1.id] ?? .distantPast) }
        activePeeks = availablePeeks.filter { peek in
            let preference = CustomPeekPreferences.shared.preference(for: peek)
            return preference.isEnabled && !hiddenPopUps.contains(peek.id)
        }
        currentPeek = activePeeks.first
    }

    private func scheduleExpiry(for peek: CustomPeek) {
        expiryTasks[peek.id]?.cancel()
        guard let duration = peek.duration else { return }
        expiryTasks[peek.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            try? FileManager.default.removeItem(at: self?.folderURL.appendingPathComponent("\(peek.id).json") ?? URL(fileURLWithPath: "/dev/null"))
            self?.rescan()
        }
    }

    private func schedulePopUpExpiry(for peek: CustomPeek) {
        popUpTasks[peek.id]?.cancel()
        let preference = CustomPeekPreferences.shared.preference(for: peek)
        guard preference.displayMode == .popUp else { return }
        let duration = max(0.5, preference.popUpDuration)
        popUpTasks[peek.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.hiddenPopUps.insert(peek.id)
            self?.rescan()
        }
    }
}
