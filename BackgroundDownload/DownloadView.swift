//
//  DownloadView.swift
//  BackgroundDownload
//
//  Created by Youssef Ghattas on 18/07/2024.
//

import SwiftUI

struct DownloadView: View {
    @StateObject var viewModel = DownloadViewModel()
    
    var body: some View {
        VStack {
            switch viewModel.downloadState {
            case .idle:
                Button("Download") {
                    viewModel.scheduleDownload()
                }
            case .downloading(let progress, let time):
                Text("Elapsed Seconds: \(time * -1)")
                Text("Downloading: \(String(format: "%.2f", progress * 100))%")
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
            case .completed(let url, let size, let time):
                Text("Download completed. File size: \(size) bytes")
                Text("File saved to: \(url.path)")
                Text("Elapsed Seconds: \(time * -1)")
            case .error(let error, let time):
                Text("Error: \(error.localizedDescription)")
                Text("Elapsed Seconds: \(time * -1)")
            }
        }
        .padding()
    }
}

#Preview {
    DownloadView()
}
