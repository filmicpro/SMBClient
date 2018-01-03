//
//  SessionDownloadTask.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/5/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif

import libdsm

public protocol SessionDownloadTaskDelegate: class {
    func downloadTask(didFinishDownloadingToPath: String)
    func downloadTask(totalBytesReceived: UInt64, totalBytesExpected: UInt64)
    func downloadTask(didCompleteWithError: SessionDownloadTask.SessionDownloadError)
}

public class SessionDownloadTask: SessionTask {
    var sourceFile: SMBFile
    var destinationFileURL: URL?
    var bytesReceived: UInt64?
    var bytesExpected: UInt64?
    var file: SMBFile?
    let appendDestinationFileNameIfExists: Bool
    public weak var delegate: SessionDownloadTaskDelegate?

    var tempPathForTemoraryDestination: String {
        let filename = self.hashForFilePath.appending("smb.data")
        return NSTemporaryDirectory().appending(filename)
    }

    var hashForFilePath: String {
        let filepath = self.sourceFile.path.routablePath.lowercased()
        return "\(filepath.hashValue)"
    }

    public init(session: SMBSession,
                sourceFile: SMBFile,
                destinationFileURL: URL? = nil,
                appendDestinationFileNameIfExists: Bool = true,
                delegate: SessionDownloadTaskDelegate? = nil) {
        self.sourceFile = sourceFile
        self.destinationFileURL = destinationFileURL
        self.appendDestinationFileNameIfExists = appendDestinationFileNameIfExists
        self.delegate = delegate
        super.init(session: session)
    }

    private func delegateError(_ error: SessionDownloadTask.SessionDownloadError) {
        self.delegateQueue.async {
            self.delegate?.downloadTask(didCompleteWithError: error)
        }
    }

    private var finalFilePathForDownloadedFile: URL? {
        guard let dest = self.destinationFileURL else { return nil }

        var fileName = dest.lastPathComponent
        let fName = fileName.utf8
        let isFile = fileName.contains(".") && fName.first != Unicode.UTF8.CodeUnit(".")

        let folderPath: URL
        if isFile {
            folderPath = dest.deletingLastPathComponent()
        } else {
            fileName = self.sourceFile.name
            folderPath = dest
        }

        var newFilePath = dest
        var newFileName = fileName

        var index = 0
        if self.appendDestinationFileNameIfExists {
            while FileManager.default.fileExists(atPath: newFilePath.path) {
                let fileNameURL = URL(fileURLWithPath: fileName)
                index += 1
                if fileNameURL.pathExtension != "" {
                    newFileName = "\(fileNameURL.deletingPathExtension().relativeString)-\(index).\(fileNameURL.pathExtension)"
                } else {
                    newFileName = "\(fileNameURL.deletingPathExtension().relativeString)-\(index)"
                }
                newFilePath = folderPath.appendingPathComponent(newFileName)
            }
        }
        return newFilePath
    }

    override func performTaskWith(operation: BlockOperation) {
        if operation.isCancelled {
            delegateError(.cancelled)
            return
        }

        var treeId = smb_tid(0)
        var fileId = smb_fd(0)

        // Connect to the volume/share
        let treeConnResult = self.session.treeConnect(volume: self.sourceFile.path.volume)
        switch treeConnResult {
        case .failure:
            delegateError(.serverNotFound)
        case .success(let t):
            treeId = t
        }

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        self.file = self.request(file: sourceFile, inTree: treeId)

        guard let file = self.file else {
            delegateError(.fileNotFound)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        if operation.isCancelled {
            delegateError(.cancelled)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        self.bytesExpected = file.fileSize

        // ### Open file handle
        let fopen = self.session.fileOpen(treeId: treeId, path: file.downloadPath, mod: UInt32(SMB_MOD_READ))
        switch fopen {
        case .failure:
            delegateError(.fileNotFound)
            self.cleanupBlock(treeId: treeId, fileId: 0)
            return
        case .success(let f):
            fileId = f
        }

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        // ### Start downloading
        var path = URL(string: self.tempPathForTemoraryDestination)
        path?.deleteLastPathComponent()

        do {
            try FileManager.default.createDirectory(atPath: path!.absoluteString,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            self.delegateError(.invalidDestination)
            fail()
            return
        }

        if !self.canBeResumed {
            FileManager.default.createFile(atPath: self.tempPathForTemoraryDestination, contents: nil, attributes: nil)
        }

        // open a handle to file
        let fileHandle = FileHandle(forWritingAtPath: self.tempPathForTemoraryDestination)
        let seekOffset = fileHandle?.seekToEndOfFile()
        self.bytesReceived = seekOffset ?? 0

        #if os(iOS)
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.suspend()
        })
        #endif

        if let so = seekOffset, so > 0 {
            let fSeek = self.session.fileSeek(fileId: fileId, offset: so)
            switch fSeek {
            case .failure:
                delegateError(.downloadFailed)
                self.cleanupBlock(treeId: treeId, fileId: fileId)
                do {
                    try FileManager.default.removeItem(atPath: self.tempPathForTemoraryDestination)
                } catch { }
                return
            case .success(let readBytes):
                self.bytesReceived = UInt64(readBytes)
            }
        }

        // ### Download bytes
        var bytesRead: Int = 0
        let bufferSize: Int = 65535

        var didAlreadyError = false

        repeat {
            let readResult = self.session.fileRead(fileId: fileId, bufferSize: UInt(bufferSize))
            switch readResult {
            case .failure(let err):
                self.fail()

                switch err {
                case .unableToConnect:
                    delegateError(.lostConnection)
                default:
                    delegateError(.downloadFailed)
                }
                didAlreadyError = true
                break
            case .success(let data):
                fileHandle?.write(data)
                fileHandle?.synchronizeFile()
                bytesRead = data.count
            }

            if operation.isCancelled {
                break
            }

            self.bytesReceived = self.bytesReceived! + UInt64(bytesRead)
            self.delegateQueue.async {
                self.delegate?.downloadTask(totalBytesReceived: self.bytesReceived!,
                                            totalBytesExpected: self.bytesExpected!)
            }
        } while (bytesRead > 0)

        // Set the modification date to match the one on the SMB device so we can compare the two at a later date
        do {
            if let modAt = file.modifiedAt {
                try FileManager.default.setAttributes([FileAttributeKey.modificationDate: modAt],
                                                      ofItemAtPath: self.tempPathForTemoraryDestination)
            }
        } catch {
            // updating the timestamp doesn't matter that much
        }

        fileHandle?.closeFile()

        if operation.isCancelled || self.state != .running {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            if !didAlreadyError {
                delegateError(.cancelled)
            }
            return
        }

        // ### Move the finished file to its destination
        guard let finalDestination = self.finalFilePathForDownloadedFile else { return }

        do {
            let url = URL(fileURLWithPath: self.tempPathForTemoraryDestination)
            try FileManager.default.moveItem(at: url, to: finalDestination)
        } catch {
            delegateError(.invalidDestination)
        }
        self.state = .completed
        self.delegateQueue.async {
            self.delegate?.downloadTask(didFinishDownloadingToPath: finalDestination.absoluteString)
        }
        self.cleanupBlock(treeId: treeId, fileId: fileId)
    }

    override var canBeResumed: Bool {
        if !FileManager.default.fileExists(atPath: self.tempPathForTemoraryDestination) {
            return false
        }

        var tempModifiedAt: Date?

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: self.tempPathForTemoraryDestination)
            tempModifiedAt = attrs[FileAttributeKey.modificationDate] as? Date
        } catch {
            return false
        }

        if tempModifiedAt != nil && tempModifiedAt == self.file?.modifiedAt {
            return true
        }
        return false
    }

    func suspend() {
        if self.state != .running {
            return
        }
        self.taskOperation?.cancel()
        self.state = .cancelled
        self.taskOperation = nil
    }

    override public func cancel() {
        if self.state != .running {
            return
        }

        let deleteFunc = {
            do {
                try FileManager.default.removeItem(atPath: self.tempPathForTemoraryDestination)
            } catch { }
        }
        let deleteOperation = BlockOperation(block: deleteFunc)
        if let op = self.taskOperation {
            deleteOperation.addDependency(op)
        }
        self.session.taskQueue.addOperation(deleteOperation)

        self.taskOperation?.cancel()
        self.state = .cancelled

        self.taskOperation = nil
    }
}

extension SessionDownloadTask {
    public enum SessionDownloadError: Error {
        case cancelled
        case fileNotFound
        case serverNotFound
        case downloadFailed
        case lostConnection
        case invalidDestination
    }
}
