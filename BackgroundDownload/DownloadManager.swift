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
private let BG_TASK_ID = "com.youssef.BackgroundDownload.BGTask"
private let TARGET_DATE_KEY = "targetExecutionDate"
private let TASK_COMPLETED_KEY = "taskCompleted"

import Foundation
import Combine
import BackgroundTasks


class DownloadManager: NSObject, ObservableObject {
    enum DownloadState {
        case idle
        case downloading(progress: Double, time: TimeInterval)
        case completed(url: URL, size: Int64, time: TimeInterval)
        case error(error: Error, time: TimeInterval)
    }
    
    @Published private(set) var downloadState: DownloadState = .idle
    
    private let notificationCenter = NotificationCenter()
    
    private var backgroundSession: URLSession!
    private let backgroundSessionIdentifier = "com.example.backgroundsession"
    private var subscriptions = Set<AnyCancellable>()
        
    private var startTime = Date()
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        notificationCenter.requestNotificationAuthorization()
        
        registerDownloadTask()
        scheduleCheckPeriodically()
    }
    
    func scheduleDownloadTask() {
        let threeHours: TimeInterval = 3 * 60 * 60
        let targetDate = Date().addingTimeInterval(threeHours)
        UserDefaults.standard.set(targetDate, forKey: TARGET_DATE_KEY)
        UserDefaults.standard.set(false, forKey: TASK_COMPLETED_KEY)
        scheduleCheckPeriodically()
    }
    
    private func registerDownloadTask() {
        let isRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: BG_TASK_ID, using: nil) { [unowned self] task in
            handleDownload(task: task as! BGAppRefreshTask)
            task.expirationHandler = {
                print("Background task expired")
                self.scheduleCheckPeriodically()
            }
        }
        print(isRegistered)
    }
    
    private func handleDownload(task: BGAppRefreshTask) {
        checkAndPerformDownload()
        task.setTaskCompleted(success: true)
        let taskCompleted = UserDefaults.standard.bool(forKey: TASK_COMPLETED_KEY)
        if !taskCompleted {
            scheduleCheckPeriodically()
        }
    }
    
    private func checkAndPerformDownload() {
        notificationCenter.scheduleNotification(title: "Checking", description: "Checking your download status")
        guard let targetDate = UserDefaults.standard.object(forKey: TARGET_DATE_KEY) as? Date else { return }
        let taskCompleted = UserDefaults.standard.bool(forKey: TASK_COMPLETED_KEY)
        
        if !taskCompleted && Date() >= targetDate {
            notificationCenter.scheduleNotification(title: "Download Started", description: "Tap to open app")
            guard let url = URL(string: smallFile) else {
                print("Invalid URL")
                return
            }
            startDownload(from: url)
            UserDefaults.standard.set(true, forKey: TASK_COMPLETED_KEY)
        }
    }
    
    private func startDownload(from url: URL) {
        let downloadTask = backgroundSession.downloadTask(with: url)
        downloadTask.resume()
        startTime = Date()
    }
    
    private func scheduleCheckPeriodically() {
        let oneHour: TimeInterval = 1 * 60 * 60
        let request = BGAppRefreshTaskRequest(identifier: BG_TASK_ID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: oneHour)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not reschedule processing task: \(error)")
        }
    }
}

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.notificationCenter.scheduleNotification(title: "Download Failed", description: "Tap to open app")
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
                self.notificationCenter.scheduleNotification(title: "Download Completed", description: "Tap to open app")
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.notificationCenter.scheduleNotification(title: "Download Failed", description: "Tap to open app")
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.downloadState = .error(error: error, time: self.startTime.timeIntervalSince(Date()))
                self.notificationCenter.scheduleNotification(title: "Download Failed", description: "Tap to open app")
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
