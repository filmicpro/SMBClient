//
//  SessionUploadTask.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/6/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

import libdsm

public protocol SessionUploadTaskDelegate: class {
    func uploadTask(didFinishUploading: SessionUploadTask)
    func uploadTask(_ task: SessionUploadTask, totalBytesSent: UInt64, totalBytesExpected: UInt64)
    func uploadTask(didCompleteWithError: SessionUploadTask.SessionUploadError)
}

public class SessionUploadTask: SessionTask {
    var path: SMBPath
    var fileName: String
    var uploadExtension: String? // appending .upload to upload file name, then move
    var data: Data
    var file: SMBFile?
    public weak var delegate: SessionUploadTaskDelegate?

    public init(session: SMBSession,
                delegateQueue: DispatchQueue = DispatchQueue.main,
                path: SMBPath,
                fileName: String,
                uploadExtension: String? = nil,
                data: Data,
                delegate: SessionUploadTaskDelegate? = nil) {
        self.path = path
        self.fileName = fileName
        self.uploadExtension = uploadExtension
        self.data = data
        self.delegate = delegate
        super.init(session: session, delegateQueue: delegateQueue)
    }

    override func performTaskWith(operation: BlockOperation) {
        if operation.isCancelled {
            delegateError(.cancelled)
            return
        }

        var treeId = smb_tid(0)
        var fileId = smb_fd(0)

        // ### connect to share
        let conn = self.session.treeConnect(volume: self.path.volume)
        switch conn {
        case .failure:
            self.delegateError(.connectionFailed)
            return
        case .success(let t):
            treeId = t
        }

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
        }

        // ### find the target file
        self.file = SMBFile(path: self.path, name: self.fileName)

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            delegateError(.cancelled)
            return
        }

        let SMB_MOD_READ_WRITE_NEW_FILE = SMB_MOD_READ | SMB_MOD_WRITE | SMB_MOD_APPEND
            | SMB_MOD_READ_EXT | SMB_MOD_WRITE_EXT
            | SMB_MOD_READ_ATTR | SMB_MOD_WRITE_ATTR
            | SMB_MOD_READ_CTL
        let SMB_MOD_READ_WRITE_EXISTING_FILE = SMB_MOD_READ | SMB_MOD_WRITE | SMB_MOD_APPEND
            | SMB_MOD_READ_ATTR | SMB_MOD_WRITE_ATTR
            | SMB_MOD_READ_CTL

        // ### open the file handle
        guard let uploadPath = self.fileUploadPath else {
            self.delegateError(SessionUploadTask.SessionUploadError.fileNotFound)
            return
        }

        var bytes = [UInt8](self.data)
        let totalByteCount = bytes.count

        var uploadBufferLimit = min(bytes.count, 63488)
        var bytesWritten = 0
        var totalBytesWritten = 0

        // check if there is a file to resume upload on
        if let previousUpload = self.existingTempDestination(treeId: treeId) {
            totalBytesWritten = Int(previousUpload.fileSize)
        }

        let fileOpenResult: Result<smb_fd, SMBSession.SMBSessionError>
        if totalBytesWritten == 0 {
            fileOpenResult = self.session.fileOpen(treeId: treeId, path: uploadPath, mod: UInt32(SMB_MOD_READ_WRITE_NEW_FILE))
        } else {
            fileOpenResult = self.session.fileOpen(treeId: treeId, path: uploadPath, mod: UInt32(SMB_MOD_READ_WRITE_EXISTING_FILE))
        }
        switch fileOpenResult {
        case .failure:
            self.delegateError(SessionUploadTask.SessionUploadError.connectionFailed)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        case .success(let fId):
            fileId = fId
        }

        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            self.delegateError(.cancelled)
            return
        }

        // if resuming a previously failed upload
        if totalBytesWritten > 0 {
            let res = self.session.fileSeek(fileId: fileId, offset: UInt64(totalBytesWritten))
            switch res {
            case .success(let readPointer):
                if readPointer != totalBytesWritten {
                    // something has gone wrong, remove remote file and try again
                }
            case .failure:
                // remove file, try again
                break
            }
        }

        repeat {
            if totalByteCount - totalBytesWritten < uploadBufferLimit {
                uploadBufferLimit = totalByteCount - totalBytesWritten
            }

            let ptr: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: bytes)

            if operation.isCancelled {
                break
            }
            bytesWritten = self.session.fileWrite(fileId: fileId, buffer: ptr+totalBytesWritten, bufferSize: uploadBufferLimit)
            // bytesWritten == -1, console output is 'netbios_session_packet_recv: : Network is down'
            if bytesWritten < 0 {
                fail()
                self.delegateError(.uploadFailed)
                bytes = []
                break
            }
            self.delegateQueue.async {
                self.delegate?.uploadTask(self, totalBytesSent: UInt64(totalBytesWritten), totalBytesExpected: UInt64(totalByteCount))
            }

            totalBytesWritten += bytesWritten
        } while (totalBytesWritten < totalByteCount)

        bytes = []

        self.session.fileClose(fileId: fileId)

        if operation.isCancelled {
            return
        }

        // if there was an upload extension move the file to remove the extension
        if self.uploadExtension != nil, let destPath = self.file?.uploadPath {
            let moveError = self.session.fileMove(volume: self.path.volume, oldPath: uploadPath, newPath: destPath)
            if moveError != nil {
                self.delegateError(.uploadFailed)
                return
            }
        }
        self.didFinish()
    }

    override public func cancel() {
        if self.state != .running {
            return
        }

        let deleteFunc = {
            if self.uploadExtension != nil, let destPath = self.file?.uploadPath {
                _ = self.session.fileDelete(volume: self.path.volume, path: destPath)
            }
            if let uploadPath = self.fileUploadPath {
                _ = self.session.fileDelete(volume: self.path.volume, path: uploadPath)
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

    private func delegateError(_ error: SessionUploadTask.SessionUploadError) {
        self.delegateQueue.async {
            self.delegate?.uploadTask(didCompleteWithError: error)
        }
    }

    private func existingTempDestination(treeId: smb_tid) -> SMBFile? {
        guard let ue = self.uploadExtension else { return nil }
        guard let filePath = self.file?.path else { return nil }
        guard let tempName = self.file?.name.appending(ue) else { return nil }
        if let tempFile = SMBFile(path: filePath, name: tempName) {
            let existingUpload = self.session.fileStat(treeId: treeId, file: tempFile)
            switch existingUpload {
            case .success(let f):
                return f
            default:
                break
            }
        }
        return nil
    }

    private var fileUploadPath: String? {
        guard let f = self.file else { return nil }
        if let ue = self.uploadExtension {
            return f.uploadPath.appending(ue)
        } else {
            return f.uploadPath
        }
    }

    private func didFinish() {
        self.state = .completed
        self.delegateQueue.async {
            self.delegate?.uploadTask(didFinishUploading: self)
        }
    }

}

extension SessionUploadTask: Equatable { }

public func == (lhs: SessionUploadTask, rhs: SessionUploadTask) -> Bool {
    return lhs.path == rhs.path
}

extension SessionUploadTask {
    public enum SessionUploadError: Error {
        case cancelled
        case connectionFailed
        case fileNotFound
        case serverNotFound
        case directoryDownloaded
        case uploadFailed
    }
}
