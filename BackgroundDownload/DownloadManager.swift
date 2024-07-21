//
//  DownloadManager.swift
//  BackgroundDownload
//
//  Created by Youssef Ghattas on 18/07/2024.
//

import Foundation

private let hugeFile = "https://drive.google.com/uc?export=download&id=1ymaHyZjqIqF7YZ4wQcWpw_mPcIMYMwBX"
private let largeFile = "https://drive.google.com/uc?export=download&id=1LKCIX6NPN6pqmc9RwifkOIj9W9HttjCi"
private let mediumFile = "https://drive.google.com/uc?export=download&id=1OUMC0WxUy6iEyCLvM8RESWllHeC7p9cF"
private let smallFile = "https://drive.google.com/uc?export=download&id=1ayeLvmGivtZUFeu3_yh8qo99hJNFReYI"

import Foundation
import SwiftUI
import Combine

class DownloadManager: NSObject, ObservableObject {
    enum DownloadState {
        case idle
        case downloading(progress: Double, time: TimeInterval)
        case completed(url: URL, size: Int64, time: TimeInterval)
        case error(error: Error, time: TimeInterval)
    }
    
    @Published private(set) var downloadState: DownloadState = .idle
    
    private var backgroundSession: URLSession!
    private let backgroundSessionIdentifier = "com.example.backgroundsession"
    private var subscriptions = Set<AnyCancellable>()
    private var activeSessions = [URLSessionTask]()
    private var startTime = Date()
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startBackgroundDownload() {
        if !activeSessions.isEmpty { return }
        guard let url = URL(string: smallFile) else {
            print("Invalid URL")
            return
        }
        startDownload(from: url)
    }
    
    private func startDownload(from url: URL) {
        let downloadTask = backgroundSession.downloadTask(with: url)
        activeSessions.append(downloadTask)
        downloadTask.resume()
        startTime = Date()
    }
}

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.activeSessions.removeAll()
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent("downloadedFile.zip")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
            DispatchQueue.main.async {
                self.downloadState = .completed(url: destinationURL, size: fileSize, time: self.startTime.timeIntervalSince(Date()))
                self.activeSessions.removeAll()
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.activeSessions.removeAll()
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.activeSessions.removeAll()
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print(progress * 100)
        DispatchQueue.main.async {
            self.downloadState = .downloading(progress: progress, time: self.startTime.timeIntervalSince(Date()))
        }
    }
}