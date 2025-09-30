//
//  ContentView.swift
//  ExportAppleWallet
//
//  Created by Yulin Pu on 2025-09-30.
//

import SwiftUI
import CryptoKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("ExportAppleWallet")
                .font(.largeTitle).bold()
            Text("启动后会把 Wallet 卡片背景导出到桌面 /Cards")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("再次执行导出") {
                Copier.run()
            }
            .padding(.top, 8)
        }
        .frame(width: 420, height: 220)
        .padding()
    }
}

import AppKit
import UserNotifications

enum Copier {
    private static func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func run() {
        do {
            let source = expandTilde("~/Library/Passes/Cards")
            let dest   = expandTilde("~/Desktop/Cards")

            let fm = FileManager.default
            try fm.createDirectory(atPath: dest, withIntermediateDirectories: true)

            let destURL = URL(fileURLWithPath: dest)
            let destFiles = (try? fm.contentsOfDirectory(at: destURL, includingPropertiesForKeys: nil)) ?? []
            var existingHashes = Set<String>()
            for file in destFiles where file.pathExtension.lowercased() == "png" {
                if let h = sha256(of: file) { existingHashes.insert(h) }
            }

            // 找到所有 .pkpass 包里名为 cardBackgroundCombined@2x.png 的文件
            let srcURL = URL(fileURLWithPath: source)
            guard let enumr = fm.enumerator(at: srcURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                notify(title: "导出失败", body: "无法访问 Passes 目录")
                return
            }

            var found: [URL] = []
            for case let fileURL as URL in enumr {
                let path = fileURL.path
                if path.contains(".pkpass/"),
                   fileURL.lastPathComponent == "cardBackgroundCombined@2x.png" {
                    found.append(fileURL)
                }
            }

            if found.isEmpty {
                notify(title: "没有找到可导出的图片", body: "检查是否存在 Wallet 卡或文件名变化")
                return
            }

            // 确定从几开始编号：读取现有的 N.png，接着往后排
            let existingNumbers = (try? fm.contentsOfDirectory(atPath: dest))?
                .compactMap { $0.replacingOccurrences(of: ".png", with: "") }
                .compactMap(Int.init) ?? []
            var nextIndex = (existingNumbers.max() ?? 0) + 1

            var copiedCount = 0
            var skippedDuplicates = 0
            for url in found.sorted(by: { $0.path < $1.path }) {
                guard let h = sha256(of: url) else { continue }
                if existingHashes.contains(h) {
                    // 已存在相同内容，跳过
                    skippedDuplicates += 1
                    continue
                }
                let outURL = destURL.appendingPathComponent("\(nextIndex).png")
                try fm.copyItem(at: url, to: outURL)
                existingHashes.insert(h)
                copiedCount += 1
                nextIndex += 1
            }

            notify(title: "导出完成", body: "新增复制 \(copiedCount) 张到桌面/Cards")
            if skippedDuplicates > 0 {
                notify(title: "已跳过重复", body: "发现 \(skippedDuplicates) 个重复图片")
            }
            // 自动打开目标文件夹
            NSWorkspace.shared.activateFileViewerSelecting([destURL])

        } catch {
            notify(title: "导出出错", body: error.localizedDescription)
        }
    }

    private static func expandTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    // 系统通知（首次会请求授权）
    private static func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let send = {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body  = body
                let req = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content,
                                                trigger: nil)
                center.add(req, withCompletionHandler: nil)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                send()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    send()
                }
            default:
                // 用户拒绝了通知权限，静默处理
                break
            }
        }
    }
}
