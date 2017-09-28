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

public enum SessionDownloadError: Error {
    case cancelled
    case fileNotFound
    case serverNotFound
    case downloadFailed
    case invalidDestination
}

public protocol SessionDownloadTaskDelegate {
    func downloadTask(didFinishDownloadingToPath: String)
    func downloadTask(totalBytesReceived: UInt64, totalBytesExpected: UInt64)
    func downloadTask(didCompleteWithError: SessionDownloadError)
}

public class SessionDownloadTask: SessionTask {
    var sourceFile: SMBFile
    var destinationFilePath: String?
    var bytesReceived: UInt64?
    var bytesExpected: UInt64?
    var file: SMBFile?

    var tempPathForTemoraryDestination: String {
        let filename = self.hashForFilePath.appending("smb.data")
        return NSTemporaryDirectory().appending(filename)
    }

    var hashForFilePath: String {
        let filepath = self.sourceFile.path.routablePath.lowercased()
        return "\(filepath.hashValue)"
    }

    public var delegate: SessionDownloadTaskDelegate?

    public init(session: SMBSession,
                sourceFile: SMBFile,
                destinationFilePath: String? = nil,
                delegate: SessionDownloadTaskDelegate? = nil) {
        self.sourceFile = sourceFile
        self.destinationFilePath = destinationFilePath
        self.delegate = delegate
        super.init(session: session)
    }

    func delegateError(_ error: SessionDownloadError) {
        self.delegateQueue.async {
            self.delegate?.downloadTask(didCompleteWithError: error)
        }
    }

    private var finalFilePathForDownloadedFile: URL? {
        guard let dest = self.destinationFilePath else { return nil }
        let path = URL(fileURLWithPath: dest.replacingOccurrences(of: "file://", with: ""))

        var fileName = path.lastPathComponent
        let isFile = fileName.contains(".") && fileName.characters.first != "."

        let folderPath: URL
        if isFile {
            folderPath = path.deletingLastPathComponent()
        } else {
            fileName = self.sourceFile.name
            folderPath = path
        }

        var newFilePath = path
        var newFileName = fileName

        var index = 0
        while FileManager.default.fileExists(atPath: newFilePath.absoluteString) {
            let fileNameURL = URL(fileURLWithPath: fileName)
            index += 1
            newFileName = "\(fileNameURL.deletingPathExtension())-\(index).\(fileNameURL.pathExtension)"
            newFilePath = folderPath.appendingPathComponent(newFileName)
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

        // Connect to SMB Server
        var connectError: SMBSession.SMBSessionError? = nil
        self.session.serialQueue.sync {
            connectError = self.session.refreshConnection(smbSession: self.session.rawSession)
        }
        if connectError != nil {
            delegateError(.serverNotFound)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }

        // Connect to the share
        let volumeName = self.sourceFile.path.volume.name
        let volumeCString = volumeName.cString(using: .utf8)
        smb_tree_connect(self.session.rawSession, volumeCString, &treeId)

        if treeId == 0 {
            delegateError(.serverNotFound)
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

        // TODO if directory check was here, refactor to enum should resolve

        self.bytesExpected = file.fileSize

        // ### Open file handle
        smb_fopen(self.session.rawSession, treeId, file.downloadPath.cString(using: .utf8), UInt32(SMB_MOD_READ), &fileId)
        if fileId == 0 {
            delegateError(.fileNotFound)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
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
            // return error TODO
        }

        if self.canBeResumed == false {
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

        if let so = seekOffset {
            if so > 0 {
                smb_fseek(self.session.rawSession, fileId, Int64(so), Int32(SMB_SEEK_SET))
                // self.didResumeOffset(seekOffset: so, totalBytesExpeted: self.bytesExpected!) // TODO
            }
        }

        // ### Download bytes
        var bytesRead: Int = 0
        let bufferSize: Int = 65535
        let buffer = UnsafeMutableRawPointer.allocate(bytes: bufferSize, alignedTo: 1)

        repeat {
            bytesRead = smb_fread(self.session.rawSession, fileId, buffer, bufferSize)
            if bytesRead < 0 {
                self.fail()
                delegateError(.downloadFailed)
                break
            }

            let data = Data.init(bytes: buffer, count: bytesRead)
            fileHandle?.write(data)
            fileHandle?.synchronizeFile()

            if operation.isCancelled {
                break
            }

            self.bytesReceived = self.bytesReceived! + UInt64(bytesRead)
            self.delegateQueue.async {
                self.delegate?.downloadTask(totalBytesReceived: self.bytesReceived!,
                                            totalBytesExpected: self.bytesExpected!)
            }
        } while (bytesRead > 0)

        // Set the modification date to match the one on the SMB device so we can compare thetwo at a later date
        do {
            if let modAt = file.modifiedAt {
                try FileManager.default.setAttributes([FileAttributeKey.modificationDate: modAt],
                                                      ofItemAtPath: self.tempPathForTemoraryDestination)
            }
        } catch {
            // updating the timestamp doesn't matter that much
        }

        // free(buffer)
        buffer.deallocate(bytes: bufferSize, alignedTo: 1)
        fileHandle?.closeFile()

        if operation.isCancelled || self.state != .running {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            delegateError(.cancelled)
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
            } catch {
                // TODO
            }
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
