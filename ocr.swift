// ocr.swift
//
// A command-line utility that performs optical character recognition (OCR) on an image file.
// Uses Apple's Vision framework to extract text with high accuracy and language correction.

import Foundation
import Vision

func extractText(from imagePath: String) throws -> String {
    let url = URL(fileURLWithPath: imagePath)
    let handler = try VNImageRequestHandler(url: url)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try handler.perform([request])

    let text = (request.results as? [VNRecognizedTextObservation])?
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n") ?? ""

    return text
}

if CommandLine.arguments.count > 1 {
    let path = CommandLine.arguments[1]
    let text = try extractText(from: path)
    print(text)
} else {
    print("Usage: ocr /path/to/image.png")
}
