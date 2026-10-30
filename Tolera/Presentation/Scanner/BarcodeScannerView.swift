import SwiftUI
import VisionKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        uiViewController.delegate = context.coordinator
        guard !context.coordinator.hasStartedScanning else { return }
        context.coordinator.hasStartedScanning = true
        try? uiViewController.startScanning()
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var hasScanned = false
        var hasStartedScanning = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScanned else { return }

            for item in addedItems {
                guard case let .barcode(barcode) = item, let payload = barcode.payloadStringValue else {
                    continue
                }
                hasScanned = true
                dataScanner.stopScanning()
                onScan(payload)
                break
            }
        }
    }
}
