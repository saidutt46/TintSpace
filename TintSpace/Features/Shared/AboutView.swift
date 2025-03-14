//
//  AboutView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  AboutView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("TintSpace is an AR app that helps you visualize paint colors on your walls before you buy.")
                    .padding()
                
                Text("Made with ❤️ by the TintSpace team")
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("About")
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView()
        }
    }
}
