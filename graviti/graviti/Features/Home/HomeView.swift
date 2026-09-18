//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            GravitiColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                GravitiWordmark(
                    size: .large,
                    animated: true
                )

                Text("Save what pulls you.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

#Preview {
    HomeView()
}
