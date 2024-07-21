//
//  NotificationCenter.swift
//  BackgroundDownload
//
//  Created by Youssef Ghattas on 21/07/2024.
//

import Foundation
import UserNotifications

struct NotificationCenter {
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permissions granted.")
            } else if let error = error {
                print("Error requesting notifications: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(title: String, description: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = description
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}
