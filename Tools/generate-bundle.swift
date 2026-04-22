#!/usr/bin/env swift
/// Generates three resource bundles for Shellbee from a zigbee2mqtt.io clone:
///
///   Shellbee/Resources/device_docs.lzfse    — full markdown per device (doc renderer)
///   Shellbee/Resources/device_index.lzfse   — compact JSON index (Device Library browser)
///   Shellbee/Resources/device_images.lzfse  — 80×80 PNG thumbnails (Device Library rows)
///
/// Run from the Shellbee repo root:
///   swift Tools/generate-bundle.swift
///   swift Tools/generate-bundle.swift --force
///   swift Tools/generate-bundle.swift [--force] /path/to/zigbee2mqtt.io
///
/// On the first run (or if the repo path doesn't exist) the script clones
/// https://github.com/Koenkk/zigbee2mqtt.io automatically. Subsequent runs
/// pull the latest changes and skip regeneration if nothing changed (unless
/// --force is passed).

import Foundation
import ImageIO
import CoreGraphics

// MARK: - Configuration

let repoRemote      = "https://github.com/Koenkk/zigbee2mqtt.io"
let defaultRepoPath = "\(NSHomeDirectory())/Tools/ReferenceProjects/zigbee2mqtt.io"
let resourcesDir    = "Shellbee/Resources"
let hashFile        = "Tools/.bundle-hash"
let thumbnailPx     = 80           // pixels — matches @2× of summaryRowSymbolFrame (36 pt)

// MARK: - Argument parsing

var forceRebuild = false
var repoPath     = defaultRepoPath

for arg in CommandLine.arguments.dropFirst() {
    if arg == "--force"      { forceRebuild = true }
    else if arg.hasPrefix("/") { repoPath = arg }
}

// MARK: - Utilities

let fm = FileManager.default

func die(_ msg: String) -> Never {
    fputs("\n❌ \(msg)\n", stderr)
    exit(1)
}

@discardableResult
func sh(_ exe: String, _ args: String..., quiet: Bool = false) -> (output: String, ok: Bool) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: exe)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError  = quiet ? Pipe() : pipe
    try? proc.run()
    proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (out, proc.terminationStatus == 0)
}

func writeBundle<T: Encodable>(_ value: T, to path: String, label: String, format: PropertyListSerialization.PropertyListFormat = .binary) {
    // Use binary plist so Data values are stored as raw bytes (no base64 overhead)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = format
    guard let raw        = try? encoder.encode(value)                                else { die("Encode failed: \(label)") }
    guard let compressed = try? (raw as NSData).compressed(using: .lzfse) as Data   else { die("Compress failed: \(label)") }
    let url = URL(fileURLWithPath: path)
    try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard (try? compressed.write(to: url, options: .atomic)) != nil                 else { die("Write failed: \(path)") }
    let mb    = { (n: Int) in String(format: "%.2f MB", Double(n) / 1_048_576) }
    let ratio = String(format: "%.1f×", Double(raw.count) / Double(compressed.count))
    print("  ✓ \(label): \(mb(raw.count)) → \(mb(compressed.count)) (\(ratio))  [\(path)]")
}

// MARK: - Phase 0: Verify working directory

guard fm.fileExists(atPath: "Shellbee.xcodeproj") else {
    die("Run this script from the Shellbee repo root (where Shellbee.xcodeproj lives).")
}
print("Working directory: \(fm.currentDirectoryPath)")

// MARK: - Phase 1: Sync repository

print("\n── Syncing zigbee2mqtt.io ─────────────────────────────────────────────")

if fm.fileExists(atPath: "\(repoPath)/.git") {
    print("Pulling \(repoRemote)…")
    let result = sh("/usr/bin/git", "-C", repoPath, "pull", "--ff-only")
    print(result.output.isEmpty ? "(already up to date)" : result.output)
    if !result.ok { die("git pull failed. Resolve conflicts in \(repoPath) manually.") }
} else {
    print("Cloning \(repoRemote)…")
    let parent = URL(fileURLWithPath: repoPath).deletingLastPathComponent().path
    try? fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
    let result = sh("/usr/bin/git", "clone", "--depth=1", repoRemote, repoPath)
    if !result.ok { die("git clone failed:\n\(result.output)") }
    print("Cloned to \(repoPath)")
}

// MARK: - Phase 2: Change detection

let currentHash = sh("/usr/bin/git", "-C", repoPath, "rev-parse", "HEAD", quiet: true).output
let storedHash  = (try? String(contentsOfFile: hashFile, encoding: .utf8))?
                      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

print("Repo HEAD: \(currentHash.prefix(12))")

if !forceRebuild && currentHash == storedHash {
    print("\n✓ Nothing changed since last run (hash \(currentHash.prefix(12))).")
    print("  Pass --force to rebuild anyway.\n")
    exit(0)
}

if !storedHash.isEmpty {
    print("Previous: \(storedHash.prefix(12)) → New: \(currentHash.prefix(12))")
}

// MARK: - Phase 3: Device docs bundle

print("\n── Device docs ────────────────────────────────────────────────────────")

let devicesDocDir = URL(fileURLWithPath: "\(repoPath)/docs/devices")
let imagesDir     = URL(fileURLWithPath: "\(repoPath)/public/images/devices")

guard let allFiles = try? fm.contentsOfDirectory(at: devicesDocDir, includingPropertiesForKeys: nil) else {
    die("Cannot read \(devicesDocDir.path)")
}

let mdFiles = allFiles.filter { $0.pathExtension == "md" }
print("Reading \(mdFiles.count) markdown files…")

var docs: [String: String] = [:]
for file in mdFiles {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
    docs[file.deletingPathExtension().lastPathComponent] = text
}
print("Loaded \(docs.count) docs")

writeBundle(docs, to: "\(resourcesDir)/device_docs.lzfse", label: "docs")

// MARK: - Phase 4: Device index

print("\n── Device index ───────────────────────────────────────────────────────")

let readmeURL = URL(fileURLWithPath: "\(repoPath)/docs/supported-devices/README.md")
guard let readmeText = try? String(contentsOf: readmeURL, encoding: .utf8) else {
    die("Cannot read supported-devices/README.md")
}

let pattern = "window\\.ZIGBEE2MQTT_SUPPORTED_DEVICES = (\\[.*?\\]);"
guard
    let regex      = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
    let match      = regex.firstMatch(in: readmeText, range: NSRange(readmeText.startIndex..., in: readmeText)),
    let jsonRange  = Range(match.range(at: 1), in: readmeText),
    let jsonData   = readmeText[jsonRange].data(using: .utf8),
    let rawDevices = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
else {
    die("Cannot parse supported-devices JSON from README.md")
}

print("Supported-devices entries: \(rawDevices.count)")

struct IndexEntry: Codable {
    let docKey:      String   // markdown filename stem — used as image bundle key
    let imageKey:    String   // image filename stem from JSON `image` field
    let model:       String
    let vendor:      String
    let description: String
    let exposes:     [String]
}

var index: [IndexEntry] = []

for raw in rawDevices {
    guard
        let model       = raw["model"]       as? String,
        let vendor      = raw["vendor"]      as? String,
        let description = raw["description"] as? String,
        let link        = raw["link"]        as? String,
        let exposes     = raw["exposes"]     as? [String]
    else { continue }

    // e.g. "../devices/FL_230_C.html" → "FL_230_C"
    let docKey = URL(fileURLWithPath: link).deletingPathExtension().lastPathComponent

    // Only include entries that have a documentation page
    guard docs[docKey] != nil else { continue }

    // e.g. "../images/devices/FL-230-C.png" → "FL-230-C"
    let imageKey: String
    if let imgField = raw["image"] as? String {
        imageKey = URL(fileURLWithPath: imgField).deletingPathExtension().lastPathComponent
    } else {
        // Fallback: match the sanitization used in Device+Images.swift
        imageKey = model
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    index.append(IndexEntry(
        docKey: docKey, imageKey: imageKey, model: model,
        vendor: vendor, description: description, exposes: exposes
    ))
}

print("Index entries with docs: \(index.count)")
writeBundle(index, to: "\(resourcesDir)/device_index.lzfse", label: "index")

// MARK: - Phase 5: Image thumbnails

print("\n── Device images ──────────────────────────────────────────────────────")
print("Generating \(thumbnailPx)×\(thumbnailPx) PNG thumbnails (preserving transparency)…")

func makeThumbnail(from url: URL) -> Data? {
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform:   true,
        kCGImageSourceThumbnailMaxPixelSize:           thumbnailPx
    ]
    guard
        let src   = CGImageSourceCreateWithURL(url as CFURL, nil),
        let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    else { return nil }

    let out = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, thumb, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return out as Data
}

// Keyed by imageKey (the image filename stem, e.g. "FL-230-C") so Device objects
// can look up bundled images directly using the same sanitization as Device+Images.swift.
var images: [String: Data] = [:]
var missing  = 0
var failures = 0
let total    = index.count

for (i, entry) in index.enumerated() {
    // Print progress on a rewriting line
    if i % 100 == 0 || i == total - 1 {
        let pct = Int(Double(i + 1) / Double(total) * 100)
        print("  \(i + 1)/\(total) (\(pct)%)…", terminator: "\r")
        fflush(stdout)
    }

    // Prefer PNG; fall back to JPG
    let pngURL = imagesDir.appendingPathComponent("\(entry.imageKey).png")
    let jpgURL = imagesDir.appendingPathComponent("\(entry.imageKey).jpg")
    guard let imgURL = fm.fileExists(atPath: pngURL.path) ? pngURL
                     : fm.fileExists(atPath: jpgURL.path) ? jpgURL
                     : nil
    else { missing += 1; continue }

    guard let data = makeThumbnail(from: imgURL) else { failures += 1; continue }
    images[entry.imageKey] = data
}

print()  // newline after the \r progress line

let rawBytes  = images.values.reduce(0) { $0 + $1.count }
print("Generated: \(images.count)  Missing: \(missing)  Failed: \(failures)")
print("Raw thumbnail data: \(String(format: "%.2f MB", Double(rawBytes) / 1_048_576))")

writeBundle(images, to: "\(resourcesDir)/device_images.lzfse", label: "images")

// MARK: - Phase 6: Save hash & summary

try? currentHash.write(toFile: hashFile, atomically: true, encoding: .utf8)

print("""

── Summary ─────────────────────────────────────────────────────────────
  Docs:   \(docs.count) files
  Index:  \(index.count) entries
  Images: \(images.count) thumbnails (\(missing) missing, \(failures) failed)
  Hash \(currentHash.prefix(12)) saved to \(hashFile)
─────────────────────────────────────────────────────────────────────────
""")
