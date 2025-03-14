//
//  HelpView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  HelpView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section(header: Text("Getting Started")) {
                NavigationLink("How to Use TintSpace") {
                    HowToUseView()
                }
                
                NavigationLink("Tips & Tricks") {
                    TipsView()
                }
            }
            
            Section(header: Text("Support")) {
                Link("Contact Us", destination: URL(string: "https://tintspace.app/contact")!)
                Link("Privacy Policy", destination: URL(string: "https://tintspace.app/privacy")!)
            }
        }
        .navigationTitle("Help")
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HelpView()
        }
    }
}
