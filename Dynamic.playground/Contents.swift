import UIKit
import PlaygroundSupport

/**

 # Playground of Justice

 */

struct Item {
    var height: CGFloat
}

arc4random()

func randomHeight() -> CGFloat {
    return CGFloat((arc4random() % 100) + 50)
}

class DynamicLayout: UICollectionViewLayout {
    let verticalPadding: CGFloat = 10.0
    var dynamicAnimator: UIDynamicAnimator?
    var latestDelta: CGFloat = 0.0
    var staticContentSize: CGSize = .zero

    override init() {
        super.init()
        dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView,
            let dataSource = collectionView.dataSource as? DataSource,
            let dynamicAnimator = dynamicAnimator else { return }

        let visibleRect = CGRect(origin: collectionView.bounds.origin, size: collectionView.frame.size).insetBy(dx: 0, dy: -100)
        let visiblePaths = indexPaths(rect: visibleRect)
        var currentlyVisible: [IndexPath] = []

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
            let attributes = UICollectionViewLayoutAttributes(forCellWith: path)
            let size = dataSource.cellSizes[path.item]
            let origin = dataSource.cellOrigins[path.item]
            attributes.frame = CGRect(origin: origin, size: size)

            return attributes
        }

        let touchLocation = collectionView.panGestureRecognizer.location(in: collectionView)

        staticAttributes.forEach { attributes in
            let center = attributes.center
            let spring = UIAttachmentBehavior(item: attributes, attachedToAnchor: center)
            spring.length = 0.5
            spring.damping = 0.1
            spring.frequency = 1.5

            if .zero != touchLocation {
                let yDistanceFromTouch = touchLocation.y - spring.anchorPoint.y
                let xDistanceFromTouch = touchLocation.x - spring.anchorPoint.x
                let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1500.0
                var center = attributes.center
                if latestDelta < 0 {
                    center.y += max(latestDelta, latestDelta * scrollResistance);
                } else {
                    center.y += min(latestDelta, latestDelta * scrollResistance);
                }
                attributes.center = center
            }

            dynamicAnimator.addBehavior(spring)
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView,
            let dynamicAnimator = dynamicAnimator else { return false }

        let delta = newBounds.origin.y - collectionView.bounds.origin.y
        latestDelta = delta

        let touchLocation = collectionView.panGestureRecognizer.location(in: collectionView)
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
                dynamicAnimator.updateItem(usingCurrentState: item)
            }
        }
        return false
    }

    override var collectionViewContentSize: CGSize {
        if staticContentSize != .zero {
            return staticContentSize
        }

        guard let collectionView = collectionView,
            let dataSource: DataSource = collectionView.dataSource as? DataSource else { return .zero }
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

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return dynamicAnimator?.items(in: rect).map {
            ($0 as? UICollectionViewLayoutAttributes)!
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return dynamicAnimator?.layoutAttributesForCell(at: indexPath)
    }


    func firstIndexPath(_ rect: CGRect) -> IndexPath {
        guard let dataSource = collectionView?.dataSource as? DataSource else { return IndexPath(item: 0, section: 0) }

        for (index, origin) in dataSource.cellOrigins.enumerated() {
            if origin.y >= rect.minY {
                return IndexPath(item: index, section: 0)
            }
        }

        return IndexPath(item: 0, section: 0)
    }

    func lastIndexPath(_ rect: CGRect) -> IndexPath {
        guard let dataSource = collectionView?.dataSource as? DataSource else { return IndexPath(item: 0, section: 0) }

        for (index, origin) in dataSource.cellOrigins.enumerated() {
            if origin.y >= rect.maxY {
                return IndexPath(item: index, section: 0)
            }
        }

        return IndexPath(item: dataSource.items.count - 1, section: 0)
    }

    func indexPaths(rect: CGRect) -> [IndexPath] {
        let min = firstIndexPath(rect).item
        let max = lastIndexPath(rect).item

        return (min...max).map { return IndexPath(item: $0, section: 0) }
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

        for event in items {
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

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .lightGray
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
foo.collectionView?.register(Cell.self, forCellWithReuseIdentifier: "cell")
foo.collectionView?.backgroundColor = .white

PlaygroundPage.current.liveView = foo
