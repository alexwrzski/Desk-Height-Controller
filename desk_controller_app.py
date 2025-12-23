#!/usr/bin/env python3
"""
Desk Controller - Native macOS Application
A standalone native app that embeds the web interface in a native window
"""

import sys
import threading
import time
from flask import Flask, render_template_string

# Import the web app template
from web_app import HTML_TEMPLATE, ESP32_IP_DEFAULT

# Try PyQt5 first (easier to install), fall back to PySide6, then PyObjC
try:
    from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
    from PyQt5.QtWebEngineWidgets import QWebEngineView
    from PyQt5.QtCore import QUrl, Qt, QSize
    from PyQt5.QtGui import QIcon
    GUI_FRAMEWORK = "PyQt5"
except ImportError:
    try:
        from PySide6.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
        from PySide6.QtWebEngineWidgets import QWebEngineView
        from PySide6.QtCore import QUrl, Qt, QSize
        from PySide6.QtGui import QIcon
        GUI_FRAMEWORK = "PySide6"
    except ImportError:
        try:
            from AppKit import NSApplication, NSWindow, NSWindowStyleMask, NSBackingStoreBuffered
            from WebKit import WKWebView, WKWebViewConfiguration
            from Foundation import NSURL, NSRect, NSPoint, NSSize
            from PyObjCTools import AppHelper
            GUI_FRAMEWORK = "PyObjC"
        except ImportError:
            GUI_FRAMEWORK = None

# Flask app
app = Flask(__name__)

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE, esp32_ip=ESP32_IP_DEFAULT)

def start_flask_server():
    """Start Flask server in a separate thread"""
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)

class DeskControllerApp:
    def __init__(self):
        if GUI_FRAMEWORK == "PyQt5" or GUI_FRAMEWORK == "PySide6":
            self.app = QApplication(sys.argv)
            self.app.setApplicationName("Desk Controller")
            self.window = QMainWindow()
            self.setup_qt_window()
        elif GUI_FRAMEWORK == "PyObjC":
            self.app = NSApplication.sharedApplication()
            self.window = None
            self.setup_cocoa_window()
        else:
            print("No GUI framework available!")
            print("Please install one of:")
            print("  pip3 install PyQt5")
            print("  pip3 install PySide6")
            print("  pip3 install pyobjc-framework-WebKit")
            sys.exit(1)
    
    def setup_qt_window(self):
        """Setup PyQt5/PySide6 window"""
        self.window.setWindowTitle("Desk Controller")
        self.window.setMinimumSize(380, 600)
        self.window.resize(420, 800)
        
        # Center window
        screen = self.app.primaryScreen().geometry()
        window_geometry = self.window.frameGeometry()
        window_geometry.moveCenter(screen.center())
        self.window.move(window_geometry.topLeft())
        
        # Create central widget and layout
        central_widget = QWidget()
        self.window.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Create web view
        self.web_view = QWebEngineView()
        self.web_view.setUrl(QUrl("http://localhost:5000"))
        layout.addWidget(self.web_view)
        
        # Set window icon if available
        import os
        icon_path = os.path.join(os.path.dirname(__file__), "desk_icon.icns")
        if os.path.exists(icon_path):
            # Convert .icns to .png for Qt (simplified - just try to set it)
            pass  # Qt doesn't directly support .icns, would need conversion
    
    def setup_cocoa_window(self):
        """Setup PyObjC/Cocoa window"""
        screen_frame = self.app.mainWindow().screen().frame() if self.app.mainWindow() else None
        if screen_frame:
            window_width = 420
            window_height = 800
            x = (screen_frame.size.width - window_width) / 2
            y = (screen_frame.size.height - window_height) / 2
            frame = NSRect(NSPoint(x, y), NSSize(window_width, window_height))
        else:
            frame = NSRect(NSPoint(100, 100), NSSize(420, 800))
        
        self.window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            frame,
            NSWindowStyleMask.Titled | NSWindowStyleMask.Closable | NSWindowStyleMask.Miniaturizable,
            NSBackingStoreBuffered,
            False
        )
        
        self.window.setTitle_("Desk Controller")
        self.window.setMinSize_(NSSize(380, 600))
        self.window.center()
        
        config = WKWebViewConfiguration.alloc().init()
        self.web_view = WKWebView.alloc().initWithFrame_configuration_(
            self.window.contentView().bounds(),
            config
        )
        
        self.web_view.setAutoresizingMask_(0x12)
        self.window.contentView().addSubview_(self.web_view)
        
        url = NSURL.URLWithString_("http://localhost:5000")
        request = NSURLRequest.requestWithURL_(url)
        self.web_view.loadRequest_(request)
    
    def run(self):
        """Run the application"""
        # Start Flask server in background
        flask_thread = threading.Thread(target=start_flask_server, daemon=True)
        flask_thread.start()
        
        # Wait for server to start
        time.sleep(2)
        
        if GUI_FRAMEWORK == "PyQt5" or GUI_FRAMEWORK == "PySide6":
            self.window.show()
            sys.exit(self.app.exec_())
        elif GUI_FRAMEWORK == "PyObjC":
            self.window.makeKeyAndOrderFront_(None)
            self.app.activateIgnoringOtherApps_(True)
            AppHelper.runEventLoop()

def main():
    app = DeskControllerApp()
    app.run()

if __name__ == '__main__':
    main()
