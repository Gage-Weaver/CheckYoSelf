//
//  ARQuickLookView.swift
//  CheckYoSelf
//
//  Created by Carlos Mbendera on 29/03/2025.
//

import SwiftUI
import QuickLook

struct ARQuickLookView: UIViewControllerRepresentable {
    let modelFile: URL
    let endCaptureCallback: () -> Void
    let onUpload: (() -> Void)?
    
    func makeUIViewController(context: Context) -> QLPreviewControllerWrapper {
        let controller = QLPreviewControllerWrapper()
        controller.previewController.dataSource = context.coordinator
        controller.previewController.delegate = context.coordinator
        
        // Add upload button
        let uploadButton = UIBarButtonItem(
            title: "Upload",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.uploadButtonTapped)
        )
        
        controller.previewController.navigationItem.rightBarButtonItem = uploadButton
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewControllerWrapper, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
        let parent: ARQuickLookView
        
        init(parent: ARQuickLookView) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.modelFile as QLPreviewItem
        }
        
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            parent.endCaptureCallback()
        }
        
        @objc func uploadButtonTapped() {
            parent.onUpload?()
        }
    }
}

extension ARQuickLookView {
    class QLPreviewControllerWrapper: UIViewController {
        let previewController = QLPreviewController()
        var quickLookIsPresented = false
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            if !quickLookIsPresented {
                present(previewController, animated: false)
                quickLookIsPresented = true
            }
        }
    }
}
