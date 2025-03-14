//
//  HowToUseView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  HowToUseView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Point your camera at a wall")
                        .font(.headline)
                    Text("The app will automatically detect vertical surfaces.")
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("2. Tap on a wall to select it")
                        .font(.headline)
                    Text("Selected walls will be highlighted.")
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("3. Choose a color from the palette")
                        .font(.headline)
                    Text("Or use the color wheel to create a custom color.")
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("4. See the wall in your chosen color")
                        .font(.headline)
                    Text("The color will be applied with realistic lighting.")
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("How to Use")
    }
}

struct HowToUseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HowToUseView()
        }
    }
}
