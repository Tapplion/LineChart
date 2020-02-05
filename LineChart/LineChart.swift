//
//  https://github.com/Tapplion/LineChart
//  Copyright (c) Pascal Kimmel 2020-present
//  Licensed under the MIT license. See LICENSE file.
//

import UIKit

struct ChartItem {
    let value: Int
    let label: String
}

extension ChartItem: Comparable {
    static func <(lhs: ChartItem, rhs: ChartItem) -> Bool {
        return lhs.value < rhs.value
    }
    
    static func ==(lhs: ChartItem, rhs: ChartItem) -> Bool {
        return lhs.value == rhs.value
    }
}

class LineChart: UIView {
    
    /// Background color of the main view, defaults to white
    var mainViewBackGroundColor: UIColor = .white
    
    /// Axis color, defaults to black
    var axisColor: UIColor = .black
    
    /// Axis labels color, defaults to black
    var axisLabelsColor: UIColor = .black
    
    /// Line color, defaults to black
    var lineColor: UIColor = .black
    
    /// Line width, defaults to 1.0
    var lineWidth: CGFloat = 1.0
    
    /// Draw a zigzag line or a curved line
    var drawsCurvedLine: Bool = false
    
    /// Show/hide the last value label on the X axis, defaults to true
    var showLastValueLabel: Bool = true
    
    /// Minimum width of the labels on the X axis
    var minimumLabelWidth: CGFloat = 30.0
    
    /// Defines if grid lines needs to be shown, defaults to true
    var showsGridLines: Bool = true
    
    /// Draw a gradient layer below the line
    var showsGradientLayer: Bool = false

    /// Defines the colors used in the gradient layer, if enabled
    var gradientLayerColors: [CGColor] = [#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7).cgColor, UIColor.clear.cgColor]
    
    /// Defines if the highlight label is drawn when the chart is touched, defaults to true
    var drawsHightLabelOnTouch: Bool = true
    
    /// Remove highlight label and line when main layer receives a touch, defaults to true
    var removeHighlightLayersOnTouchOutOfChart: Bool = true
    
    /// Background color of the highlight label, defaults to black
    var highlightLabelBackgroundColor: UIColor = .black
    
    /// Text color of the highlight label, defaults to white
    var highlightLabelTextColor: UIColor = .white

    /// Draw the highlight line when the chart is touched, defaults to true
    var drawsHighlightLine: Bool = true
    
    /// Color for the highlight line
    var highlightLineColor = UIColor.gray
    
    /// Width for the highlight line
    var highlightLineWidth: CGFloat = 0.5
    
    /// Hide the highlight line when touch event ends, e.g. when stop swiping over the chart
    var hideHighlightLineOnTouchEnd = false
    
    /// Defines to draw dots, defaults to false
    var showsDots: Bool = false
    
    /// Active or desactive animation on dots
    var animatesDots: Bool = false

    /// Dot outer color, defaults to black
    var dotOuterColor: UIColor = .black
    
    /// Dot outer Radius
    var dotOuterRadius: CGFloat = 6.0
    
    /// Dot inner color, defaults to white
    var dotInnterColor: UIColor = .white
    
    /// Dot inner Radius
    private var dotInnerRadius: CGFloat {
        return dotOuterRadius / 2
    }

    /// Array of items to be used for creating the chart
    var chartItems: [ChartItem]? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// Array of points to be used for drawing the chart
    private var dataPoints: [CGPoint] = []
    
    /// The top most horizontal line in the chart will be 10% higher than the highest value in the chart
    private let topHorizontalLine: CGFloat = 110.0 / 100.0
    
    /// Gap between each point
    private var lineGap: CGFloat = 0.0
    
    /// Preseved space at top of the chart
    private let topSpace: CGFloat = 20.0
    
    /// Preserved space at bottom of the chart to show labels along the Y axis
    private let bottomSpace: CGFloat = 30.0
    
    /// Preserved space at left of the chart to show labels along the X axis
    private let leftSpace: CGFloat = 30.0
    
    /// Preserved space at the right side of the chart
    private var rightSpace: CGFloat {
        return showLastValueLabel ? 16.0 : 0.0
    }
    
    /// Contains dataLayer and gradientLayer
    private let mainLayer: CALayer = CALayer()
    
    /// Contains the main line which represents the data
    private let dataLayer: CALayer = CALayer()
    
    /// To show the gradient below the main line
    private let gradientLayer: CAGradientLayer = CAGradientLayer()
    
    /// Contains horizontal lines
    private let gridLayer: CALayer = CALayer()
    
    /// Highlight text layer
    private var highlightTextLayer: CATextLayer?
    
    /// Highlight shape layer
    private var highlightShapeLayer: CAShapeLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    convenience init() {
        self.init(frame: CGRect.zero)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        mainLayer.addSublayer(gridLayer)
        mainLayer.addSublayer(dataLayer)
        self.layer.addSublayer(mainLayer)
        
        mainLayer.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        dataLayer.frame = CGRect(x: leftSpace, y: topSpace, width: mainLayer.frame.width - leftSpace - rightSpace, height: mainLayer.frame.height - topSpace - bottomSpace)
        gridLayer.frame = CGRect(x: leftSpace, y: topSpace, width: dataLayer.frame.width, height: dataLayer.frame.height)
        gradientLayer.frame = dataLayer.frame
    }
    
    override func layoutSubviews() {
        guard let chartItems = chartItems, let dataPoints = convertChartItemsToPoints(chartItems) else {
            return
        }
        
        self.dataPoints = dataPoints
        self.backgroundColor = mainViewBackGroundColor
        
        clean()
        drawHorizontalLines(with: chartItems)
        drawChart(with: dataPoints, curved: drawsCurvedLine)
        if showsGradientLayer {
            gradientLayer.colors = gradientLayerColors
            maskGradientLayer(for: dataPoints)
            mainLayer.addSublayer(gradientLayer)
        }
        if showsDots {
            drawDots(for: dataPoints)
        }
        drawLabels(for: chartItems)
    }
    
    // MARK: - Drawing
    
    /**
     Convert an array of PointEntry to an array of CGPoint on dataLayer coordinate system
     */
    private func convertChartItemsToPoints(_ items: [ChartItem]) -> [CGPoint]? {
        lineGap = (dataLayer.frame.size.width) / CGFloat(items.count - 1)
        
        var result: [CGPoint] = []
        let topValue = calculateTopValue(for: items)
        var max = 0
        var min = 0
        var minMaxRange: CGFloat = 0.0
        
        if let topValue = topValue {
            max = topValue
            minMaxRange = CGFloat(topValue - min)
        } else if let topValue = items.max()?.value,
            let lowValue = items.min()?.value {
            max = topValue
            min = lowValue
            minMaxRange = CGFloat(max - min) * topHorizontalLine
        }
        
        var xValue: CGFloat = 0
        
        for i in 0..<items.count {
            let height = dataLayer.frame.height * (1 - ((CGFloat(items[i].value) - CGFloat(min)) / minMaxRange))
            let point = CGPoint(x: xValue, y: height)
            result.append(point)
            xValue += lineGap
        }
        return result
    }
    
    /**
     Create a bezier path that connects all points in dataPoints
     */
    private func path(for dataPoints: [CGPoint], curved: Bool) -> UIBezierPath? {
        let path = UIBezierPath()
        path.move(to: dataPoints[0])
        
        if curved {
            var curveSegments: [CurvedSegment] = []
            curveSegments = CurveAlgorithm.controlPointsFrom(points: dataPoints)
            
            for i in 1..<dataPoints.count {
                path.addCurve(to: dataPoints[i], controlPoint1: curveSegments[i-1].controlPoint1, controlPoint2: curveSegments[i-1].controlPoint2)
            }
        } else {
            for i in 1..<dataPoints.count {
                path.addLine(to: dataPoints[i])
            }
        }
        
        return path
    }
    
    /**
    Draws highlight text layer on the main layer
    */
    private func drawHighlightLabel(for chartItem: ChartItem, at point: CGPoint) {
        let textLayer = CATextLayer()
        textLayer.foregroundColor = highlightLabelTextColor.cgColor
        textLayer.backgroundColor = highlightLabelBackgroundColor.cgColor
        textLayer.alignmentMode = CATextLayerAlignmentMode.center
        textLayer.isOpaque = false
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.fontSize = 12
        textLayer.string = String(describing: chartItem.value)
        textLayer.frame = CGRect(x: point.x - (minimumLabelWidth / 2) + leftSpace, y: point.y - bottomSpace + topSpace + 8, width: minimumLabelWidth, height: 16)
        highlightTextLayer = textLayer
        
        mainLayer.addSublayer(textLayer)
        if drawsHighlightLine {
            drawHighlightLineAtPoint(point)
        }
    }
    
    /**
    Drwas highlight line at the given point
    */
    private func drawHighlightLineAtPoint(_ point: CGPoint) {
        if let highlightShapeLayer = highlightShapeLayer {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: point.x, y: 0))
            path.addLine(to: CGPoint(x: point.x, y: dataLayer.frame.height))
            highlightShapeLayer.path = path
        } else {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: point.x, y: CGFloat(0)))
            path.addLine(to: CGPoint(x: point.x, y: dataLayer.frame.height))
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path
            shapeLayer.strokeColor = highlightLineColor.cgColor
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = highlightLineWidth

            highlightShapeLayer = shapeLayer
            dataLayer.addSublayer(shapeLayer)
        }
    }
    
    /**
     Draw a line connecting all points in dataPoints
     */
    private func drawChart(with dataPoints: [CGPoint], curved: Bool) {
        guard dataPoints.count > 0, let path = path(for: dataPoints, curved: curved) else {
            return
        }
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = lineWidth
        dataLayer.addSublayer(lineLayer)
    }

    /**
     Create titles at the bottom for all entries showed in the chart
     */
    private func drawLabels(for dataEntries: [ChartItem]) {
        guard dataEntries.count > 0, lineGap > 0 else {
            return
        }

        var itemsToShow = calculateVisibileLabels(for: dataEntries)
        let lastItemIndex = dataEntries.count - 1
        
        for i in 0..<dataEntries.count {
            let width = dataEntries.count > itemsToShow.count ? minimumLabelWidth : lineGap
            let y = gridLayer.frame.size.height + 4
            let x = lineGap * CGFloat(i) - width / 2
            
            let textLayer = CATextLayer()
            textLayer.foregroundColor = axisLabelsColor.cgColor
            textLayer.backgroundColor = UIColor.clear.cgColor
            textLayer.alignmentMode = CATextLayerAlignmentMode.center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.fontSize = 11
            textLayer.string = dataEntries[i].label
            textLayer.frame = CGRect(x: x, y: y, width: width, height: 16)
            
            if i == lastItemIndex && !showLastValueLabel && itemsToShow.contains(i) {
                itemsToShow.remove(at: i)
            }

            if itemsToShow.contains(i) {
                gridLayer.addSublayer(textLayer)
            }
        }
    }
    
    /**
     Create horizontal lines (grid lines) and show the value of each line
     */
    private func drawHorizontalLines(with dataEntries: [ChartItem]) {
        
        let topValue = calculateTopValue(for: dataEntries)
        var gridValues: [CGFloat]? = nil
        
        if dataEntries.count < 4 && dataEntries.count > 0 {
            gridValues = [0, 1]
        } else if dataEntries.count >= 4 {
            gridValues = [0, 0.25, 0.5, 0.75, 1]
        }
        if let gridValues = gridValues {
            
            let verticalLinePath = UIBezierPath()
            verticalLinePath.move(to: CGPoint(x: 0, y: 0))
            verticalLinePath.addLine(to: CGPoint(x: 0, y: gridLayer.frame.size.height))
            
            let vericalLineLayer = CAShapeLayer()
            vericalLineLayer.path = verticalLinePath.cgPath
            vericalLineLayer.fillColor = UIColor.clear.cgColor
            vericalLineLayer.strokeColor = axisColor.cgColor
            vericalLineLayer.lineWidth = 0.5
            gridLayer.addSublayer(vericalLineLayer)
            
            for value in gridValues {
                let height = value * gridLayer.frame.size.height
                
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: gridLayer.frame.size.width, y: height))
                
                let lineLayer = CAShapeLayer()
                lineLayer.path = path.cgPath
                lineLayer.fillColor = UIColor.clear.cgColor
                lineLayer.strokeColor = axisColor.cgColor
                lineLayer.lineWidth = 0.5

                if (value != 1.0) {
                    if showsGridLines {
                        lineLayer.opacity = 0.5
                        lineLayer.lineDashPattern = [4, 4]
                    } else {
                        lineLayer.lineWidth = 0.0
                    }
                }
                
                gridLayer.addSublayer(lineLayer)
                
                var minMaxGap:CGFloat = 0
                var lineValue:Int = 0
                var min = 0
                
                if let topValue = topValue {
                    minMaxGap = CGFloat(topValue - min)
                    lineValue = Int((1-value) * minMaxGap) + Int(min)
                } else if let max = dataEntries.max()?.value {
                    min = dataEntries.min()?.value ?? 0
                    minMaxGap = CGFloat(max - min) * topHorizontalLine
                }
                
                lineValue = Int((1-value) * minMaxGap) + Int(min)
         
                let textLayer = CATextLayer()
                textLayer.frame = CGRect(x: -55, y: height - 8, width: 50, height: 16)
                textLayer.foregroundColor = axisLabelsColor.cgColor
                textLayer.backgroundColor = UIColor.clear.cgColor
                textLayer.contentsScale = UIScreen.main.scale
                textLayer.fontSize = 11
                textLayer.string = "\(lineValue)"
                textLayer.alignmentMode = .right
                
                gridLayer.addSublayer(textLayer)
            }
        }
    }
    
    /**
     Create Dots on line points
     */
    private func drawDots(for dataPoints: [CGPoint]) {
        var dotLayers: [DotLayer] = []
        for dataPoint in dataPoints {
            let xValue = (dataPoint.x - dotOuterRadius/2) + leftSpace
            let yValue = (dataPoint.y - dotInnerRadius) + topSpace
            let dotLayer = DotLayer()
            dotLayer.dotInnerColor = dotInnterColor
            dotLayer.innerRadius = dotInnerRadius
            dotLayer.backgroundColor = dotOuterColor.cgColor
            dotLayer.cornerRadius = dotOuterRadius / 2
            dotLayer.frame = CGRect(x: xValue, y: yValue, width: dotOuterRadius, height: dotOuterRadius)
            dotLayers.append(dotLayer)

            if animatesDots {
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.duration = 1.0
                anim.fromValue = 0
                anim.toValue = 1
                dotLayer.add(anim, forKey: "opacity")
            }
            
            mainLayer.addSublayer(dotLayer)
        }
    }
    
    /**
     Create a gradient layer below the line that connecting all dataPoints
     */
    private func maskGradientLayer(for dataPoints: [CGPoint]) {
        guard dataPoints.count > 0, let dataPath = path(for: dataPoints, curved: drawsCurvedLine)  else {
            return
        }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: dataPoints[0].x, y: dataLayer.frame.height))
        path.addLine(to: dataPoints[0])
        path.append(dataPath)
        path.addLine(to: CGPoint(x: dataPoints[dataPoints.count-1].x, y: dataLayer.frame.height))
        path.addLine(to: CGPoint(x: dataPoints[0].x, y: dataLayer.frame.height))
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.lineWidth = 0.0
        
        gradientLayer.mask = maskLayer
    }
    
    // MARK: - Touches
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        handleTouchEvents(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        handleTouchEvents(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        handleTouchEvents(touches)
        if hideHighlightLineOnTouchEnd {
            removeHighlightShapeLayer()
        }
    }
    
    private func handleTouchEvents(_ touches: Set<UITouch>) {
        guard drawsHightLabelOnTouch else {
            return
        }
        guard let closestPoint = closestPoint(for: touches),
            let closestitemIndex = dataPoints.firstIndex(of: closestPoint),
            let closestItem = chartItems?[closestitemIndex] else {
                return
        }
        
        removeHighlightTextLayer()
        drawHighlightLabel(for: closestItem, at: closestPoint)
    }
    
    /**
    Returns the closest point in the array of `data points`
    */
    private func closestPoint(for touches: Set<UITouch>) -> CGPoint? {
        guard let touch = touches.first, layerFor(touch) != mainLayer else {
            if removeHighlightLayersOnTouchOutOfChart {
                removeHighlightTextLayer()
                removeHighlightShapeLayer()
            }
            return nil
        }
        
        var point = touch.location(in: self)
        point.x -= leftSpace
        point.y -= topSpace
        let closestPoint = closestPointOnPath(fromPoint: point)
        return closestPoint
    }
    
    /**
    Finds the closest value on path for a given point
    */
    private func closestPointOnPath(fromPoint: CGPoint) -> CGPoint {
        func distance(fromPoint: CGPoint, toPoint: CGPoint) -> CGFloat {
            let xDist = Float(fromPoint.x - toPoint.x)
            let yDist = Float(fromPoint.y)
            return CGFloat(hypotf(xDist, yDist))
        }
        
        let end = dataPoints.count
        var dd = distance(fromPoint: fromPoint, toPoint: dataPoints.first!)
        var d: CGFloat = 0
        var f = 0
        for i in 1..<end {
            d = distance(fromPoint: fromPoint, toPoint: dataPoints[i])
            if d < dd {
                f = i
                dd = d
            }
        }
        return dataPoints[f]
    }
        
    /**
    Returns the layer touched
    */
    private func layerFor(_ touch: UITouch) -> CALayer? {
        let view = self
        let touchLocation = touch.location(in: view)
        let locationInView = view.convert(touchLocation, to: nil)

        let hitPresentationLayer = view.layer.presentation()?.hitTest(locationInView)
        return hitPresentationLayer?.model()
    }
    
    // MARK: - Utilities
    
    /**
    Calculate the top value, rounded to a multiple of 100
    */
    private func calculateTopValue(for dataEntries: [ChartItem]) -> Int? {
        guard let maxValue = dataEntries.max()?.value else {
            return nil
        }
        
        let roundedToHundreds = (maxValue / 100 * 100) + ((maxValue % 100) / 50) * 100
        return roundedToHundreds < maxValue ? roundedToHundreds + 200 : roundedToHundreds + 100
    }
    
    /**
    Calculate which labels should be should on the X axis
    */
    private func calculateVisibileLabels(for dataEntries: [ChartItem]) -> [Int] {
        let itemCount = dataEntries.count
        let maxLabels = Int(dataLayer.frame.width / minimumLabelWidth)
        let lastItemIndex = dataEntries.count - 1
        
        let minimumSpace = Int(ceil(Double(itemCount) / Double(maxLabels)))
        var result = [Int]()
        
        if itemCount > maxLabels {
            for i in 0..<dataEntries.count {
                if i % minimumSpace == 0 || (i == lastItemIndex && showLastValueLabel) {
                    result.append(i)
                }
            }
        } else {
            for (index, _) in dataEntries.enumerated() {
                result.append(index)
            }
        }
        return result
    }
    
    /**
    Removes hightlight text layer
    */
    private func removeHighlightTextLayer() {
        highlightTextLayer?.removeFromSuperlayer()
        highlightTextLayer = nil
    }
    
    /**
    Removes hightlight shape layer
    */
    private func removeHighlightShapeLayer() {
        highlightShapeLayer?.removeFromSuperlayer()
        highlightShapeLayer = nil
    }
    
    /**
    Removes all sublayers
    */
    private func clean() {
        mainLayer.sublayers?.forEach({
            if $0 is CATextLayer || $0 is DotLayer {
                $0.removeFromSuperlayer()
            }
        })
        dataLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        gridLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
    }
}
