//
//  SMBSession.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/1/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import SystemConfiguration
import libdsm

public class SMBSession {
    private var rawSession = smb_session_new()
    internal var serialQueue = DispatchQueue(label: "SMBSession")

    lazy var dataQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var lastRequestDate: Date?

    public private(set) var sessionGuestState: SessionGuestState?
    public private(set) var connected: Bool = false
    public let server: SMBServer
    public let credentials: Credentials
    /// Array of strings, IP addresses to use when checking reachability
    public var wifiReachabilityVerificationIPs: [String] = ["8.8.8.8"]

    public var maxTaskOperationCount = OperationQueue.defaultMaxConcurrentOperationCount

    // tasks
    var downloadTasks: [SessionDownloadTask] = []
    var uploadTasks: [SessionUploadTask] = []
    lazy var taskQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public init(server: SMBServer, credentials: SMBSession.Credentials = .guest) {
        self.server = server
        self.credentials = credentials
    }

    public var deviceIsOnWiFi: Bool {
        for address in self.wifiReachabilityVerificationIPs {
            let result = checkReachabilityFor(ipAddress: address)
            if result {
                return true
            }
        }
        return false
    }

    private func checkReachabilityFor(ipAddress: String) -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, ipAddress) else { return false }
        var flags = SCNetworkReachabilityFlags()
        let getFlags = SCNetworkReachabilityGetFlags(reachability, &flags)
        if !getFlags {
            return false
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let isNetworkReachable = (isReachable && !needsConnection)

        if !isNetworkReachable {
            return false
        } else if flags.contains(.isWWAN) {
            return false
        }

        return true
    }

    public func requestVolumes() -> Result<[SMBVolume], SMBSessionError> {
        let conError = self.attemptConnection()
        // switch result/error
        if let error = conError {
            return Result.failure(error)
        }

        var list: smb_share_list? = nil
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
        shareCount.deallocate(capacity: 1)

        return Result.success(results)
    }

    public func requestVolumes(completionQueue: DispatchQueue = DispatchQueue.main,
                               completion: @escaping (_ result: Result<[SMBVolume], SMBSessionError>) -> Void) {
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

    public func requestItems(atPath path: SMBPath) -> Result<[SMBItem], SMBSessionError> {
        var treeId = smb_tid(0)

        let connectResult = self.treeConnect(volume: path.volume)
        switch connectResult {
        case .success(let tid):
            treeId = tid
        case .failure(let error):
            return Result.failure(error)
        }

        // \SampleMedia\*
        let statList = smb_find(self.rawSession, treeId, path.searchPath.cString(using: .utf8))
        if statList == nil {
            return Result.failure(SMBSessionError.unableToConnect)
        }
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
                             completion: @escaping (_ result: Result<[SMBItem], SMBSessionError>) -> Void) {
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
        if !self.deviceIsOnWiFi {
            return SMBSessionError.notOnWiFi
        }

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
                                                   Int32(libdsm.SMB_TRANSPORT_TCP))
        // connectionResult == -3 on timeout
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

    @discardableResult public func downloadTaskForFile(file: SMBFile,
                                                       destinationFileURL: URL?,
                                                       delegate: SessionDownloadTaskDelegate?) -> SessionDownloadTask {
        let task = SessionDownloadTask(session: self,
                                       sourceFile: file,
                                       destinationFileURL: destinationFileURL,
                                       delegate: delegate)
        self.downloadTasks.append(task)
        task.resume()
        return task
    }

    // uploadTaskForFile(toPath: path, withName: fileName, data: data, delegate: self)
//    @discardableResult public func uploadTaskForData(toPath path: SMBPath,
//                                                     withName fileName: String,
//                                                     uploadExtension: String? = nil,
//                                                     data: Data,
//                                                     delegate: SessionUploadTaskDelegate?) -> SessionUploadTask {
//        let task = SessionUploadTask(session: self,
//                                     path: path,
//                                     fileName: fileName,
//                                     uploadExtension: uploadExtension,
//                                     data: data,
//                                     delegate: delegate)
//        self.uploadTasks.append(task)
//        task.resume()
//        return task
//    }

    @discardableResult public func uploadTaskForFile(toPath path: SMBPath,
                                                     withName fileName: String,
                                                     uploadExtension: String? = nil,
                                                     fromURL url: URL,
                                                     delegate: SessionUploadTaskDelegate?) -> Result<SessionUploadTask, SessionUploadTask.SessionUploadError> {
        if !FileManager.default.fileExists(atPath: url.path) {
            return Result.failure(SessionUploadTask.SessionUploadError.fileNotFound)
        }

        let task = SessionUploadTask(session: self,
                                     path: path,
                                     fileName: fileName,
                                     uploadExtension: uploadExtension,
                                     fromURL: url,
                                     delegate: delegate)
        self.uploadTasks.append(task)
        task.resume()
        return Result.success(task)
    }

    func cancelAllRequests() {
        self.dataQueue.cancelAllOperations()
    }

    internal func treeConnect(volume: SMBVolume) -> Result<smb_tid, SMBSessionError> {
        var treeId = smb_tid(0)
        // ### confirm server is still available
        let smbSessionError = self.attemptConnection()
        if let err = smbSessionError {
            return Result.failure(err)
        }

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

    internal func fileStat(treeId: smb_tid, file: SMBFile) -> Result<SMBFile, SMBSessionError> {
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

    internal func fileOpen(treeId: smb_tid, path: String, mod: UInt32) -> Result<smb_fd, SMBSessionError> {
        var fd = smb_fd(0)
        let openResult = smb_fopen(self.rawSession, treeId, path.cString(using: .utf8), mod, &fd)
        if openResult != 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        } else {
            return Result.success(fd)
        }
    }

    internal func fileMove(volume: SMBVolume, oldPath: String, newPath: String) -> SMBMoveError? {
        var treeId = smb_tid(0)

        let smbSessionError = self.attemptConnection()
        if smbSessionError != nil {
            return SMBMoveError.failed
        }

        // ### connect to share
        let conn = self.treeConnect(volume: volume)
        switch conn {
        case .failure:
            return SMBMoveError.failed
        case .success(let t):
            treeId = t
        }

        let mvResult = smb_file_mv(self.rawSession, treeId, oldPath.cString(using: .utf8), newPath.cString(using: .utf8))
        if mvResult != 0 {
            return SMBMoveError.failed
        }
        return nil
    }

    internal func fileDelete(volume: SMBVolume, path: String) -> SMBDeleteError? {
        var treeId = smb_tid(0)

        let smbSessionError = self.attemptConnection()
        if smbSessionError != nil {
            return SMBDeleteError.failed
        }

        // ### connect to share
        let conn = self.treeConnect(volume: volume)
        switch conn {
        case .failure:
            return SMBDeleteError.failed
        case .success(let t):
            treeId = t
        }

        let result = smb_file_rm(self.rawSession, treeId, path.cString(using: .utf8))
        if result == 0 {
            return nil
        } else {
            return SMBDeleteError.failed
        }
    }

    // @return The current read pointer position or -1 on error
    internal func fileSeek(fileId: smb_fd, offset: UInt64) -> Result<Int, SMBSessionError> {
        let result = smb_fseek(self.rawSession, fileId, Int64(offset), Int32(libdsm.SMB_SEEK_SET))
        if result < 0 {
            return Result.failure(SMBSessionError.unableToConnect)
        } else {
            return Result.success(result)
        }
    }

    internal func fileRead(fileId: smb_fd, bufferSize: UInt) -> Result<Data, SMBSessionError> {
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
        case notOnWiFi
        case unableToResolveAddress
        case unableToConnect
        case authenticationFailed
        case disconnectFailed
    }

    public enum SMBMoveError: Error {
        case failed
    }

    public enum SMBDeleteError: Error {
        case failed
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

extension SMBSession.Credentials: CustomDebugStringConvertible {
    public var debugDescription: String {
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

extension SMBSession.SMBSessionError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .notOnWiFi:
            return "Not on wifi"
        case .authenticationFailed:
            return "Authentication failed"
        case .disconnectFailed:
            return "Disconnect failed"
        case .unableToConnect:
            return "Unable to connect"
        case .unableToResolveAddress:
            return "Unable to resolve address"
        }
    }
}
