/*
  MoView by hyouuu, made for Pendo, based on SPUserResizableView.

  It is a movable, resizable view, with special attention to be used with UIImage, thus providing Save, Copy and Delete menu options.

  MoView will call superview.endEditing() when receiving touch; client should call endEditing on any other firstResponder, or it might cancel MoView's touch abruptly
*/

protocol MoViewDelegate: class {
  func moViewDidBeginEditing(moView: MoView)
  func moViewDidEndEditing(moView: MoView, edited: Bool)
  func moViewTapped(moView: MoView)
  func moViewCopyTapped(moView: MoView)
  func moViewSaveTapped(moView: MoView)
  func moViewDeleteTapped(moView: MoView)
}

class MoView: UIView, UIGestureRecognizerDelegate {

  // MARK: Public vars

  static var minWidth: CGFloat = 60
  static var minHeight: CGFloat = 60

  weak var delegate: MoViewDelegate?

  // Outside view for touch
  var edgeInset: CGFloat = 1

  // Where touch is considered dragging bound and will cause resizing
  var boundMargin: CGFloat = 50

  // Whether keeping view's original ratio while resizing
  var keepRatio = true

  // The touch point's distance to cetner must be factored and still greater
  // than distance to a corner to start resizing - factor higher resize easier.
  let resizeDistanceToCenterFactor: CGFloat = 0.5

  // Disables the user from dragging the view outside the parent view's bounds.
  var preventsPositionOutsideSuperview = false

  // Toggles for each menu item
  var enableCopy = true
  var enableSave = true
  var enableDelete = true

  // Should provide localized titles for i18n
  var copyItemTitle = "Copy"
  var saveItemTitle = "Save"
  var deleteItemTitle = "Delete"

  // The actual view to be assigned from client
  var contentView: UIView? {
    willSet {
      if let contentView = contentView {
        contentView.removeFromSuperview()
      }
    }
    didSet {
      if let contentView = contentView {
        contentView.frame = CGRectInset(self.bounds, edgeInset, edgeInset);
        contentView.layer.cornerRadius = 9
        contentView.layer.masksToBounds = true
        addSubview(contentView)
      }
    }
  }

  override var frame: CGRect {
    didSet {
      contentView?.frame = CGRectInset(self.bounds, edgeInset, edgeInset);
      initialViewSize = self.bounds.size
    }
  }

  // Holds to an original media object for the view, e.g. a media object in DB.
  // It's more like a convenient link, and not necessarily useful to every instance
  var media: AnyObject?

  override init(frame: CGRect) {
    super.init(frame: frame)

    let longPress = UILongPressGestureRecognizer(target: self, action: "longPress:")
    addGestureRecognizer(longPress)

    let pinch = UIPinchGestureRecognizer(target: self, action: "pinch:")
    addGestureRecognizer(pinch)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self, name: nil, object: nil)
  }

  // MARK: Privates

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

  // Will be initiated when the MoView's frame is set to keep ratio
  private var initialViewSize = CGSizeZero

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

  // Helper for fast distance comparison
  private func distSquared(a: CGPoint, b: CGPoint) -> CGFloat {
    let dx = (b.x - a.x)
    let dy = (b.y - a.y)
    return (dx * dx) + (dy * dy)
  }

  private func anchorForTouchLoc(touchPoint: CGPoint) -> MoViewAnchor {
    let width = bounds.width
    let height = bounds.height
    let centerPoint = CGPointMake(width / 2, height / 2)

    // Edge 8 points to compare against center
    let pointToAnchors: [MoViewPointToAnchor] = [
      MoViewPointToAnchor(point: CGPointMake(0, 0), anchor: upperLeftAnchor),
      MoViewPointToAnchor(point: CGPointMake(width / 2, 0), anchor: upperMidAnchor),
      MoViewPointToAnchor(point: CGPointMake(width, 0), anchor: upperRightAnchor),
      MoViewPointToAnchor(point: CGPointMake(width, height / 2), anchor: midRightAnchor),
      MoViewPointToAnchor(point: CGPointMake(width, height), anchor: lowerRightAnchor),
      MoViewPointToAnchor(point: CGPointMake(width / 2, height), anchor: lowerMidAnchor),
      MoViewPointToAnchor(point: CGPointMake(0, height), anchor: lowerLeftAnchor),
      MoViewPointToAnchor(point: CGPointMake(0, height / 2), anchor: midLeftAnchor)
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

  private func superviewBoundWidth() -> CGFloat {
    guard let superview = superview else {
      return 0
    }
    var boundWidth = superview.bounds.width
    // If superview is UITextView (the case of Pendo), check contentSize
    if superview .isKindOfClass(UITextView) {
      let contentWidth = (superview as! UITextView).contentSize.width
      boundWidth = max(boundWidth, contentWidth)
    }
    return boundWidth
  }

  private func superviewBoundHeight() -> CGFloat {
    guard let superview = superview else {
      return 0
    }
    var boundHeight = superview.bounds.height
    // If superview is UITextView (the case of Pendo), check contentSize
    if superview .isKindOfClass(UITextView) {
      let contentHeight = (superview as! UITextView).contentSize.height
      boundHeight = max(boundHeight, contentHeight)
    }
    return boundHeight
  }

  private func resizeUsingTouchLoc(var touchPoint: CGPoint) {
    if let anchor = curAnchor, let touchStart = touchStart {
      // (1) Update the touch point if we're outside the superview.
      if preventsPositionOutsideSuperview {
        let border = edgeInset
        if touchPoint.x < border {
          touchPoint.x = border
        }
        if touchPoint.x > superviewBoundWidth() - border {
          touchPoint.x = superviewBoundWidth() - border
        }
        if touchPoint.y < border {
          touchPoint.y = border
        }
        if touchPoint.y > superviewBoundHeight() - border {
          touchPoint.y = superviewBoundHeight() - border
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

  private func resizeWith(
    var deltaW: CGFloat,
    var deltaX: CGFloat,
    var deltaH: CGFloat,
    var deltaY: CGFloat)
  {
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
      if newWidth < MoView.minWidth || newHeight < MoView.minHeight {
        return
      }
    } else {
      if newWidth < MoView.minWidth {
        newWidth = self.frame.size.width;
        newX = self.frame.origin.x;
      }
      if newHeight < MoView.minHeight {
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
          (newX + newWidth > superX + superviewBoundWidth() && self.frame.size.width != newWidth) ||
          (newY < superY && self.frame.origin.y != newY ) ||
          (newY + newHeight > superY + superviewBoundHeight() && self.frame.size.height != newHeight))
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
          newWidth = max(newWidth, MoView.minWidth)
        }
        // right
        if (newX + newWidth > superX + superviewBoundWidth() &&
          self.frame.size.width != newWidth) {
            newWidth = superviewBoundWidth() - newX;
            newWidth = max(newWidth, MoView.minWidth)
        }
        // top
        if (newY < superY && self.frame.origin.y != newY ) {
          // Calculate how much to grow the height by such that the new Y coordintae will align with the superview.
          deltaH = self.frame.origin.y - superY
          newHeight = self.frame.size.height + deltaH;
          newY = superY
          newHeight = max(newHeight, MoView.minHeight)
        }
        // bottom
        if (newY + newHeight > superviewBoundHeight() &&
          self.frame.size.height != newHeight) {
            newHeight = superviewBoundHeight() - newY;
            newHeight = max(newHeight, MoView.minHeight)
        }
      }
    } else { // even without the option, don't want image completely out of screen
      if ((newX > superview!.bounds.width - boundMargin) ||
        (newX + newWidth < boundMargin) ||
        (newY > superview!.bounds.height - boundMargin) ||
        (newY + newHeight < boundMargin))
      {
        return;
      }
    }

    self.frame = CGRectMake(newX, newY, newWidth, newHeight);
  }

  private func translateUsingTouchLoc(touchPoint: CGPoint) {
    if touchStart == nil {
      assertionFailure("Shouldn't be nil")
      return
    }
    var newCenter = CGPointMake(
      self.center.x + touchPoint.x - touchStart!.x,
      self.center.y + touchPoint.y - touchStart!.y);
    
    if (self.preventsPositionOutsideSuperview) {
      // Ensure the translation won't cause the view to move offscreen.
      let midPointX = CGRectGetMidX(self.bounds);
      if (newCenter.x > superviewBoundWidth() - midPointX) {
        newCenter.x = superviewBoundWidth() - midPointX;
      }
      if (newCenter.x < midPointX) {
        newCenter.x = midPointX;
      }
      let midPointY = CGRectGetMidY(self.bounds);
      if (newCenter.y > superviewBoundHeight() - midPointY) {
        newCenter.y = superviewBoundHeight() - midPointY;
      }
      if (newCenter.y < midPointY) {
        newCenter.y = midPointY;
      }
    } else { // even without the option, don't want image completely out of screen
      // Ensure the translation won't cause the view to move offscreen.
      let midPointX = CGRectGetMidX(self.bounds);
      if (newCenter.x > superview!.bounds.width + midPointX - boundMargin) {
        newCenter.x = superview!.bounds.width + midPointX - boundMargin;
      }
      if (newCenter.x < 0 - midPointX + boundMargin) {
        newCenter.x = 0 - midPointX + boundMargin;
      }
      let midPointY = CGRectGetMidY(self.bounds);
      if (newCenter.y > superviewBoundHeight() + midPointY - boundMargin) {
        newCenter.y = superviewBoundHeight() + midPointY - boundMargin;
      }
      if (newCenter.y < 0 - midPointY + boundMargin) {
        newCenter.y = 0 - midPointY + boundMargin;
      }
    }
    self.center = newCenter;
  }

  // MARK: UIGestureRecognizerDelegate

  func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool
  {
    return true
  }
  
  override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    // If a e.g. UITextView isFirstResponder, the touch might be cancelled abruptly
    superview?.endEditing(true)
    delegate?.moViewDidBeginEditing(self)

    isValidTap = true

    let touch = touches.first!

    // When translating, all calculations are done in the view's coordinate space.
    touchStart = touch.locationInView(self)

    curAnchor = anchorForTouchLoc(touchStart!)

    // When resizing, all calculations are done in the superview's coordinate space.
    if curAnchor!.isResizing() {
      touchStart = touch.locationInView(superview)
    }
  }

  override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
    if curAnchor == nil || superview == nil {
      assertionFailure("Shouldn't be nil")
      return
    }
    let touch = touches.first!
    let touchPos = touch.locationInView(self)

    if isValidTap,
      let touchStart = touchStart
    {
      let moveDistFromStart = distSquared(touchStart, b: touchPos)
      if moveDistFromStart < 10 {
        return
      }
    }

    isValidTap = false

    if curAnchor!.isResizing() {
      resizeUsingTouchLoc(touch.locationInView(superview!))
    } else {
      translateUsingTouchLoc(touchPos)
    }
  }

  override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    delegate?.moViewDidEndEditing(self, edited: !isValidTap)

    if isValidTap {
      delegate?.moViewTapped(self)
    }
  }

  override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
    delegate?.moViewDidEndEditing(self, edited: !isValidTap)
  }


  func pinch(gestureRecognizer: UIPinchGestureRecognizer) {
    curAnchor = centerAnchor
    var velocity = gestureRecognizer.velocity;
    // velocity can be NaN or infinity
    if isnan(velocity) || !isfinite(velocity) {
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

  func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
    if gestureRecognizer.state == .Began {
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

    let menuController = UIMenuController.sharedMenuController()
    if menuController.menuVisible {
      return
    }

    let copyItem = UIMenuItem(title: copyItemTitle, action: "copyItem")
    let saveItem = UIMenuItem(title: saveItemTitle, action: "saveItem")
    let deleteItem = UIMenuItem(title: deleteItemTitle, action: "deleteItem")
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
    menuController.setTargetRect(contentView!.frame, inView: self)
    menuController.setMenuVisible(true, animated: true)
  }

  @objc func copyItem() {
    delegate?.moViewCopyTapped(self)
  }

  @objc func saveItem() {
    delegate?.moViewSaveTapped(self)
  }

  @objc func deleteItem() {
    delegate?.moViewDeleteTapped(self)
  }

  override func canBecomeFirstResponder() -> Bool {
    return true
  }

  override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
    // Need to only return true for the actions desired, otherwise will get the whole range of iOS actions.
    if action == Selector("copyItem") ||
      action == Selector("saveItem") ||
      action == Selector("deleteItem")
    {
      return true
    }

    return false
  }
}