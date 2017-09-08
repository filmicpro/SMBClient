//
//  SessionUploadTask.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/6/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

import libdsm

public enum SessionUploadError: Error {
    case cancelled
    case connectionFailed
    case fileNotFound
    case serverNotFound
    case directoryDownloaded
    case uploadFailed
}

public protocol SessionUploadTaskDelegate {
    func uploadTask(didFinishUploading: SessionUploadTask)
    func uploadTask(_ task: SessionUploadTask, totalBytesSent: UInt64, totalBytesExpected: UInt64)
    func uploadTask(didCompleteWithError: SessionUploadError)
}


public class SessionUploadTask: SessionTask {
    var path: String
    var data: Data
    var delegate: SessionUploadTaskDelegate?
    var file: SMBFile?
    
    public init(session: SMBSession, delegateQueue: DispatchQueue = DispatchQueue.main, path: String, data: Data, delegate: SessionUploadTaskDelegate? = nil) {
        self.path = path
        self.data = data
        self.delegate = delegate
        super.init(session: session, delegateQueue: delegateQueue)
    }
    
    func delegateError(_ error: SessionUploadError) {
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
//        var smbSessionError: SMBSessionError? = nil
//        self.smbSession.serialQueue.async {
            let smbSessionError = self.session.attemptConnection()
//        }
        if (smbSessionError != nil) {
            self.delegateError(.serverNotFound)
            return
        }
        
        // ### connect to share
        let (shareName, sharePathRaw) = self.session.shareAndPathFrom(path: self.path)
        guard let sharePath = sharePathRaw else { return } // TODO: error?
        let shareCString = shareName.cString(using: .utf8)
        smb_tree_connect(self.session.smbSession, shareCString, &treeId)
        if treeId == 0 {
            self.delegateError(.connectionFailed)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }
        
        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
        }
        
        // ### find the target file
        var formattedPath = "\(sharePath)".replacingOccurrences(of: "/", with: "\\\\")
        formattedPath = "\\(formattedPath)"
        
        
        self.file = self.requestFileForItemAt(path: formattedPath, inTree: treeId)
        
        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }
        
        if let f = file {
            if f.isDirectory {
                // shouldn't have to do this if we're passing files
                delegateError(.directoryDownloaded)
                return
            }
        }
        
        let SMB_MOD_RW = SMB_MOD_READ | SMB_MOD_WRITE | SMB_MOD_APPEND | SMB_MOD_READ_EXT + SMB_MOD_WRITE_EXT | SMB_MOD_READ_ATTR | SMB_MOD_WRITE_ATTR | SMB_MOD_READ_CTL
        // ### open the file handle
        smb_fopen(self.session.smbSession, treeId, formattedPath.cString(using: .utf8), UInt32(SMB_MOD_RW), &fileId)
        if fileId == 0 {
            self.delegateError(.fileNotFound)
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }
        
        if operation.isCancelled {
            self.cleanupBlock(treeId: treeId, fileId: fileId)
            return
        }
        
        var bytes = [UInt8](self.data)
        let bufferSize = bytes.count
        
        var uploadBufferLimit = min(bytes.count, 63488)
        var bytesWritten = 0
        var totalBytesWritten = 0
        
        repeat {
            if (bufferSize - totalBytesWritten < uploadBufferLimit) {
                uploadBufferLimit = bufferSize - totalBytesWritten
            }
            
            let ptr: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: bytes)
            
            bytesWritten = smb_fwrite(self.session.smbSession, fileId, ptr, uploadBufferLimit)
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
