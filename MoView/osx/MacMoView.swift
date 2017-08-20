/*

 MoView by hyouuu, made for Pendo, based on SPUserResizableView.

 It is a movable, resizable view, with special attention to be used with UIImage, thus providing Save, Copy and Delete menu options.

 MoView will call superview.endEditing() when receiving touch; client should call endEditing on any other firstResponder, or it might cancel MoView's touch abruptly

 Copyright © 2017 Lychee Isle. All rights reserved.

 */

import AppKit

public protocol MoViewDelegate: class {
    func moViewDidBeginEditing(_ moView: MoView)
    func moViewDidEndEditing(_ moView: MoView, edited: Bool)

    func moViewTapped(_ moView: MoView)

    func moViewCopyTapped(_ moView: MoView)
    func moViewSaveTapped(_ moView: MoView)
    func moViewDeleteTapped(_ moView: MoView)

    // macOS only - iOS please stub and return nil
    func moViewRequestImage(_ moView: MoView) -> NSImage?
}

public class MoView: NSView {

    // MARK: Static Vars

    open static var defaultMinX: CGFloat = -100
    open static var defaultMinY: CGFloat = -100

    open static var defaultMinWidth: CGFloat = 60
    open static var defaultMinHeight: CGFloat = 60

    // MARK: Public Vars

    open weak var delegate: MoViewDelegate?

    // Editing switches
    open var enableMoving = true
    open var enablePinchResizing = true
    open var enableDragResizing = false

    // By default if the touch is in the outside 10% area, it will be ignored for tap and drag actions (pinch is not affected)
    // Set this to 0 to disable exclusion
    open var excludeAreaRatio: CGFloat = 0.1
    open var excludeAreaMaxWidth: CGFloat = 30
    open var enableTapping = true

    // Menu switches
    open var enableCopy = true {
        didSet {
            self.setupMacMenu()
        }
    }
    open var enableSave = true {
        didSet {
            self.setupMacMenu()
        }
    }
    open var enableDelete = true {
        didSet {
            self.setupMacMenu()
        }
    }

    // Positions
    open var minX: CGFloat = MoView.defaultMinX
    open var minY: CGFloat = MoView.defaultMinY
    open var minWidth: CGFloat = MoView.defaultMinWidth
    open var minHeight: CGFloat = MoView.defaultMinHeight

    // Edge inset for touch detection
    open var edgeInset: CGFloat = 1

    // Border dragging (resizing) vs inner dragging (moving)
    open var boundMargin: CGFloat = 50
    // Pad beyond the boundMargin to sense (resizing) touch
    open var boundPad: CGFloat = 10

    var cornerRadius: CGFloat = 9.0

    // Whether keeping view's original ratio while resizing
    open var keepRatio = true

    // The touch point's distance to cetner must be factored and still greater
    // than distance to a corner to start resizing - factor higher resize easier.
    open var resizeDistanceToCenterFactor: CGFloat = 0.5

    // Disables the user from dragging the view outside the parent view's bounds.
    open var preventsPositionOutsideSuperview = false

    // Should provide localized titles for i18n
    open var copyItemTitle = NSLocalizedString("Copy", comment: "")
    open var saveItemTitle = NSLocalizedString("Save", comment: "")
    open var deleteItemTitle = NSLocalizedString("Delete", comment: "")

    // Holds to an original media object for the view, e.g. a media object in DB.
    // It's more like a convenient link, and probably not useful for every instance
    open var media: Any?

    // The actual view to be assigned from client
    open var contentView: NSView? {
        willSet {
            if let contentView = contentView {
                contentView.removeFromSuperview()
            }
        }
        didSet {
            if let contentView = contentView {
                contentView.frame = self.bounds.insetBy(dx: edgeInset, dy: edgeInset);
                contentView.layer?.cornerRadius = cornerRadius
                contentView.layer?.masksToBounds = true
                addSubviewIfNeeded(contentView)
            }
        }
    }

    // MARK: Private Vars

    // Will be initiated when the MoView's frame is set to keep ratio
    fileprivate var initialViewSize = CGSize.zero

    override open var frame: CGRect {
        didSet {
            contentView?.frame = self.bounds.insetBy(dx: edgeInset, dy: edgeInset);
            initialViewSize = self.bounds.size
        }
    }

    fileprivate var dragStartScreenPoint = NSPoint.zero
    fileprivate var superviewScreenFrame = NSRect.zero

    fileprivate var cursor: NSCursor?
    fileprivate var trackingArea: NSTrackingArea?

    // MARK: Shared funcs

    @objc func copyItem() {
        delegate?.moViewCopyTapped(self)
    }

    @objc func saveItem() {
        delegate?.moViewSaveTapped(self)
    }

    @objc func deleteItem() {
        delegate?.moViewDeleteTapped(self)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        if isUserInteractionEnabled && enableMoving {
            self.cursor = NSCursor.openHand()
        } else {
            self.cursor = NSCursor.arrow()
        }

        setupMacMenu()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Mac Specific

extension MoView {

    func setupMacMenu() {
        if !enableCopy && !enableSave && !enableDelete {
            return
        }

        let menu = NSMenu()
        if enableCopy {
            let copyItem = NSMenuItem(title: copyItemTitle, action: #selector(self.copyItem), keyEquivalent: "")
            menu.addItem(copyItem)
        }

        if enableSave {
            let saveItem = NSMenuItem(title: saveItemTitle, action: #selector(self.saveItem), keyEquivalent: "")
            menu.addItem(saveItem)
        }

        if enableDelete {
            let deleteItem = NSMenuItem(title: deleteItemTitle, action: #selector(self.deleteItem), keyEquivalent: "")
            menu.addItem(deleteItem)
        }

        self.menu = menu
    }

    // MARK: Resize

    override public func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) ||
            event.modifierFlags.contains(.control) else
        {
            super.scrollWheel(with: event)
            return
        }

        delegate?.moViewDidBeginEditing(self)
        resize(inset: event.deltaY * -1)
        delegate?.moViewDidEndEditing(self, edited: true)
    }

    override public func magnify(with event: NSEvent) {
        delegate?.moViewDidBeginEditing(self)

        let velocity = event.magnification * -70
        if velocity.isNaN || velocity.isInfinite {
            return
        }
        resize(inset: velocity)
        delegate?.moViewDidEndEditing(self, edited: true)
    }

    // Will take the inset on the longer side and calculate the shorter side
    func resize(inset: CGFloat) {
        var inset = inset
        // Positive inset is shrinking
        inset = min(inset, width / 2)
        // Negative is enlarging, which doesn't need capping since
        // as the image gets larger, the inset affect overall less

        var dx = 0.f
        var dy = 0.f

        if width > height {
            dx = inset
            dy = inset * height / width
        } else {
            dy = inset
            dx = inset * width / height
        }
        let newFrame = frame.insetBy(dx: dx, dy: dy)
        guard newFrame.width > minWidth && newFrame.height > minHeight else { return }
        frame = newFrame
    }

    // MARK: Cursor

    override public func updateTrackingAreas() {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }

        let options: NSTrackingAreaOptions = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways
        ]
        trackingArea = NSTrackingArea(rect: self.bounds,
                                      options: options,
                                      owner: self,
                                      userInfo: nil)
        if let trackingArea = trackingArea {
            self.addTrackingArea(trackingArea)
        }
    }

    override public func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        cursor?.set()
    }

    override public func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = self.cursor  {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    override public func cursorUpdate(with event: NSEvent) {
        cursor?.set()
    }

    override public func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        cursor?.set()
    }

    override public func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        resetCursorRects()
        NSCursor.arrow().set()
    }

    // MARK: Drag related

    // Take a snapshot of a current state NSView and return an NSImage
    func snapshot() -> NSImage {
        let pdfData = dataWithPDF(inside: bounds)
        let image = NSImage(data: pdfData)
        return image ?? NSImage()
    }

    override public func mouseDown(with theEvent: NSEvent) {
        cursor = NSCursor.closedHand()
        cursor?.set()

        guard isUserInteractionEnabled && enableMoving else { return }
        delegate?.moViewDidBeginEditing(self)

        // Get image ready for pasteboard to support drag & drop to outside destination
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(self, forTypes: [kUTTypeTIFF])

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(self.bounds, contents:snapshot())

        beginDraggingSession(with: [draggingItem], event: theEvent, source: self)
    }

    override public func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        releaseMouse()
    }

    func releaseMouse() {
        if isUserInteractionEnabled && enableMoving {
            self.cursor = NSCursor.openHand()
        } else {
            self.cursor = NSCursor.arrow()
        }
        cursor?.set()
    }

    public func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        guard let superview = superview, let superWindow = superview.window else { return }

        let frameRelativeToWindow = superview.convert(superview.bounds, to: nil)
        superviewScreenFrame = superWindow.convertToScreen(frameRelativeToWindow)
        dragStartScreenPoint = screenPoint
    }

    public func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        if superviewScreenFrame.contains(screenPoint) {
            session.animatesToStartingPositionsOnCancelOrFail = false

        } else {
            session.animatesToStartingPositionsOnCancelOrFail = true
        }
    }

    public func draggingSession(_ session: NSDraggingSession,
                                endedAt screenPoint: NSPoint,
                                operation: NSDragOperation)
    {
        defer { releaseMouse() }
        guard superviewScreenFrame.contains(screenPoint) else {
            delegate?.moViewDidEndEditing(self, edited: false)
            return
        }

        if screenPoint != dragStartScreenPoint {
            moveTo(screenPoint, from: dragStartScreenPoint)
            delegate?.moViewDidEndEditing(self, edited: true)
        } else {
            delegate?.moViewDidEndEditing(self, edited: false)
        }
    }
}

// MARK: - NSDraggingSource

extension MoView: NSDraggingSource {
    public func draggingSession(_ session: NSDraggingSession,
                                sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation
    {
        if context == .withinApplication {
            return .generic
        } else {
            return .copy
        }
    }
}

// MARK: - NSPasteboardItemDataProvider

extension MoView: NSPasteboardItemDataProvider {
    public func pasteboard(_ pasteboard: NSPasteboard?,
                           item: NSPasteboardItem,
                           provideDataForType type: String)
    {
        guard let pasteboard = pasteboard,
            let image = delegate?.moViewRequestImage(self) else {
                return
        }

        if type == String(kUTTypeTIFF) ||
            type == NSTIFFPboardType
        {
            let tiffdata = image.tiffRepresentation
            pasteboard.setData(tiffdata, forType: type)

        } else if type == NSPDFPboardType {
            pasteboard.setData(dataWithPDF(inside: bounds), forType: type)
        }
    }
}
