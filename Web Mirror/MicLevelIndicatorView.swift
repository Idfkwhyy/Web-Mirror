//
//  MicLevelIndicatorView.swift
//  Web Mirror
//
//  Created by Leonardo Munarolo on 1/1/26.
//


import SwiftUI

struct MicLevelIndicatorView: View {

    let level: CGFloat

    // Threshold where we consider “sound detected”
    private let activationThreshold: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Outline mic (always visible)
            Image(systemName: "mic")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.6))

            // Filled mic (fades in with sound)
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .opacity(fillOpacity)
                .animation(.easeOut(duration: 0.12), value: fillOpacity)
        }
        .padding(8)
    }

    private var fillOpacity: CGFloat {
        level > activationThreshold ? min(level * 1.4, 1.0) : 0.0
    }
}
