// ocr.swift
//
// A command-line utility that performs optical character recognition (OCR) on an image file.
// Uses Apple's Vision framework to extract text with high accuracy and language correction.

import Foundation
import Vision

func extractText(from imagePath: String) throws -> String {
    let url = URL(fileURLWithPath: imagePath)
    let handler = VNImageRequestHandler(url: url)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try handler.perform([request])

    let text = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")

    return text
}

func deriveOutputPath(from imagePath: String) -> String {
    let url = URL(fileURLWithPath: imagePath)
    if url.pathExtension.isEmpty {
        return imagePath + ".txt"
    }
    return url.deletingPathExtension().appendingPathExtension("txt").path
}

func writeOutput(_ text: String, to outputPath: String) throws {
    if FileManager.default.fileExists(atPath: outputPath) {
        fputs("Notice: Overwriting existing file '\(outputPath)'\n", stderr)
    }
    try text.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

// Parse arguments
var args = Array(CommandLine.arguments.dropFirst())
var outputFile: String? = nil
var deriveOutput = false
var imagePath: String? = nil

var i = 0
while i < args.count {
    switch args[i] {
    case "-o":
        guard i + 1 < args.count else {
            fputs("Error: -o requires a filename argument\n", stderr)
            exit(1)
        }
        outputFile = args[i + 1]
        i += 2
    case "-O":
        deriveOutput = true
        i += 1
    default:
        if imagePath == nil {
            imagePath = args[i]
        } else {
            fputs("Error: Unexpected argument '\(args[i])'\n", stderr)
            exit(1)
        }
        i += 1
    }
}

if outputFile != nil && deriveOutput {
    fputs("Error: -o and -O are mutually exclusive\n", stderr)
    exit(1)
}

guard let path = imagePath else {
    print("Usage: ocr [-o output.txt | -O] /path/to/image.png")
    print("  -o filename  Write output to the specified file")
    print("  -O           Write output to a .txt file derived from the input filename")
    exit(0)
}

guard FileManager.default.fileExists(atPath: path) else {
    fputs("Error: File not found at '\(path)'\n", stderr)
    exit(1)
}

let text = try extractText(from: path)

if let outputFile = outputFile {
    try writeOutput(text, to: outputFile)
} else if deriveOutput {
    let outputPath = deriveOutputPath(from: path)
    try writeOutput(text, to: outputPath)
} else {
    print(text)
}
