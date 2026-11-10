#if canImport(UIKit)
import AVFoundation
import SwiftUI
import UIKit

/// Kamera-Ansicht, die den ersten QR-Code meldet. Ohne Kamera-Recht meldet sie das, statt still schwarz zu bleiben.
public struct QRScanner: UIViewControllerRepresentable {
    public let gefunden: (String) -> Void
    public let fehler: (String) -> Void

    public init(gefunden: @escaping (String) -> Void, fehler: @escaping (String) -> Void) {
        self.gefunden = gefunden; self.fehler = fehler
    }

    public func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.gefunden = gefunden
        c.fehler = fehler
        return c
    }

    public func updateUIViewController(_ controller: ScannerController, context: Context) {}

    public final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var gefunden: ((String) -> Void)?
        var fehler: ((String) -> Void)?
        private let sitzung = AVCaptureSession()
        private var gemeldet = false

        public override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            AVCaptureDevice.requestAccess(for: .video) { [weak self] erlaubt in
                DispatchQueue.main.async {
                    if erlaubt { self?.einrichten() } else {
                        self?.fehler?("Kein Zugriff auf die Kamera. In den Einstellungen erlauben oder den Code einfügen.")
                    }
                }
            }
        }

        private func einrichten() {
            guard let kamera = AVCaptureDevice.default(for: .video),
                  let eingang = try? AVCaptureDeviceInput(device: kamera), sitzung.canAddInput(eingang) else {
                fehler?("Die Kamera lässt sich nicht öffnen.")
                return
            }
            sitzung.addInput(eingang)
            let ausgang = AVCaptureMetadataOutput()
            guard sitzung.canAddOutput(ausgang) else { fehler?("Die Kamera liefert keine Codes."); return }
            sitzung.addOutput(ausgang)
            ausgang.setMetadataObjectsDelegate(self, queue: .main)
            ausgang.metadataObjectTypes = [.qr]
            let vorschau = AVCaptureVideoPreviewLayer(session: sitzung)
            vorschau.frame = view.layer.bounds
            vorschau.videoGravity = .resizeAspectFill
            view.layer.addSublayer(vorschau)
            DispatchQueue.global(qos: .userInitiated).async { [sitzung] in sitzung.startRunning() }
        }

        public override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            view.layer.sublayers?.forEach { $0.frame = view.layer.bounds }
        }

        public override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if sitzung.isRunning { sitzung.stopRunning() }
        }

        public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objekte: [AVMetadataObject],
                                   from connection: AVCaptureConnection) {
            guard !gemeldet, let code = objekte.first as? AVMetadataMachineReadableCodeObject,
                  let text = code.stringValue else { return }
            gemeldet = true
            sitzung.stopRunning()
            gefunden?(text)
        }
    }
}
#endif
