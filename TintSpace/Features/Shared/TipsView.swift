//
//  TipsView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  TipsView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct TipsView: View {
    var body: some View {
        List {
            Text("Ensure good lighting for best results")
            Text("Use the finish options to see how different sheens look")
            Text("Compare colors side-by-side on different walls")
            Text("Save your favorite colors for future reference")
            Text("Take screenshots to share with others")
        }
        .navigationTitle("Tips & Tricks")
    }
}

struct TipsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TipsView()
        }
    }
}
