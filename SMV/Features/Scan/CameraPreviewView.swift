//
//  CameraPreviewView.swift
//  SMV
//
//  UIViewRepresentable bridge for AVCaptureVideoPreviewLayer.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

// MARK: - UIView Wrapper

class CameraPreviewUIView: UIView {

    var session: AVCaptureSession? {
        didSet {
            (layer as? AVCaptureVideoPreviewLayer)?.session = session
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.videoGravity = .resizeAspectFill
    }
}
