/*
 
 MoView by hyouuu, made for Pendo, based on SPUserResizableView.
 
 It is a movable, resizable view, with special attention to be used with UIImage, thus providing Save, Copy and Delete menu options.
 
 MoView will call superview.endEditing() when receiving touch; client should call endEditing on any other firstResponder, or it might cancel MoView's touch abruptly
 
 Copyright © 2017 Lychee Isle. All rights reserved.

 */

#if os(iOS)
    import UIKit
    typealias MoViewParent = UIView
#else
    import AppKit
    typealias MoViewParent = NSView
#endif

public protocol MoViewDelegate: class {
    func moViewDidBeginEditing(_ moView: MoView)
    func moViewDidEndEditing(_ moView: MoView, edited: Bool)

    func moViewTapped(_ moView: MoView)

    func moViewCopyTapped(_ moView: MoView)
    func moViewSaveTapped(_ moView: MoView)
    func moViewDeleteTapped(_ moView: MoView)

    // macOS only - iOS please stub and return nil
    func moViewRequestImage(_ moView: MoView) -> Image?
}

open class MoView: MoViewParent {
    
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

    #if os(OSX)
    // By default if the touch is in the outside 10% area, it will be ignored for tap and drag actions (pinch is not affected)
    // Set this to 0 to disable exclusion
    open var excludeAreaRatio: CGFloat = 0.1
    open var excludeAreaMaxWidth: CGFloat = 30
    open var enableTapping = true
    #endif

    // Menu switches
    open var enableCopy = true {
        didSet {
            #if os(OSX)
                self.setupMacMenu()
            #endif
        }
    }
    open var enableSave = true {
        didSet {
            #if os(OSX)
                self.setupMacMenu()
            #endif
        }
    }
    open var enableDelete = true {
        didSet {
            #if os(OSX)
                self.setupMacMenu()
            #endif
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
    open var contentView: UIView? {
        willSet {
            if let contentView = contentView {
                contentView.removeFromSuperview()
            }
        }
        didSet {
            if let contentView = contentView {
                contentView.frame = self.bounds.insetBy(dx: edgeInset, dy: edgeInset);
                contentView.layer.cornerRadius = cornerRadius
                contentView.layer.masksToBounds = true
                addSubview(contentView)
            }
        }
    }

    // MARK: Private Vars

    // Will be initiated when the MoView's frame is set to keep ratio
    private var initialViewSize = CGSize.zero

    override open var frame: CGRect {
        didSet {
            contentView?.frame = self.bounds.insetBy(dx: edgeInset, dy: edgeInset);
            initialViewSize = self.bounds.size
        }
    }

    #if os(iOS) // MARK: iOS Private Vars

    private struct MoViewAnchor {
        var adjustsX: CGFloat
        var adjustsY: CGFloat
        var adjustsH: CGFloat
        var adjustsW: CGFloat

        func isResizing() -> Bool {
            return adjustsX != 0 || adjustsY != 0 || adjustsH != 0 || adjustsW != 0
        }
    }

    private struct MoViewPointToAnchor {
        var point: CGPoint
        var anchor: MoViewAnchor
    }

    // If touch moves, invalid this so at touchEnd we know if it's a tap or drag
    private var isValidTap = true

    private let noAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 0, adjustsH: 0, adjustsW: 0)

    private let centerAnchor = MoViewAnchor(adjustsX: 0.5, adjustsY: 0.5, adjustsH: 1, adjustsW: 1)

    private let upperLeftAnchor = MoViewAnchor(adjustsX: 1, adjustsY: 1, adjustsH: -1, adjustsW: 1)
    private let midLeftAnchor = MoViewAnchor(adjustsX: 1, adjustsY: 0, adjustsH: 0, adjustsW: 1)
    private let lowerLeftAnchor = MoViewAnchor(adjustsX: 1, adjustsY: 0, adjustsH: 1, adjustsW: 1)
    private let upperMidAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 1, adjustsH: -1, adjustsW: 0)
    private let upperRightAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 1, adjustsH: -1, adjustsW: -1)
    private let midRightAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 0, adjustsH: 0, adjustsW: -1)
    private let lowerRightAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 0, adjustsH: 1, adjustsW: -1)
    private let lowerMidAnchor = MoViewAnchor(adjustsX: 0, adjustsY: 0, adjustsH: 1, adjustsW: 0)

    // Used to determine which components of the bounds we'll be modifying, based upon where the user's touch started.
    private var curAnchor: MoViewAnchor?

    private var touchStart: CGPoint?

    #else  // MARK: Mac Private Vars

    private var dragStartScreenPoint = NSPoint.zero
    private var superviewScreenFrame = NSRect.zero

    private var cursor: NSCursor?
    private var trackingArea: NSTrackingArea?

    #endif

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

    #if os(iOS)

    override public init(frame: CGRect) {
        super.init(frame: frame)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MoView.longPress(_:)))
        addGestureRecognizer(longPress)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(MoView.pinch(_:)))
        addGestureRecognizer(pinch)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: nil, object: nil)
    }

    #else

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        if isUserInteractionEnabled && enableMoving {
            self.cursor = NSCursor.openHand()
        } else {
            self.cursor = NSCursor.arrow()
        }

        setupMacMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #endif
}

// MARK: iOS Specific

#if os(iOS)
extension MoView {

    // Helper for fast distance comparison
    private func distSquared(_ a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = (b.x - a.x)
        let dy = (b.y - a.y)
        return (dx * dx) + (dy * dy)
    }

    private func anchorForTouchLoc(_ touchPoint: CGPoint) -> MoViewAnchor {
        let width = bounds.width
        let height = bounds.height
        let centerPoint = CGPoint(x: width / 2, y: height / 2)

        // Edge 8 points to compare against center
        let pointToAnchors: [MoViewPointToAnchor] = [
            MoViewPointToAnchor(point: CGPoint(x: 0, y: 0), anchor: upperLeftAnchor),
            MoViewPointToAnchor(point: CGPoint(x: width / 2, y: 0), anchor: upperMidAnchor),
            MoViewPointToAnchor(point: CGPoint(x: width, y: 0), anchor: upperRightAnchor),
            MoViewPointToAnchor(point: CGPoint(x: width, y: height / 2), anchor: midRightAnchor),
            MoViewPointToAnchor(point: CGPoint(x: width, y: height), anchor: lowerRightAnchor),
            MoViewPointToAnchor(point: CGPoint(x: width / 2, y: height), anchor: lowerMidAnchor),
            MoViewPointToAnchor(point: CGPoint(x: 0, y: height), anchor: lowerLeftAnchor),
            MoViewPointToAnchor(point: CGPoint(x: 0, y: height / 2), anchor: midLeftAnchor)
        ]

        let centerDist = distSquared(touchPoint, b: centerPoint)

        var smallestDist = centerDist
        var closestAnchor = noAnchor

        for pointToAnchor in pointToAnchors {
            let dist = distSquared(touchPoint, b: pointToAnchor.point)
            if dist < smallestDist {
                smallestDist = dist
                closestAnchor = pointToAnchor.anchor
            }
        }

        return smallestDist < centerDist * resizeDistanceToCenterFactor ? closestAnchor : noAnchor
    }

    private func superviewTotalWidth() -> CGFloat {
        guard let superview = superview else {
            return 0
        }
        var boundWidth = superview.bounds.width
        // If superview is UIScrollView, add contentInset as well
        if let superview = superview as? UIScrollView {
            let width = superview.contentSize.width + superview.contentInset.left + superview.contentInset.right
            boundWidth = max(boundWidth, width)
        }
        return boundWidth
    }

    private func superviewTotalHeight() -> CGFloat {
        guard let superview = superview else {
            return 0
        }
        var boundHeight = superview.bounds.height
        // If superview is UIScrollView, add contentInset as well
        if let superview = superview as? UIScrollView {
            let height = superview.contentSize.height + superview.contentInset.top + superview.contentInset.bottom
            boundHeight = max(boundHeight, height)
        }
        return boundHeight
    }

    private func resizeUsingTouchLoc(_ touchPoint: CGPoint) {
        var touchPoint = touchPoint
        if let anchor = curAnchor, let touchStart = touchStart {
            // (1) Update the touch point if we're outside the superview.
            if preventsPositionOutsideSuperview {
                let border = edgeInset
                if touchPoint.x < border {
                    touchPoint.x = border
                }
                if touchPoint.x > superviewTotalWidth() - border {
                    touchPoint.x = superviewTotalWidth() - border
                }
                if touchPoint.y < border {
                    touchPoint.y = border
                }
                if touchPoint.y > superviewTotalHeight() - border {
                    touchPoint.y = superviewTotalHeight() - border
                }
            }

            // (2) Calculate the deltas using the current anchor point.
            let deltaW = anchor.adjustsW * (touchStart.x - touchPoint.x);
            let deltaX = anchor.adjustsX * (-1.0 * deltaW);
            let deltaH = anchor.adjustsH * (touchPoint.y - touchStart.y);
            let deltaY = anchor.adjustsY * (-1.0 * deltaH);

            resizeWith(deltaW, deltaX: deltaX, deltaH: deltaH, deltaY: deltaY)

            self.touchStart = touchPoint;
        }
    }

    private func resizeWith(_ deltaW: CGFloat, deltaX: CGFloat, deltaH: CGFloat, deltaY: CGFloat) {
        var deltaW = deltaW, deltaX = deltaX, deltaH = deltaH, deltaY = deltaY
        if curAnchor == nil {
            assertionFailure("Shouldn't be nil")
            return
        }
        if superview == nil {
            assertionFailure("Shouldn't be nil")
            return
        }
        let absDeltaW = fabs(deltaW)
        let absDeltaH = fabs(deltaH)

        if keepRatio {
            let width = initialViewSize.width
            let height = initialViewSize.height
            // Taking the larger part
            if absDeltaW > absDeltaH {
                deltaH = deltaW / width * height;
                deltaY = curAnchor!.adjustsY * (-1.0 * deltaH);
            } else {
                deltaW = deltaH / height * width;
                deltaX = curAnchor!.adjustsX * (-1.0 * deltaW);
            }
        }

        // (3) Calculate the new frame.
        var newX = self.frame.origin.x + deltaX;
        var newY = self.frame.origin.y + deltaY;
        var newWidth = self.frame.size.width + deltaW;
        var newHeight = self.frame.size.height + deltaH;

        // (4) If the new frame is too small, cancel the changes.
        if keepRatio {
            if newWidth < minWidth || newHeight < minHeight {
                return
            }
        } else {
            if newWidth < minWidth {
                newWidth = self.frame.size.width;
                newX = self.frame.origin.x;
            }
            if newHeight < minHeight {
                newHeight = self.frame.size.height;
                newY = self.frame.origin.y;
            }
        }

        // (5) Ensure the resize won't cause the view to move offscreen. (only do so if originally inside screen)
        if self.preventsPositionOutsideSuperview {
            let superX = superview!.bounds.origin.x
            let superY = superview!.bounds.origin.y
            if keepRatio {
                if ((newX < superX && self.frame.origin.x != newX) ||
                    (newX + newWidth > superX + superviewTotalWidth() && self.frame.size.width != newWidth) ||
                    (newY < superY && self.frame.origin.y != newY ) ||
                    (newY + newHeight > superY + superviewTotalHeight() && self.frame.size.height != newHeight))
                {
                    return;
                }
            } else {
                // left
                if (newX < superX && self.frame.origin.x != newX) {
                    // Calculate how much to grow the width by such that the new X coordintae will align with the superview.
                    deltaW = self.frame.origin.x - superX
                    newWidth = self.frame.size.width + deltaW;
                    newX = superX
                    newWidth = max(newWidth, minWidth)
                }
                // right
                if (newX + newWidth > superX + superviewTotalWidth() &&
                    self.frame.size.width != newWidth) {
                    newWidth = superviewTotalWidth() - newX;
                    newWidth = max(newWidth, minWidth)
                }
                // top
                if (newY < superY && self.frame.origin.y != newY ) {
                    // Calculate how much to grow the height by such that the new Y coordintae will align with the superview.
                    deltaH = self.frame.origin.y - superY
                    newHeight = self.frame.size.height + deltaH;
                    newY = superY
                    newHeight = max(newHeight, minHeight)
                }
                // bottom
                if (newY + newHeight > superviewTotalHeight() &&
                    self.frame.size.height != newHeight) {
                    newHeight = superviewTotalHeight() - newY;
                    newHeight = max(newHeight, minHeight)
                }
            }
        } else { // even without the option, don't want image completely out of screen
            if ((newX > superviewTotalWidth() - boundMargin) ||
                (newX + newWidth < boundMargin) ||
                (newY > superviewTotalHeight() - boundMargin) ||
                (newY + newHeight < boundMargin))
            {
                return;
            }
        }

        self.frame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight);
    }

    private func translateUsingTouchLoc(_ touchPoint: CGPoint) {
        guard let touchStart = touchStart,
            let _ = superview else
        {
            assertionFailure("touchStart & superview should be present")
            return
        }
        var newCenter = CGPoint(
            x: self.center.x + touchPoint.x - touchStart.x,
            y: self.center.y + touchPoint.y - touchStart.y);

        let halfWidth = self.bounds.width / 2
        let halfHeight = self.bounds.height / 2

        // To make image draggable, needs to have the boundMargin visible
        var horizontalMargin = boundMargin + boundPad
        var verticalMargin = boundMargin + boundPad
        if preventsPositionOutsideSuperview {
            horizontalMargin = bounds.width
            verticalMargin = bounds.height
        }
        let minCenterX = max(minX + halfWidth, 0 + horizontalMargin - halfWidth)
        let maxCenterX = superviewTotalWidth() - horizontalMargin + halfWidth

        let minCenterY = max(minY + halfHeight, 0 + verticalMargin - halfHeight)
        let maxCenterY = superviewTotalHeight() - verticalMargin + halfHeight

        guard minCenterX <= maxCenterX, minCenterY <= maxCenterY else {
            assertionFailure("Condition not right: minCenterX:\(minCenterX) maxCenterX:\(maxCenterX) minCenterY:\(minCenterY) maxCenterY:\(maxCenterY) ")
            return
        }

        if newCenter.x < minCenterX {
            newCenter.x = minCenterX
        } else if newCenter.x > maxCenterX {
            newCenter.x = maxCenterX
        }

        if newCenter.y < minCenterY {
            newCenter.y = minCenterY
        } else if newCenter.y > maxCenterY {
            newCenter.y = maxCenterY
        }

        self.center = newCenter;
    }
}

// MARK: iOS UIGestureRecognizer & Menu

extension MoView: UIGestureRecognizerDelegate {

    // MARK: UIGestureRecognizerDelegate

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enableMoving || enableDragResizing else { return }

        // If a e.g. UITextView isFirstResponder, the touch might be cancelled abruptly
        superview?.endEditing(true)
        delegate?.moViewDidBeginEditing(self)

        isValidTap = true

        let touch = touches.first!

        // When translating, all calculations are done in the view's coordinate space.
        touchStart = touch.location(in: self)

        curAnchor = anchorForTouchLoc(touchStart!)

        // When resizing, all calculations are done in the superview's coordinate space.
        if enableDragResizing && curAnchor!.isResizing() {
            touchStart = touch.location(in: superview)
        }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enableMoving || enableDragResizing else { return }

        if curAnchor == nil || superview == nil {
            assertionFailure("Shouldn't be nil")
            return
        }
        let touch = touches.first!
        let touchPos = touch.location(in: self)

        if isValidTap,
            let touchStart = touchStart
        {
            let moveDistFromStart = distSquared(touchStart, b: touchPos)
            if moveDistFromStart < 10 {
                return
            }
        }

        isValidTap = false

        if enableDragResizing && curAnchor!.isResizing() {
            resizeUsingTouchLoc(touch.location(in: superview!))
        } else if enableMoving {
            translateUsingTouchLoc(touchPos)
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enableMoving || enableDragResizing else { return }

        delegate?.moViewDidEndEditing(self, edited: !isValidTap)

        if isValidTap {
            delegate?.moViewTapped(self)
        }
    }

    override open func touchesCancelled(_ touches: Set<UITouch>,
                                        with event: UIEvent?)
    {
        guard enableMoving || enableDragResizing else { return }

        delegate?.moViewDidEndEditing(self, edited: !isValidTap)
    }

    func pinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        curAnchor = centerAnchor

        guard enablePinchResizing else { return }

        var velocity = gestureRecognizer.velocity;
        // velocity can be NaN or infinity
        if velocity.isNaN || velocity.isInfinite {
            return;
        }

        // Some velocity compensation to make the pinch more smooth
        if (velocity < 0 && gestureRecognizer.scale < 1.0) {
            velocity *= 2;
        }
        if (self.frame.size.width > 150) {
            velocity *= 1.5;
        }
        if (self.frame.size.width > 300) {
            velocity *= 1.5;
        }
        if (self.frame.size.width > 600) {
            velocity *= 1.5;
        }
        if (self.frame.size.width > 1000) {
            velocity *= 1.5;
        }

        // (2) Calculate the deltas using the current anchor point.
        let deltaW = curAnchor!.adjustsW * (velocity);
        let deltaX = curAnchor!.adjustsX * (-1.0 * deltaW);
        let deltaH = curAnchor!.adjustsH * (velocity);
        let deltaY = curAnchor!.adjustsY * (-1.0 * deltaH);

        resizeWith(deltaW, deltaX: deltaX, deltaH: deltaH, deltaY: deltaY)
    }

    // MARK: UIMenu

    override open var canBecomeFirstResponder: Bool { return true }

    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Need to only return true for the actions desired, otherwise will get the whole range of iOS actions.
        if action == #selector(self.copyItem) ||
            action == #selector(self.saveItem) ||
            action == #selector(self.deleteItem)
        {
            return true
        }

        return false
    }

    func longPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.showMenu()
        }
    }

    func showMenu() {
        if contentView == nil {
            assertionFailure("Shouldn't be nil")
            return
        }

        if !enableCopy && !enableSave && !enableDelete {
            return
        }

        self.becomeFirstResponder()

        let menuController = UIMenuController.shared
        if menuController.isMenuVisible {
            return
        }

        let copyItem = UIMenuItem(title: copyItemTitle, action: #selector(MoView.copyItem))
        let saveItem = UIMenuItem(title: saveItemTitle, action: #selector(MoView.saveItem))
        let deleteItem = UIMenuItem(title: deleteItemTitle, action: #selector(MoView.deleteItem))
        var items = [UIMenuItem]()
        if enableCopy {
            items.append(copyItem)
        }
        if enableSave {
            items.append(saveItem)
        }
        if enableDelete {
            items.append(deleteItem)
        }
        menuController.menuItems = items
        menuController.setTargetRect(contentView!.frame, in: self)
        menuController.setMenuVisible(true, animated: true)
    }
}

#else

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

    override func scrollWheel(with event: NSEvent) {
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

    override func magnify(with event: NSEvent) {
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

    override func updateTrackingAreas() {
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

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        cursor?.set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = self.cursor  {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        cursor?.set()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        cursor?.set()
    }

    override func mouseExited(with event: NSEvent) {
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

    override func mouseDown(with theEvent: NSEvent) {
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

    override func mouseUp(with event: NSEvent) {
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

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        guard let superview = superview, let superWindow = superview.window else { return }

        let frameRelativeToWindow = superview.convert(superview.bounds, to: nil)
        superviewScreenFrame = superWindow.convertToScreen(frameRelativeToWindow)
        dragStartScreenPoint = screenPoint
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        if superviewScreenFrame.contains(screenPoint) {
            session.animatesToStartingPositionsOnCancelOrFail = false

        } else {
            session.animatesToStartingPositionsOnCancelOrFail = true
        }
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation)
    {
        defer { releaseMouse() }
        guard superviewScreenFrame.contains(screenPoint) else {
            delegate?.moViewDidEndEditing(self, edited: false)
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
    func draggingSession(_ session: NSDraggingSession,
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
    func pasteboard(_ pasteboard: NSPasteboard?,
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

#endif
