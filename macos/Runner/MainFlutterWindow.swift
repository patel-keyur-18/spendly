import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1040, height: 640)
    // minSize only clamps future resizes — it does nothing for a frame
    // already smaller than that, which macOS's window-state restoration
    // (applicationSupportsSecureRestorableState) can hand back from before
    // this minimum existed. Widen/heighten a too-small restored frame here
    // so layouts that assume at least this width (the three-across
    // dashboard row, in particular) never start out starved.
    if windowFrame.width < 1040 || windowFrame.height < 640 {
      var frame = windowFrame
      frame.size.width = max(frame.width, 1040)
      frame.size.height = max(frame.height, 640)
      self.setFrame(frame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
