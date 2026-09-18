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

            VStack(spacing: 10) {
                Text("graviti")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Save what pulls you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

#Preview {
    HomeView()
}
