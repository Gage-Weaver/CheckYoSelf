//
//  ScanState.swift
//  CheckYoSelf
//
//  Created by Carlos Mbendera on 29/03/2025.
//

import SwiftUI
import RealityKit

extension ObjectCaptureSession.CaptureState {
    
    var label: String {
        switch self {
        case .initializing:
            "initializing"
        case .ready:
            "ready"
        case .detecting:
            "detecting"
        case .capturing:
            "capturing"
        case .finishing:
            "finishing"
        case .completed:
            "completed"
        case .failed(let error):
            "failed: \(String(describing: error))"
        @unknown default:
            fatalError("unknown default: \(self)")
        }
    }
}
