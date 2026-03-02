//
//  FloatArrayCache.swift
//  MusicalCaneGame
//
//  Created by Paul Ruvolo on 3/2/26.
//  Copyright © 2026 occamlab. All rights reserved.
//


import Foundation

enum FloatArrayCacheError: Error {
    case cacheDirectoryNotFound
    case encodingFailed
    case decodingFailed
}

struct FloatArrayCache {

    // MARK: - Directory
    
    private static func cacheDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .cachesDirectory,
                                                 in: .userDomainMask).first
        else {
            throw FloatArrayCacheError.cacheDirectoryNotFound
        }
        return url
    }

    // MARK: - Save
    
    static func save(_ array: [Float], as filename: String) throws {
        let directory = try cacheDirectory()
        let fileURL = directory.appendingPathComponent(filename)
            .appendingPathExtension("json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted] // optional
        
        do {
            let data = try encoder.encode(array)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw FloatArrayCacheError.encodingFailed
        }
    }

    // MARK: - Load
    
    static func load(from filename: String) throws -> [Float] {
        let directory = try cacheDirectory()
        let fileURL = directory.appendingPathComponent(filename)
            .appendingPathExtension("json")

        let data = try Data(contentsOf: fileURL)
        
        do {
            return try JSONDecoder().decode([Float].self, from: data)
        } catch {
            throw FloatArrayCacheError.decodingFailed
        }
    }

    // MARK: - Delete (Optional)
    
    static func delete(filename: String) throws {
        let directory = try cacheDirectory()
        let fileURL = directory.appendingPathComponent(filename)
            .appendingPathExtension("json")

        try FileManager.default.removeItem(at: fileURL)
    }
}
