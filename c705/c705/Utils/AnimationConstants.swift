//
//  AnimationConstants.swift
//  c705
//
//  Created for optimized animation constants
//
//  PURPOSE: A shelf of ready-made animation styles. Defining them once keeps
//  animations consistent and lets you tune the feel of the whole app
//  in one place.
//

import SwiftUI

// A spring animation bounces slightly into place. Smaller numbers make it faster and tighter.
struct AppAnimations {
    // Fast, smooth spring animations
    static let fastSpring = Animation.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)
    static let smoothSpring = Animation.spring(response: 0.3, dampingFraction: 0.85, blendDuration: 0)
    static let quickSpring = Animation.spring(response: 0.2, dampingFraction: 0.75, blendDuration: 0)
    
    // List/item animations
    // A transition is how a view appears or disappears, for example fading in while sliding
    // down.
    static let listTransition = AnyTransition.opacity.combined(with: .move(edge: .top))
    static let slideTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    // Scale animations
    static let scaleTransition = AnyTransition.scale.combined(with: .opacity)
    
    // Ease animations for simple transitions
    static let quickEase = Animation.easeInOut(duration: 0.2)
    static let smoothEase = Animation.easeInOut(duration: 0.3)
}

