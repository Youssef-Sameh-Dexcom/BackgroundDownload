//
//  DownloadViewModel.swift
//  BackgroundDownload
//
//  Created by Youssef Ghattas on 18/07/2024.
//

import Foundation
import Combine
import UIKit

@MainActor
class DownloadViewModel: ObservableObject {
    @Published private(set) var downloadState: DownloadManager.DownloadState = .idle
    private var downloadManager: DownloadManager = DownloadManager()
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        downloadManager.$downloadState
            .receive(on: DispatchQueue.main)
            .assign(to: \.downloadState, on: self)
            .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [unowned self] _ in
            downloadManager.startBackgroundDownload()
        }
        .store(in: &subscriptions)
    }
}
