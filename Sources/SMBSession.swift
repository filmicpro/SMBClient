//
//  SMBSession.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/1/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

public class SMBSession {
    private var rawSession = smb_session_new() {
        didSet {
            print("rawSession updated: \(String(describing: rawSession))")
        }
    }
    internal var serialQueue = DispatchQueue(label: "SMBSession")

    lazy var dataQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var lastRequestDate: Date?

    public var sessionGuestState: SessionGuestState?
    public var connected: Bool = false
    public var server: SMBServer
    public var credentials: Credentials

    public var maxTaskOperationCount = OperationQueue.defaultMaxConcurrentOperationCount

    // tasks
    var downloadTasks: [SessionDownloadTask] = []
    var uploadTasks: [SessionUploadTask] = []
    lazy var taskQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = self.maxTaskOperationCount
        return queue
    }()

    public init(server: SMBServer, credentials: SMBSession.Credentials = .guest) {
        self.server = server
        self.credentials = credentials
    }

    public func requestVolumes() -> Result<[SMBVolume]> {
        let conError = self.attemptConnection()
        // switch result/error
        if let error = conError {
            return Result.failure(error)
        }

        var list: smb_share_list? = smb_share_list.allocate(capacity: 1)

        let shareCount = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        shareCount.pointee = 0

        let getResult = smb_share_get_list(self.rawSession, &list, shareCount)
        if getResult != 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        }

        if shareCount.pointee == 0 {
            return Result.success([])
        }
        var results: [SMBVolume] = []

        var i = 0
        while i <= shareCount.pointee {
            guard let volumeNameCString = smb_share_list_at(list!, i) else {
                i += 1
                continue
            }

            let volmueName = String(cString: volumeNameCString)
            let v = SMBVolume(server: self.server, name: volmueName)

            if !v.isHidden {
                results.append(v)
            }

            i += 1
        }
        smb_share_list_destroy(list)
        list?.deallocate(capacity: <#T##Int#>)
        shareCount.deallocate(capacity: 1)

        return Result.success(results)
    }

    public func requestVolumes(completionQueue: DispatchQueue = DispatchQueue.main,
                               completion: @escaping (_ result: Result<[SMBVolume]>) -> Void) {
        let operation = BlockOperation()
        weak var weakOperation = operation

        let blockOperation = {
            if let weakOp = weakOperation, weakOp.isCancelled {
                return
            }
            let requestResult = self.requestVolumes()

            completionQueue.async {
                completion(requestResult)
            }
        }

        operation.addExecutionBlock(blockOperation)
        self.dataQueue.addOperation(operation)
    }

    public func requestItems(atPath path: SMBPath) -> Result<[SMBItem]> {
        let conError = self.attemptConnection()

        if let error = conError {
            return Result.failure(error)
        }

        var shareId: UInt16 = smb_tid.max
        smb_tree_connect(self.rawSession, path.volume.name.cString(using: .utf8), &shareId)
        if shareId == smb_tid.max {
            return Result.success([])
        }

        // \SampleMedia\*
        let statList = smb_find(self.rawSession, shareId, path.searchPath.cString(using: .utf8))
        let listCount = smb_stat_list_count(statList)
        if listCount == 0 {
            return Result.success([])
        }

        var results: [SMBItem] = []

        var i = 0
        while i < listCount {
            let item = smb_stat_list_at(statList, i)
            guard let stat = item else {
                i += 1
                continue
            }
            // guard let smbItem = SMBItem(stat: stat, session: self, parentDirectoryFilePath: relativePath) else {
            guard let smbItem = SMBItem(stat: stat, session: self, parentPath: path) else {
                i += 1
                continue
            }

            if !smbItem.isHidden {
                results.append(smbItem)
            }

            i += 1
        }

        smb_stat_list_destroy(statList)

        return Result.success(results)
    }

    public func requestItems(atPath path: SMBPath,
                             completionQueue: DispatchQueue = DispatchQueue.main,
                             completion: @escaping (_ result: Result<[SMBItem]>) -> Void) {
        let operation = BlockOperation()
        weak var weakOperation = operation

        let blockOperation = {
            if let weakOp = weakOperation, weakOp.isCancelled {
                return
            }
            let requestResult = self.requestItems(atPath: path)
            completionQueue.async {
                completion(requestResult)
            }
        }
        operation.addExecutionBlock(blockOperation)
        self.dataQueue.addOperation(operation)
    }

    public func attemptConnection() -> SMBSessionError? {
        var err: SMBSessionError?
        serialQueue.sync {
            err = self.attemptConnectionWithSessionPointer(smbSession: self.rawSession)
        }

        if err != nil {
            return err
        }

        self.sessionGuestState = SessionGuestState(rawValue: smb_session_is_guest(self.rawSession))

        return nil
    }

    private func attemptConnectionWithSessionPointer(smbSession: OpaquePointer?) -> SMBSessionError? {

        // if we're connecting from a dowload task, and the sessions match, make sure to refresh them periodically
        if self.rawSession == smbSession {
            if let lrd = self.lastRequestDate {
                if Date().timeIntervalSince(lrd) > 60 {
                    smb_session_destroy(self.rawSession)
                    self.rawSession = smb_session_new()

                    self.connected = false
                }
            }
            self.lastRequestDate = Date()
        }

        // don't attempt another connection if already connected
        if smb_session_is_guest(self.rawSession) >= 0 {
            self.connected = true
            return nil
        }

        // attempt a connection
        let connectionResult = smb_session_connect(self.rawSession,
                                                   server.hostname.cString(using: .utf8),
                                                   server.ipAddress,
                                                   Int32(SMB_TRANSPORT_TCP))
        if connectionResult != 0 {
            return SMBSessionError.unableToConnect
        }

        smb_session_set_creds(self.rawSession,
                              self.server.hostname.cString(using: .utf8),
                              self.credentials.userName.cString(using: .utf8),
                              self.credentials.password.cString(using: .utf8))
        if smb_session_login(self.rawSession) != 0 {
            return SMBSessionError.authenticationFailed
        }
        self.connected = true

        return nil
    }

    public func downloadTaskForFile(file: SMBFile,
                                    destinationPath: String?,
                                    delegate: SessionDownloadTaskDelegate?) -> SessionDownloadTask {
        let task = SessionDownloadTask(session: self,
                                       sourceFile: file,
                                       destinationFilePath: destinationPath,
                                       delegate: delegate)
        self.downloadTasks.append(task)
        return task
    }

    // uploadTaskForFile(toPath: path, withName: fileName, data: data, delegate: self)
    @discardableResult public func uploadTaskForFile(toPath path: SMBPath,
                                                     withName fileName: String,
                                                     data: Data,
                                                     delegate: SessionUploadTaskDelegate?) -> SessionUploadTask {
        let task = SessionUploadTask(session: self, path: path, fileName: fileName, data: data)
        task.delegate = delegate
        self.uploadTasks.append(task)
        return task
    }

    func cancelAllRequests() {
        self.dataQueue.cancelAllOperations()
    }

    internal func treeConnect(volume: SMBVolume) -> Result<smb_tid> {
        var treeId = smb_tid(0)
        let x = smb_tree_connect(self.rawSession, volume.name.cString(using: .utf8), &treeId)
        if x != 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        }
        return Result.success(treeId)
    }

    internal func treeDisconnect(treeId: smb_tid) -> SMBSessionError? {
        let result = smb_tree_disconnect(self.rawSession, treeId)
        if result != 0 {
            return SMBSessionError.disconnectFailed
        } else {
            return nil
        }
    }

    internal func fileStat(treeId: smb_tid, file: SMBFile) -> Result<SMBFile> {
        let filePathCString = file.downloadPath.cString(using: .utf8)
        guard let stat = smb_fstat(self.rawSession, treeId, filePathCString) else {
            return Result.failure(SMBSessionError.unableToConnect)
        }
        guard let resultFile = SMBFile(stat: stat, parentPath: file.path) else {
            smb_stat_destroy(stat)
            return Result.failure(SMBSessionError.unableToConnect)
        }
        smb_stat_destroy(stat)
        return Result.success(resultFile)
    }

    internal func fileClose(fileId: smb_fd) {
        if fileId > 0 {
            smb_fclose(self.rawSession, fileId)
        }
    }

    internal func fileOpen(treeId: smb_tid, path: String, mod: UInt32) -> Result<smb_fd> {
        var fd = smb_fd(0)
        let openResult = smb_fopen(self.rawSession, treeId, path.cString(using: .utf8), mod, &fd)
        if openResult != 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        } else {
            return Result.success(fd)
        }
    }

    // @return The current read pointer position or -1 on error
    internal func fileSeek(fileId: smb_fd, offset: UInt64) -> Result<Int> {
        let result = smb_fseek(self.rawSession, fileId, Int64(offset), Int32(SMB_SEEK_SET))
        if result < 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        } else {
            return Result.success(result)
        }
    }

    internal func fileRead(fileId: smb_fd, bufferSize: UInt) -> Result<Data> {
        let buffer = UnsafeMutableRawPointer.allocate(bytes: Int(bufferSize), alignedTo: 1)

        let bytesRead = smb_fread(self.rawSession, fileId, buffer, Int(bufferSize))
        if bytesRead < 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        } else {
            let data = Data(bytes: buffer, count: bytesRead)
            buffer.deallocate(bytes: Int(bufferSize), alignedTo: 1)
            return Result.success(data)
        }
    }

    internal func fileWrite(fileId: smb_fd, buffer: UnsafeMutableRawPointer, bufferSize: Int) -> Int {
        return smb_fwrite(self.rawSession, fileId, buffer, bufferSize)
    }

    deinit {
        guard let s = self.rawSession else { return }
        smb_session_destroy(s)
    }
}

extension SMBSession {
    public enum SessionGuestState: Int32 {
        case guest = 1
        case user = 0
        case error = -1
    }

    public enum SMBSessionError: Error {
        case unableToResolveAddress
        case unableToConnect
        case authenticationFailed
        case disconnectFailed
    }

    public enum Credentials {
        case guest
        case user(name: String, password: String)

        var userName: String {
            switch self {
            case .guest:
                return " " //
            case .user(let name, _):
                return name
            }
        }

        var password: String {
            switch self {
            case .guest:
                return " "
            case .user(_, let pass):
                return pass
            }
        }
    }
}

extension SMBSession.Credentials: CustomStringConvertible {
    public var description: String {
        switch self {
        case .guest:
            return "guest"
        case .user(let name, _):
            return "User: \(name) pass: ******"
        }
    }
}

extension SMBSession: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "hostname : \(String(describing: self.server.hostname))\n" +
               "ipAddress : \(self.server.ipAddressString)\n" +
               "credentials : \(self.credentials)\n"
    }

}
