//
//  FileConverterWidgetModel.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-17.
//

import AppKit
import Foundation
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum FileConverterWidgetError: LocalizedError, Equatable {
    case unsupportedType
    case unreadableFile
    case missingSourceImage
    case missingSourcePDF
    case missingTargetExtension
    case noPDFPages
    case directoryOutputNotSupported

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "That file type is not supported yet."
        case .unreadableFile:
            return "We couldn't read that file."
        case .missingSourceImage:
            return "We couldn't decode the source image."
        case .missingSourcePDF:
            return "We couldn't open the PDF."
        case .missingTargetExtension:
            return "That export format is unavailable."
        case .noPDFPages:
            return "This PDF has no pages to export."
        case .directoryOutputNotSupported:
            return "That export result couldn't be prepared."
        }
    }
}

protocol FileConverter {
    func supportedTargets(for inputType: UTType) -> [UTType]
    func convert(url: URL, to targetType: UTType, outputBaseName: String) async throws -> URL
}

extension UTType {
    static var interestingWebP: UTType? {
        UTType(filenameExtension: "webp")
    }

    static var interestingMarkdown: UTType? {
        UTType(filenameExtension: "md")
    }

    var interestingDisplayName: String {
        switch self {
        case .jpeg:
            return "JPG"
        case .png:
            return "PNG"
        case .heic:
            return "HEIC"
        case .pdf:
            return "PDF"
        case .tiff:
            return "TIFF"
        case .gif:
            return "GIF"
        case .bmp:
            return "BMP"
        case .plainText:
            return "TXT"
        case .rtf:
            return "RTF"
        case .html:
            return "HTML"
        default:
            if let md = UTType.interestingMarkdown, self == md {
                return "Markdown"
            }
            if let webp = UTType.interestingWebP, self == webp {
                return "WebP"
            }
            return preferredFilenameExtension?.uppercased() ?? localizedDescription ?? identifier
        }
    }
}

private enum FileConverterImageTargets {
    static var preferred: [UTType] {
        var values: [UTType] = [.jpeg, .png, .heic]
        if let webp = UTType.interestingWebP {
            values.append(webp)
        }
        values.append(.tiff)
        values.append(.pdf)
        return values
    }
}

struct ImageConverter: FileConverter {
    func supportedTargets(for inputType: UTType) -> [UTType] {
        guard inputType.conforms(to: .image) else { return [] }
        return FileConverterImageTargets.preferred.filter { $0 != inputType }
    }

    func convert(url: URL, to targetType: UTType, outputBaseName: String) async throws -> URL {
        if targetType == .pdf {
            return try convertImageToPDF(url: url, outputBaseName: outputBaseName)
        }

        return try convertImage(url: url, to: targetType, outputBaseName: outputBaseName)
    }

    private func convertImage(url: URL, to targetType: UTType, outputBaseName: String) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FileConverterWidgetError.missingSourceImage
        }

        let outputURL = FileConverterWorkspace.makeTemporaryOutputURL(
            named: outputBaseName,
            targetType: targetType
        )

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            targetType.identifier as CFString,
            1,
            nil
        ) else {
            throw FileConverterWidgetError.missingTargetExtension
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw FileConverterWidgetError.unreadableFile
        }

        return outputURL
    }

    private func convertImageToPDF(url: URL, outputBaseName: String) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FileConverterWidgetError.missingSourceImage
        }

        let outputURL = FileConverterWorkspace.makeTemporaryOutputURL(
            named: outputBaseName,
            targetType: .pdf
        )

        var mediaBox = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let consumer = CGDataConsumer(url: outputURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw FileConverterWidgetError.unreadableFile
        }

        context.beginPDFPage(nil)
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        context.closePDF()

        return outputURL
    }
}

struct PDFConverter: FileConverter {
    func supportedTargets(for inputType: UTType) -> [UTType] {
        guard inputType.conforms(to: .pdf) else { return [] }
        return [.png, .jpeg, .tiff]
    }

    func convert(url: URL, to targetType: UTType, outputBaseName: String) async throws -> URL {
        guard targetType == .png || targetType == .jpeg || targetType == .tiff else {
            throw FileConverterWidgetError.unsupportedType
        }

        guard let document = PDFDocument(url: url) else {
            throw FileConverterWidgetError.missingSourcePDF
        }

        guard document.pageCount > 0 else {
            throw FileConverterWidgetError.noPDFPages
        }

        if document.pageCount == 1, let page = document.page(at: 0) {
            return try exportSinglePage(page, targetType: targetType, outputBaseName: outputBaseName)
        }

        return try exportPageDirectory(document, targetType: targetType, outputBaseName: outputBaseName)
    }

    private func exportSinglePage(_ page: PDFPage, targetType: UTType, outputBaseName: String) throws -> URL {
        let image = try render(page: page)
        let outputURL = FileConverterWorkspace.makeTemporaryOutputURL(named: outputBaseName, targetType: targetType)
        try write(nsImage: image, to: outputURL, targetType: targetType)
        return outputURL
    }

    private func exportPageDirectory(_ document: PDFDocument, targetType: UTType, outputBaseName: String) throws -> URL {
        let folderURL = FileConverterWorkspace.makeTemporaryDirectoryURL(named: "\(outputBaseName)-pages")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

        let ext = targetType.preferredFilenameExtension ?? "png"
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let image = try render(page: page)
            let fileURL = folderURL.appendingPathComponent(
                String(format: "%@-%02d.%@", outputBaseName, pageIndex + 1, ext),
                isDirectory: false
            )
            try write(nsImage: image, to: fileURL, targetType: targetType)
        }

        return folderURL
    }

    private func render(page: PDFPage) throws -> NSImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let pixelSize = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))

        let image = NSImage(size: pixelSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            throw FileConverterWidgetError.unreadableFile
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pixelSize))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return image
    }

    private func write(nsImage: NSImage, to outputURL: URL, targetType: UTType) throws {
        guard
            let tiffData = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            throw FileConverterWidgetError.unreadableFile
        }

        let data: Data?
        switch targetType {
        case .jpeg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .tiff:
            data = bitmap.representation(using: .tiff, properties: [:])
        default:
            data = nil
        }

        guard let data else {
            throw FileConverterWidgetError.unsupportedType
        }

        try data.write(to: outputURL, options: .atomic)
    }
}

/// Native text/document conversions via NSAttributedString + Core Text.
/// Handles txt / rtf / html / markdown inter-conversion and → PDF. No
/// dependencies. (EPUB / docx are intentionally out — they need an engine.)
struct TextConverter: FileConverter {
    private static let readableTypes: [UTType] = {
        var types: [UTType] = [.plainText, .rtf, .html]
        if let md = UTType.interestingMarkdown { types.append(md) }
        return types
    }()

    private static var writableTargets: [UTType] {
        [.plainText, .rtf, .html, .pdf]
    }

    static func canRead(_ type: UTType) -> Bool {
        if readableTypes.contains(where: { type == $0 || type.conforms(to: $0) }) {
            return true
        }
        if let md = UTType.interestingMarkdown, type == md {
            return true
        }
        return false
    }

    func supportedTargets(for inputType: UTType) -> [UTType] {
        guard Self.canRead(inputType) else { return [] }
        return Self.writableTargets.filter { $0 != inputType }
    }

    func convert(url: URL, to targetType: UTType, outputBaseName: String) async throws -> URL {
        let attributed = try Self.readAttributedString(from: url)

        if targetType == .pdf {
            return try Self.writePDF(attributed, outputBaseName: outputBaseName)
        }
        return try Self.writeText(attributed, to: targetType, outputBaseName: outputBaseName)
    }

    // MARK: Read

    private static func readAttributedString(from url: URL) throws -> NSAttributedString {
        let ext = url.pathExtension.lowercased()

        // Markdown via the native initializer.
        if ext == "md" || ext == "markdown" {
            if let data = try? Data(contentsOf: url),
               let string = String(data: data, encoding: .utf8),
               let attributed = try? NSAttributedString(
                   markdown: string,
                   options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
               ) {
                return attributed
            }
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any]
        switch ext {
        case "rtf":
            options = [.documentType: NSAttributedString.DocumentType.rtf]
        case "html", "htm":
            options = [.documentType: NSAttributedString.DocumentType.html]
        default:
            options = [.documentType: NSAttributedString.DocumentType.plain]
        }

        guard let data = try? Data(contentsOf: url) else {
            throw FileConverterWidgetError.unreadableFile
        }

        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed
        }

        if let string = String(data: data, encoding: .utf8) {
            return NSAttributedString(string: string)
        }

        throw FileConverterWidgetError.unreadableFile
    }

    // MARK: Write

    private static func writeText(
        _ attributed: NSAttributedString,
        to targetType: UTType,
        outputBaseName: String
    ) throws -> URL {
        let docType: NSAttributedString.DocumentType
        switch targetType {
        case .rtf:  docType = .rtf
        case .html: docType = .html
        default:    docType = .plain
        }

        let range = NSRange(location: 0, length: attributed.length)
        guard let data = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: docType]
        ) else {
            throw FileConverterWidgetError.unreadableFile
        }

        let outputURL = FileConverterWorkspace.makeTemporaryOutputURL(
            named: outputBaseName,
            targetType: targetType
        )
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func writePDF(
        _ attributed: NSAttributedString,
        outputBaseName: String
    ) throws -> URL {
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let margin: CGFloat = 72                        // 1 inch
        let textRect = CGRect(
            x: margin, y: margin,
            width: pageSize.width - margin * 2,
            height: pageSize.height - margin * 2
        )

        // An empty document still produces one blank page rather than looping.
        let source: NSAttributedString = attributed.length > 0
            ? attributed
            : NSAttributedString(string: " ")

        let framesetter = CTFramesetterCreateWithAttributedString(source as CFAttributedString)
        let outputURL = FileConverterWorkspace.makeTemporaryOutputURL(named: outputBaseName, targetType: .pdf)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: outputURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw FileConverterWidgetError.unreadableFile
        }

        let path = CGPath(rect: textRect, transform: nil)
        var location = 0
        let total = source.length

        repeat {
            context.beginPDFPage(nil)

            // Core Text draws in the PDF's native bottom-up space and orients
            // glyphs correctly on its own. Do NOT flip the context here — a
            // manual translate/scale flip renders the whole page upside down.
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)

            let visible = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage()

            // Guard against zero-progress to avoid an infinite loop.
            if visible.length <= 0 { break }
            location += visible.length
        } while location < total

        context.closePDF()
        return outputURL
    }
}

struct FileConverterRegistry {
    private let imageConverter = ImageConverter()
    private let pdfConverter = PDFConverter()
    private let textConverter = TextConverter()

    func supportedConfiguration(for fileURL: URL) -> SupportedConfiguration? {
        guard let inputType = FileConverterWorkspace.contentType(for: fileURL) else { return nil }

        // PDF first.
        if inputType.conforms(to: .pdf) {
            let targets = pdfConverter.supportedTargets(for: inputType)
            guard let target = smartDefaultTarget(for: inputType, targets: targets, fileURL: fileURL) else { return nil }
            return SupportedConfiguration(inputType: inputType, converter: pdfConverter, targets: targets, smartDefault: target)
        }

        // Text / documents before image (some text types incidentally conform elsewhere).
        if TextConverter.canRead(inputType) || isMarkdown(fileURL) {
            let effectiveType = isMarkdown(fileURL) ? (UTType.interestingMarkdown ?? inputType) : inputType
            let targets = textConverter.supportedTargets(for: effectiveType)
            guard !targets.isEmpty,
                  let target = smartDefaultTarget(for: effectiveType, targets: targets, fileURL: fileURL) else { return nil }
            return SupportedConfiguration(inputType: effectiveType, converter: textConverter, targets: targets, smartDefault: target)
        }

        if inputType.conforms(to: .image) {
            let targets = imageConverter.supportedTargets(for: inputType)
            guard let target = smartDefaultTarget(for: inputType, targets: targets, fileURL: fileURL) else { return nil }
            return SupportedConfiguration(inputType: inputType, converter: imageConverter, targets: targets, smartDefault: target)
        }

        return nil
    }

    private func isMarkdown(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    private func smartDefaultTarget(for inputType: UTType, targets: [UTType], fileURL: URL) -> UTType? {
        // PDF → PNG
        if inputType.conforms(to: .pdf) {
            return targets.first(where: { $0 == .png }) ?? targets.first
        }

        // Text / document smart defaults.
        if isMarkdown(fileURL) {
            return targets.first(where: { $0 == .html }) ?? targets.first   // md → HTML
        }
        if inputType == .plainText {
            return targets.first(where: { $0 == .pdf }) ?? targets.first     // txt → PDF
        }
        if inputType == .rtf {
            return targets.first(where: { $0 == .pdf }) ?? targets.first     // rtf → PDF
        }
        if inputType == .html {
            return targets.first(where: { $0 == .pdf }) ?? targets.first     // html → PDF
        }

        // Image smart defaults.
        if inputType == .png {
            return targets.first(where: { $0 == .jpeg }) ?? targets.first
        }
        if inputType == .jpeg {
            return targets.first(where: { $0 == .png }) ?? targets.first
        }
        if inputType == .heic {
            return targets.first(where: { $0 == .jpeg }) ?? targets.first
        }
        if inputType == .gif || inputType == .bmp {
            return targets.first(where: { $0 == .png }) ?? targets.first
        }
        if let webp = UTType.interestingWebP, inputType == webp {
            return targets.first(where: { $0 == .png }) ?? targets.first
        }

        return targets.first(where: { $0 == .jpeg }) ?? targets.first
    }

    struct SupportedConfiguration {
        let inputType: UTType
        let converter: any FileConverter
        let targets: [UTType]
        let smartDefault: UTType
    }
}

enum FileConverterWorkspace {
    static func contentType(for fileURL: URL) -> UTType? {
        if let type = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        if let ext = fileURL.pathExtension.nilIfEmpty {
            return UTType(filenameExtension: ext)
        }
        return nil
    }

    static func makeTemporaryOutputURL(named baseName: String, targetType: UTType) -> URL {
        let ext = targetType.preferredFilenameExtension ?? "dat"
        let root = uniqueTemporaryRoot()
        return root.appendingPathComponent("\(sanitize(baseName)).\(ext)", isDirectory: false)
    }

    static func makeTemporaryDirectoryURL(named baseName: String) -> URL {
        uniqueTemporaryRoot().appendingPathComponent(sanitize(baseName), isDirectory: true)
    }

    static func uniqueDownloadsDestination(for sourceURL: URL) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)

        let ext = sourceURL.pathExtension
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        let sanitizedStem = sanitize(stem)
        let isDirectory = sourceURL.hasDirectoryPath
        let baseCandidate = downloads.appendingPathComponent(
            ext.isEmpty ? sanitizedStem : "\(sanitizedStem).\(ext)",
            isDirectory: isDirectory
        )

        if !FileManager.default.fileExists(atPath: baseCandidate.path) {
            return baseCandidate
        }

        var index = 2
        while true {
            let candidate = downloads.appendingPathComponent(
                ext.isEmpty ? "\(sanitizedStem) \(index)" : "\(sanitizedStem) \(index).\(ext)",
                isDirectory: isDirectory
            )
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    static func copyResultToDownloads(_ resultURL: URL) throws -> URL {
        let destinationURL = uniqueDownloadsDestination(for: resultURL)
        try FileManager.default.copyItem(at: resultURL, to: destinationURL)
        return destinationURL
    }

    static func byteCount(for url: URL) -> Int64 {
        if url.hasDirectoryPath {
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
            var total: Int64 = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                total += Int64(size)
            }
            return total
        }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
    }

    private static func uniqueTemporaryRoot() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("InterestingNotch-FileConverter", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        return root
    }

    static func sanitize(_ baseName: String) -> String {
        let cleaned = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = cleaned.isEmpty ? "converted-file" : cleaned
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return fallback.components(separatedBy: invalid).joined(separator: "-")
    }
}

struct FileConverterLoadedFile {
    let sourceURL: URL
    let inputType: UTType
    let targetOptions: [UTType]
    let thumbnail: NSImage?
    let iconName: String
    var selectedTarget: UTType

    var filename: String { sourceURL.lastPathComponent }
    var sourceDisplayName: String { inputType.interestingDisplayName }
    var targetDisplayName: String { selectedTarget.interestingDisplayName }
    var conversionLabel: String { "\(sourceDisplayName) → \(targetDisplayName)" }
    var outputBaseName: String { sourceURL.deletingPathExtension().lastPathComponent }
}

struct FileConverterOutput: Equatable {
    let outputURL: URL
    let sizeDescription: String
    let savedDescription: String
    let isDirectory: Bool

    var filename: String { outputURL.lastPathComponent }
}

enum FileConverterState {
    case idle
    case loaded(FileConverterLoadedFile)
    case converting(FileConverterLoadedFile)
    case done(FileConverterOutput)
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

@MainActor
final class FileConverterWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .fileConverter
    let widgetID: String

    @Published var state: FileConverterState = .idle
    @Published var isDropTargeted = false
    @Published var inlineErrorMessage: String?
    @Published var showsTargetOptions = false

    private let registry = FileConverterRegistry()

    init(widgetID: String) {
        self.widgetID = widgetID
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let first = providers.first else { return false }

        Task { [weak self] in
            guard let self else { return }
            do {
                let primaryFileURL = await first.extractFileURL()
                let fileURL: URL?
                if let primaryFileURL {
                    fileURL = primaryFileURL
                } else {
                    fileURL = await first.extractItem()
                }
                guard let fileURL else {
                    throw FileConverterWidgetError.unreadableFile
                }
                try await self.load(fileURL: fileURL)
            } catch {
                self.failInline(message: error.localizedDescription)
            }
        }

        return true
    }

    func load(fileURL: URL) async throws {
        guard let supported = registry.supportedConfiguration(for: fileURL) else {
            throw FileConverterWidgetError.unsupportedType
        }

        let thumbnail = makeThumbnail(for: fileURL, inputType: supported.inputType)
        let iconName = iconName(for: supported.inputType)
        let loaded = FileConverterLoadedFile(
            sourceURL: fileURL,
            inputType: supported.inputType,
            targetOptions: supported.targets,
            thumbnail: thumbnail,
            iconName: iconName,
            selectedTarget: supported.smartDefault
        )

        inlineErrorMessage = nil
        showsTargetOptions = false
        withAnimation(Self.stageSpring) {
            state = .loaded(loaded)
        }
    }

    func selectTarget(_ target: UTType) {
        guard case .loaded(var loaded) = state else { return }
        loaded.selectedTarget = target
        withAnimation(Self.stageSpring) {
            state = .loaded(loaded)
        }
    }

    func setShowsTargetOptions(_ show: Bool) {
        withAnimation(Self.stageSpring) {
            showsTargetOptions = show
        }
    }

    func reset() {
        inlineErrorMessage = nil
        showsTargetOptions = false
        withAnimation(Self.stageSpring) {
            state = .idle
        }
    }

    func convert() {
        guard case .loaded(let loaded) = state else { return }

        withAnimation(Self.stageSpring) {
            state = .converting(loaded)
            showsTargetOptions = false
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                guard let supported = self.registry.supportedConfiguration(for: loaded.sourceURL) else {
                    throw FileConverterWidgetError.unsupportedType
                }

                let temporaryOutput = try await supported.converter.convert(
                    url: loaded.sourceURL,
                    to: loaded.selectedTarget,
                    outputBaseName: loaded.outputBaseName
                )

                // Try Downloads; if the sandbox/permission blocks it, keep the
                // temp result so the user can still reveal/drag it rather than
                // seeing a hard failure.
                let savedURL: URL
                let savedDescription: String
                do {
                    savedURL = try FileConverterWorkspace.copyResultToDownloads(temporaryOutput)
                    savedDescription = "saved to Downloads"
                } catch {
                    savedURL = temporaryOutput
                    savedDescription = "ready — reveal to save"
                }

                let bytes = FileConverterWorkspace.byteCount(for: savedURL)
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file

                let output = FileConverterOutput(
                    outputURL: savedURL,
                    sizeDescription: formatter.string(fromByteCount: bytes),
                    savedDescription: savedDescription,
                    isDirectory: temporaryOutput.hasDirectoryPath
                )

                self.inlineErrorMessage = nil
                withAnimation(Self.stageSpring) {
                    self.state = .done(output)
                }
            } catch {
                self.failInline(message: error.localizedDescription)
            }
        }
    }

    func revealInFinder() {
        guard case .done(let output) = state else { return }
        NSWorkspace.shared.activateFileViewerSelecting([output.outputURL])
    }

    func openOutput() {
        guard case .done(let output) = state else { return }
        NSWorkspace.shared.open(output.outputURL)
    }

    private func failInline(message: String) {
        inlineErrorMessage = message
        showsTargetOptions = false
        withAnimation(Self.stageSpring) {
            state = .idle
        }
    }

    private func makeThumbnail(for fileURL: URL, inputType: UTType) -> NSImage? {
        if inputType.conforms(to: .pdf), let document = PDFDocument(url: fileURL), let page = document.page(at: 0) {
            return page.thumbnail(of: CGSize(width: 56, height: 56), for: .mediaBox)
        }

        if inputType.conforms(to: .image), let image = NSImage(contentsOf: fileURL) {
            return image
        }

        return nil
    }

    private func iconName(for inputType: UTType) -> String {
        if inputType.conforms(to: .pdf) {
            return "doc.richtext"
        }
        if inputType.conforms(to: .image) {
            return "photo"
        }
        if TextConverter.canRead(inputType) {
            return "doc.text"
        }
        return "doc"
    }

    static let stageSpring = Animation.spring(response: 0.4, dampingFraction: 0.82)
}
