//
//  SessionTask.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/5/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation
import UIKit
import libdsm

public enum SessionTaskState {
    case ready
    case running
    case suspended
    case cancelled
    case completed
    case failed
}

public class SessionTask {
    var smbSession: SMBSession
    var delegateQueue: DispatchQueue
    var canBeResumed: Bool = false
    var state: SessionTaskState = .ready
    
    internal var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    init(session: SMBSession, delegateQueue: DispatchQueue = DispatchQueue.main) {
        self.smbSession = session
        self.delegateQueue = delegateQueue
    }
    
    lazy var taskOperation: BlockOperation? = {
        var result = BlockOperation()
        result.addExecutionBlock {
            self.performTaskWith(operation: result)
        }
        result.completionBlock = {
            self.taskOperation = nil
        }
        return result
    }()
    
    func performTaskWith(operation: BlockOperation) {
        return
    }
    
    func requestFileForItemAt(path: String, inTree treeId: smb_tid) -> SMBFile? {
        let fileCString = path.cString(using: .utf8)
        guard let stat = smb_fstat(self.smbSession.smbSession, treeId, fileCString) else { return nil }
        
        let file = SMBFile(stat: stat, session: self.smbSession, parentDirectoryFilePath: path)
        
        smb_stat_destroy(stat)
        return file
    }
    
    func cleanupBlock(treeId: smb_tid, fileId: smb_fd) {
        if let backgroundTask = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            self.backgroundTaskIdentifier = nil
        }
        
        
        if self.taskOperation != nil && treeId > 0 {
            smb_tree_disconnect(self.smbSession.smbSession, treeId)
        }
        
        if let session = self.smbSession.smbSession {
            if fileId > 0 {
                smb_fclose(session, fileId)
            }
            smb_session_destroy(session)
        }
    }
    
    public func cancel() {
        if self.state != .running {
            return
        }
        self.taskOperation?.cancel()
        self.state = .cancelled
        self.taskOperation = nil
    }
    
    internal func fail() {
        if self.state != .running {
            return
        }
        self.cancel()
        self.state = .failed
    }
    
    public func resume() {
        if self.state == .running {
            return
        }
        guard let to = self.taskOperation else {
            return
        }
        self.smbSession.taskQueue.addOperation(to)
        self.state = .running
    }

}
