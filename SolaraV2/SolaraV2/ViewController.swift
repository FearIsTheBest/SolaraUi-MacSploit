import Cocoa
import WebKit
import SwiftUI
import Foundation

class ViewController: NSViewController {
    
    @IBOutlet weak var connectionColorSymbol: NSImageView!
    @IBAction func saveFile(_ sender: Any) {
    }
    @IBAction func openFile(_ sender: Any) {
    }
    @IBAction func clearEditor(_ sender: Any) {
    }
    @IBAction func execute(_ sender: Any) {
        // Ensure the webView has finished loading
        if webView.isLoading {
            print("WebView is still loading.")
            return
        }
        
        // JavaScript to get the content of the Ace Editor
        let getEditorContentScript = "getEditorContent();"
        
        // Evaluate JavaScript to get the editor content
        webView.evaluateJavaScript(getEditorContentScript) { (result, error) in
            if let error = error {
                print("Failed to evaluate JavaScript: \(error.localizedDescription)")
                return
            }
            
            // Check if the result is a string
            if let editorContent = result as? String {
                // Print or use the content
                print("Editor content retrieved: \(editorContent)")
                
                // Send the content to the client
                self.client?.send(data: editorContent)
            } else {
                print("No content retrieved or content is not a string. Result: \(String(describing: result))")
            }
        }
    }
    private var client: Client?
    
    func convertToNSColor(color: Color) -> NSColor {
        // Create a SwiftUI color view to extract the NSColor
        let nsColor = NSColor(color)
        return nsColor
    }
    
    func applyTintColor(to imageView: NSImageView, color: Color) {
        let nsColor = convertToNSColor(color: color)
        
        // Ensure the imageView has a layer
        if imageView.layer == nil {
            imageView.wantsLayer = true
        }
        
        // Create an overlay view with the tint color
        let overlayView = NSView(frame: imageView.bounds)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = nsColor.withAlphaComponent(0.3).cgColor // Adjust alpha as needed
        overlayView.autoresizingMask = [.width, .height]
        
        // Remove any existing overlays
        imageView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add the new overlay
        imageView.addSubview(overlayView)
    }
    
    @IBAction func attach(_ sender: Any) {
        
        let ports: ClosedRange<Int> = 5553...5563
        let selectedPort: UInt16 = UInt16(ports.lowerBound)
        client = Client(port: selectedPort)
        client?.reconnect(port: selectedPort)
        
        if let color = client?.connectionColor {
            self.connectionColorSymbol.image = NSImage(named: NSImage.statusAvailableName)
        }
    }
    @IBOutlet weak var webView: WKWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let webView = webView {
            if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
        
        view.wantsLayer = true // Enable the view's layer
        view.layer?.backgroundColor = NSColor(red: 9/255, green: 0/255, blue: 14/255, alpha: 1.0).cgColor
    }
}

var representedObject: Any? {
    didSet {
        // Update the view, if already loaded.
    }
}




