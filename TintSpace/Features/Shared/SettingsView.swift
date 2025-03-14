//
//  SettingsView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  SettingsView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        List {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $themeManager.themeType) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section(header: Text("About")) {
                NavigationLink("About TintSpace") {
                    AboutView()
                }
                
                NavigationLink("Help & Tips") {
                    HelpView()
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(AppConfig.appVersion) (\(AppConfig.buildNumber))")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(ThemeManager())
                .navigationTitle("Settings")
        }
    }
}
