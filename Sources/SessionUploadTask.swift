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
            SMB_MOD_READ_EXT |
            SMB_MOD_WRITE_EXT |
            SMB_MOD_READ_ATTR |
            SMB_MOD_WRITE_ATTR |
            SMB_MOD_READ_CTL
        // ### open the file handle
        guard let uploadPath = self.fileUploadPath else {
            self.delegateError(SessionUploadTask.SessionUploadError.fileNotFound)
            return
        }
        let fileOpenResult = self.session.fileOpen(treeId: treeId, path: uploadPath, mod: UInt32(SMB_MOD_RW))
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
        let totalByteCount = bytes.count

        var uploadBufferLimit = min(bytes.count, 63488)
        var bytesWritten = 0
        var totalBytesWritten = 0

        repeat {
            if totalByteCount - totalBytesWritten < uploadBufferLimit {
                uploadBufferLimit = totalByteCount - totalBytesWritten
            }

            let ptr: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: bytes)

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

    private var fileUploadPath: String? {
        guard let f = self.file else { return nil }
        if let ue = self.uploadExtension {
            return f.uploadPath.appending(ue)
        } else {
            return f.uploadPath
        }
    }

    func didFinish() {
        self.state = .completed
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
