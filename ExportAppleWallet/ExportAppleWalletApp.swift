//
//  ExportAppleWalletApp.swift
//  ExportAppleWallet
//
//  Created by Yulin Pu on 2025-09-30.
//

import SwiftUI

@main
struct ExportCardsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 启动即执行
                    Copier.run()
                }
        }
    }
}
