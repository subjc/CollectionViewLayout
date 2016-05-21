import UIKit
import XCPlayground

/**
 
 # Playground of Justice
 
 */

struct Item {
    var height: CGFloat
}

// Predictability is a good thing yo
srand(123)

func randomHeight() -> CGFloat {
    return CGFloat((rand() % 100) + 50)
}

class DynamicLayout: UICollectionViewLayout {
    let verticalPadding: CGFloat = 10.0
    var dynamicAnimator: UIDynamicAnimator?
    var latestDelta: CGFloat = 0.0
    var staticContentSize: CGSize = CGSizeZero
    
    override init() {
        super.init()
        dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareLayout() {
        super.prepareLayout()

        guard let collectionView = collectionView,
              let dataSource = collectionView.dataSource as? DataSource,
              let dynamicAnimator = dynamicAnimator else { return }
        
        let visibleRect = CGRectInset(CGRect(origin: collectionView.bounds.origin, size: collectionView.frame.size), 0, -100)
        let visiblePaths = indexPaths(visibleRect)
        var currentlyVisible: [NSIndexPath] = []

        dynamicAnimator.behaviors.forEach { behavior in
            if let behavior = behavior as? UIAttachmentBehavior,
                let item = behavior.items.first as? UICollectionViewLayoutAttributes {
                if !visiblePaths.contains(item.indexPath) {
                    dynamicAnimator.removeBehavior(behavior)
                } else {
                    currentlyVisible.append(item.indexPath)
                }
            }
        }

        let newlyVisible = visiblePaths.filter { path in
            return !currentlyVisible.contains(path)
        }

        let staticAttributes: [UICollectionViewLayoutAttributes] = newlyVisible.map { path in
            let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: path)
            let size = dataSource.cellSizes[path.item]
            let origin = dataSource.cellOrigins[path.item]
            attributes.frame = CGRect(origin: origin, size: size)

            return attributes
        }

        let touchLocation = collectionView.panGestureRecognizer.locationInView(collectionView)

        staticAttributes.forEach { attributes in
            let center = attributes.center
            let spring = UIAttachmentBehavior(item: attributes, attachedToAnchor: center)
            spring.length = 0.5
            spring.damping = 0.1
            spring.frequency = 1.5
            
            if (!CGPointEqualToPoint(CGPointZero, touchLocation)) {
                let yDistanceFromTouch = touchLocation.y - spring.anchorPoint.y
                let xDistanceFromTouch = touchLocation.x - spring.anchorPoint.x
                let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1500.0
                var center = attributes.center
                if (latestDelta < 0) {
                    center.y += max(latestDelta, latestDelta * scrollResistance);
                } else {
                    center.y += min(latestDelta, latestDelta * scrollResistance);
                }
                attributes.center = center
            }
            
            dynamicAnimator.addBehavior(spring)
        }
    }

    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView,
              let dynamicAnimator = dynamicAnimator else { return false }

        let delta = newBounds.origin.y - collectionView.bounds.origin.y
        latestDelta = delta

        let touchLocation = collectionView.panGestureRecognizer.locationInView(collectionView)
        dynamicAnimator.behaviors.forEach { behavior in
            if let springBehaviour = behavior as? UIAttachmentBehavior, let item = springBehaviour.items.first {
                let yDistanceFromTouch = touchLocation.y - springBehaviour.anchorPoint.y
                let xDistanceFromTouch = touchLocation.x - springBehaviour.anchorPoint.x
                let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1500.0
                var center = item.center
                if (delta < 0) {
                    center.y += max(delta, delta*scrollResistance);
                } else {
                    center.y += min(delta, delta*scrollResistance);
                }
                item.center = center
                dynamicAnimator.updateItemUsingCurrentState(item)
            }
        }
        return false
    }

    override func collectionViewContentSize() -> CGSize {
        if staticContentSize != CGSizeZero {
            return staticContentSize
        }

        guard let collectionView = collectionView,
            let dataSource: DataSource = collectionView.dataSource as? DataSource else { return CGSizeZero }
        var maxY: CGFloat = 0.0
        (0..<dataSource.items.count).forEach { index in
            let originY = dataSource.cellOrigins[index].y
            let height = dataSource.cellSizes[index].height
            let newMax = originY + height
            if newMax > maxY {
                maxY = newMax
            }
        }
        // This needs to be calculated properly
        staticContentSize = CGSize(width: 320, height: maxY + 10)

        return staticContentSize
    }

    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return dynamicAnimator?.itemsInRect(rect).map {
            ($0 as? UICollectionViewLayoutAttributes)!
        }
    }

    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return dynamicAnimator?.layoutAttributesForCellAtIndexPath(indexPath)
    }
    
    
    func firstIndexPath(rect: CGRect) -> NSIndexPath {
        guard let dataSource = collectionView?.dataSource as? DataSource else { return NSIndexPath(forItem: 0, inSection: 0) }
        
        for (index, origin) in dataSource.cellOrigins.enumerate() {
            if origin.y >= CGRectGetMinY(rect) {
                return NSIndexPath(forItem: index, inSection: 0)
            }
        }
        
        return NSIndexPath(forItem: 0, inSection: 0)
    }
    
    func lastIndexPath(rect: CGRect) -> NSIndexPath {
        guard let dataSource = collectionView?.dataSource as? DataSource else { return NSIndexPath(forItem: 0, inSection: 0) }
        
        for (index, origin) in dataSource.cellOrigins.enumerate() {
            if origin.y >= CGRectGetMaxY(rect) {
                return NSIndexPath(forItem: index, inSection: 0)
            }
        }
        
        return NSIndexPath(forItem: dataSource.items.count - 1, inSection: 0)
    }
    
    func indexPaths(rect: CGRect) -> [NSIndexPath] {
        let min = firstIndexPath(rect).item
        let max = lastIndexPath(rect).item
        
        return (min...max).map { return NSIndexPath(forItem: $0, inSection: 0) }
    }
    
}

class DataSource: NSObject, UICollectionViewDataSource {
    let items = (0..<100).map {_ in
        return Item(
            height: randomHeight()
        )
    }
    
    let cellOrigins: [CGPoint]
    let cellSizes: [CGSize]
    
    override init() {
        var tempOrigins = [CGPoint]()
        var tempSizes = [CGSize]()
        var leftHeight: CGFloat = 16.0
        var rightHeight: CGFloat = 16.0
        let padding: CGFloat = 32.0
        let leftOrigin: CGFloat = 16.0
        let rightOrigin: CGFloat = 200.0

        items.enumerate().forEach { index, event in
            var x: CGFloat = leftOrigin
            var y: CGFloat = 0.0
            let width: CGFloat = 150.0
            let height: CGFloat = event.height
            
            if rightHeight > leftHeight {
                y = leftHeight
                leftHeight += event.height + padding
            } else {
                x = rightOrigin
                y = rightHeight
                rightHeight += event.height + padding
            }
            
            tempOrigins.append(CGPoint(x: x, y: y))
            tempSizes.append(CGSize(width: width, height: height))
        }
        
        cellOrigins = tempOrigins
        cellSizes = tempSizes
        
        super.init()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! Cell
        cell.backgroundColor = UIColor.redColor()
        return cell
    }
}

class Cell: UICollectionViewCell {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
}

let dataSource = DataSource()
let layout = DynamicLayout()

let foo = UICollectionViewController(collectionViewLayout: layout)
foo.collectionView?.dataSource = dataSource
foo.collectionView?.registerClass(Cell.self, forCellWithReuseIdentifier: "cell")
foo.collectionView?.backgroundColor = UIColor.whiteColor()

XCPlaygroundPage.currentPage.liveView = foo

