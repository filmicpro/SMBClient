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
    var data: Data
    var file: SMBFile?
    public weak var delegate: SessionUploadTaskDelegate?

    public init(session: SMBSession,
                delegateQueue: DispatchQueue = DispatchQueue.main,
                path: SMBPath,
                fileName: String,
                data: Data,
                delegate: SessionUploadTaskDelegate? = nil) {
        self.path = path
        self.fileName = fileName
        self.data = data
        self.delegate = delegate
        super.init(session: session, delegateQueue: delegateQueue)
    }

    func delegateError(_ error: SessionUploadTask.SessionUploadError) {
        self.delegateQueue.async {
            self.delegate?.uploadTask(didCompleteWithError: error)
        }
    }

    override func performTaskWith(operation: BlockOperation) {
        if operation.isCancelled {
            return
        }

        var treeId = smb_tid(0)
        var fileId = smb_fd(0)

        // ### confirm server is still available
        let smbSessionError = self.session.attemptConnection()
        if smbSessionError != nil {
            self.delegateError(.serverNotFound)
            return
        }

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
            return
        }

        let SMB_MOD_RW = SMB_MOD_READ |
            SMB_MOD_WRITE |
            SMB_MOD_APPEND |
            SMB_MOD_READ_EXT + SMB_MOD_WRITE_EXT |
            SMB_MOD_READ_ATTR |
            SMB_MOD_WRITE_ATTR |
            SMB_MOD_READ_CTL
        // ### open the file handle
        let fileOpenResult = self.session.fileOpen(treeId: treeId, path: self.file!.uploadPath, mod: UInt32(SMB_MOD_RW))
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

        var bytes = [UInt8](self.data)
        let bufferSize = bytes.count

        var uploadBufferLimit = min(bytes.count, 63488)
        var bytesWritten = 0
        var totalBytesWritten = 0

        repeat {
            if bufferSize - totalBytesWritten < uploadBufferLimit {
                uploadBufferLimit = bufferSize - totalBytesWritten
            }

            let ptr: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: bytes)

            bytesWritten = self.session.fileWrite(fileId: fileId, buffer: ptr, bufferSize: uploadBufferLimit)
            if bytesWritten < 0 {
                fail()
                self.delegateError(.uploadFailed)
                break
            }

            totalBytesWritten += bytesWritten
        } while (totalBytesWritten < bufferSize)

        bytes = []
        self.didFinish()
    }

    func didFinish() {
        self.delegateQueue.async {
            self.delegate?.uploadTask(didFinishUploading: self)
        }
    }

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
