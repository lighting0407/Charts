//
//  LineChartRenderer.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class LineChartRenderer: LineRadarRenderer
{
    // TODO: Currently, this nesting isn't necessary for LineCharts. However, it will make it much easier to add a custom rotor
    // that navigates between datasets.
    // NOTE: Unlike the other renderers, LineChartRenderer populates accessibleChartElements in drawCircles due to the nature of its drawing options.
    /// A nested array of elements ordered logically (i.e not in visual/drawing order) for use with VoiceOver.
    private lazy var accessibilityOrderedElements: [[NSUIAccessibilityElement]] = accessibilityCreateEmptyOrderedElements()

    @objc open weak var dataProvider: LineChartDataProvider?
    
    @objc public init(dataProvider: LineChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard let lineData = dataProvider?.lineData else { return }

        let sets = lineData.dataSets as? [LineChartDataSet]
        assert(sets != nil, "Datasets for LineChartRenderer must conform to ILineChartDataSet")

        let drawDataSet = { self.drawDataSet(context: context, dataSet: $0) }
        sets!.lazy
            .filter(\.isVisible)
            .forEach(drawDataSet)
    }
    
    @objc open func drawDataSet(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        if dataSet.entryCount < 1
        {
            return
        }
        
        context.saveGState()
        
        context.setLineWidth(dataSet.lineWidth)
        if dataSet.lineDashLengths != nil
        {
            context.setLineDash(phase: dataSet.lineDashPhase, lengths: dataSet.lineDashLengths!)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        context.setLineCap(dataSet.lineCapType)
        
        // if drawing cubic lines is enabled
        switch dataSet.mode
        {
        case .linear:
            if dataSet.isCheckStepCubicLine  {
                drawStepLinear(context: context, dataSet: dataSet)
            }else{
                drawLinear(context: context, dataSet: dataSet)
            }
        case .stepped:
            drawLinear(context: context, dataSet: dataSet)
            
        case .cubicBezier:
            guard let dataProvider = dataProvider else { return }
                                            
            _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            let t = ceil(Double(_xBounds.max - _xBounds.min) * animator.phaseX)
            
            if Int(t) > Int(viewPortHandler.contentWidth*UIScreen.main.scale){
                drawLinear(context: context, dataSet: dataSet)
            }else{
                if dataSet.isCheckStepCubicLine  {
                    drawStepCubicBezier(context: context, dataSet: dataSet)
                }else{
                    drawCubicBezier(context: context, dataSet: dataSet)
                }
            }
            
        case .horizontalBezier:
            drawHorizontalBezier(context: context, dataSet: dataSet)
        }
        
        context.restoreGState()
    }
    
    private func getValidateList(_ dataSet: LineChartDataSetProtocol,  validateFlagList: inout [Bool])->Bool{
        return false
    }

    private func drawLine(
        context: CGContext,
        spline: CGMutablePath,
        drawingColor: NSUIColor)
    {
        context.beginPath()
        context.addPath(spline)
        context.setStrokeColor(drawingColor.cgColor)
        context.strokePath()
    }
    
    func drawMinMaxFlag( context: CGContext, lineColor: UIColor, textColor: UIColor){
        if let lineDataSet = dataProvider?.data?.dataSets as? [LineChartDataSet]{
            for set in lineDataSet{
                drawMaxMarker(context, dataSet: set,lineColor: lineColor, textColor: textColor)
                drawMinMarker(context, dataSet: set,lineColor: lineColor, textColor: textColor)
            }
        }
    }
    
    func drawMaxMarker(_ context: CGContext, dataSet: LineChartDataSet,lineColor: UIColor, textColor: UIColor){
        guard animator.phaseX >= 1 else { return }
        
        if dataSet.count < 1
        {
            return
        }
        guard let dataProvider = dataProvider else { return }
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)

        var maxYValue = -Double.greatestFiniteMagnitude
        var maxEntry: ChartDataEntry? = nil
        for i in _xBounds{
            let entry = dataSet.entryForIndex(i)
            if entry == nil{
                continue
            }
            if entry!.y < dataSet.minValidateValue{
                continue
            }
            let pt = trans.pixelForValues(x: entry!.x, y: entry!.y)
            if !viewPortHandler.isInBounds(x: pt.x, y: pt.y){
                continue
            }
            if dataSet.isDashLastPoint && i == _xBounds.max{
                continue
            }else{
                if entry!.y >= maxYValue{
                    maxYValue = entry!.y
                    maxEntry = entry!
                }
            }
            
        }
        
        if maxEntry == nil{
            return
        }
        
        let dataStr = dataSet.maxMinvalueFormatter == nil ? "\(maxEntry!.y)" : dataSet.maxMinvalueFormatter!.stringForValue(maxEntry!.y, entry: ChartDataEntry(), dataSetIndex: 0, viewPortHandler: nil)
        self.drawPointMarker(dataSet, context: context, entry: maxEntry!, text: dataStr, startPtOffsetY: -1.50, endPtOffsetY: -5,lineColor: lineColor, textColor: textColor)
    }
    
    func drawMinMarker(_ context: CGContext, dataSet: LineChartDataSet,lineColor: UIColor, textColor: UIColor){
        guard animator.phaseX >= 1 else { return }
        
        if dataSet.count < 1
        {
            return
        }
        guard let dataProvider = dataProvider else { return }
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        var minYValue = Double.greatestFiniteMagnitude
        var minEntry: ChartDataEntry? = nil
        for i in _xBounds{
            let entry = dataSet.entryForIndex(i)
            if entry == nil{
                continue
            }
            
            let pt = trans.pixelForValues(x: entry!.x, y: entry!.y)
            if !viewPortHandler.isInBounds(x: pt.x, y: pt.y){
                continue
            }
            
            if dataSet.isCheckStepCubicLine{
                if entry!.y < minYValue && entry!.y > dataSet.minValidateValue{
                    if dataSet.isDashLastPoint && i == _xBounds.max{
                        continue
                    }else{
                        minYValue = entry!.y
                        minEntry = entry!
                    }
                    
                }
            }else{
                if entry!.y < minYValue{
                    minYValue = entry!.y
                    minEntry = entry!
                }
            }
        }
        
        if minEntry == nil{
            return
        }
        
        let dataStr = dataSet.maxMinvalueFormatter == nil ? "\(minEntry!.y)" : dataSet.maxMinvalueFormatter!.stringForValue(minEntry!.y, entry: ChartDataEntry(), dataSetIndex: 0, viewPortHandler: nil)
        self.drawPointMarker(dataSet, context: context, entry: minEntry!, text: dataStr, startPtOffsetY: 1.5, endPtOffsetY: 5,lineColor: lineColor, textColor: textColor)
    }
    
    func drawPointMarker(_ dataSet: LineChartDataSet, context: CGContext, entry: ChartDataEntry, text:String, startPtOffsetY: CGFloat, endPtOffsetY: CGFloat,lineColor: UIColor, textColor: UIColor){
        guard let dataProvider = dataProvider else { return }
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        var vals = CGPoint(x: CGFloat(entry.x), y: CGFloat(entry.y))
        trans.pointValueToPixel(&vals)
        
        let startPt = CGPoint(x: vals.x, y: vals.y+startPtOffsetY)
        let lineLength: CGFloat  = 25
        var endPt: CGPoint
        
        var toLeft = false,toTop = false
        
        var _drawAttributes = [NSAttributedString.Key : Any]()
        _drawAttributes[.font] = UIFont.systemFont(ofSize: 12)
//        _drawAttributes[.paragraphStyle] = _paragraphStyle
        _drawAttributes[.foregroundColor] = textColor
        let textSize = getLabelSize(text, attributes: _drawAttributes)
        
        if (viewPortHandler.isInBounds(x: startPt.x+lineLength+textSize.width, y: startPt.y - startPtOffsetY)){
            toLeft = true
        }
        if (viewPortHandler.isInBounds(x: startPt.x, y: startPt.y + endPtOffsetY)){
            toTop = true
        }
        
        endPt = CGPoint(x: startPt.x + lineLength * (toLeft ? 1 : -1), y: startPt.y  + (toTop ? endPtOffsetY : -endPtOffsetY))

        //draw line
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)

        context.beginPath()
        context.move(to: startPt)
        context.addLine(to: endPt)
        context.strokePath()
        
        //draw text
        text.draw(in: CGRect(x: endPt.x - (toLeft ? 0 : textSize.width), y: endPt.y-textSize.height/2, width: textSize.width, height: textSize.height), withAttributes: _drawAttributes)
    }
    
    @objc open func getLabelSize(_ label: String, attributes: [NSAttributedString.Key : Any] ) -> CGSize
    {
        let _labelSize = label.size(withAttributes: attributes) ?? CGSize.zero
        return _labelSize
    }
    
    @objc open func drawCubicBezier(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        //设置range，多画一个后面的点，方便做平滑动画
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        let t = ceil(Double(_xBounds.max - _xBounds.min) * animator.phaseX)
        _xBounds.range = Int(t)
        //裁剪绘图区域，根据动画来
        var clipRect = viewPortHandler.contentRect
        clipRect.size.width = clipRect.width*CGFloat(animator.phaseX)
        context.clip(to: clipRect)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        let lastPointDashCubicPath = CGMutablePath()
        var isDrawLastPointDashPath = false
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            
            let firstIndex = _xBounds.min + 1
            
            var prevPrev: ChartDataEntry! = nil
            var prev: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 2, 0))
            var cur: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 1, 0))
            var next: ChartDataEntry! = cur
            var nextIndex: Int = -1
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            lastPointDashCubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
                        
            let dataSet1 = dataSet as? LineChartDataSet
            if dataSet1 != nil && dataSet1!.isDashLastPoint{
                isDrawLastPointDashPath = true
            }
//            print("_xBounds:\(_xBounds)")
            for j in _xBounds.dropFirst()  // same as firstIndex
            {
                prevPrev = prev
                prev = cur
                cur = nextIndex == j ? next : dataSet.entryForIndex(j)
                
                nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                next = dataSet.entryForIndex(nextIndex)
//                print("nextIndex:\(nextIndex), next:\(next.x),\(next.y)")
                
                if next == nil { break }
//                print("nextIndex:",nextIndex)
                prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                curDx = CGFloat(next.x - prev.x) * intensity
                curDy = CGFloat(next.y - prev.y) * intensity
                

                if dataSet.lineDashLengths == nil && isDrawLastPointDashPath && j == _xBounds.max  {
                    //最后一个点虚线
                    lastPointDashCubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                }else{
                    lastPointDashCubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                    cubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                }
            }
        }
        
        context.saveGState()
        defer { context.restoreGState() }

        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = isDrawLastPointDashPath ? lastPointDashCubicPath.mutableCopy() :   cubicPath.mutableCopy()

            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }

        if dataSet.isDrawLineWithGradientEnabled
        {
            drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
        }
        else
        {
            drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            if isDrawLastPointDashPath{
                context.setLineDash(phase: 0.0, lengths: [2, 2])
                drawLine(context: context, spline: lastPointDashCubicPath, drawingColor: drawingColor)
            }            
        }
    }
    
    //检测数据分段画曲线
    @objc open func drawStepCubicBezier(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        let bounds = calcStepBounds(context: context, dataSet: dataSet)
        
        //如果曲线上的点大于分辨率，贝塞尔曲线会导致绘图卡
        let maxPixelCount = Int(viewPortHandler.contentWidth*UIScreen.main.scale)
        var gap = 1
        if _xBounds.range > maxPixelCount{
            gap = Swift.max(1,Int(round( Double(_xBounds.range) / Double(maxPixelCount))) )
        }
        
        for bound in bounds{
            self.drawPartStepCubicBezier(context: context, dataSet: dataSet, bound: bound, gap: gap)
        }
    }
    
    open func drawPartStepCubicBezier(context: CGContext, dataSet: LineChartDataSetProtocol, bound: XBounds, gap: Int = 1){
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        let lastPointDashCubicPath = CGMutablePath()
        var isDrawLastPointDashPath = false
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if bound.range >= 1
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            
            let firstIndex = bound.min + 1
            
            var prevPrev: ChartDataEntry! = nil
            let startMin = max(bound.min, 0)
            var prev: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 2, startMin))
            var cur: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 1, startMin))
            var next: ChartDataEntry! = cur
            var nextIndex: Int = -1
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            lastPointDashCubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
                        
            let dataSet1 = dataSet as? LineChartDataSet
            if dataSet1 != nil && dataSet1!.isDashLastPoint && bound.max == dataSet.entryCount-1{
                isDrawLastPointDashPath = true
            }
            let entryCount = bound.range+1
            
//            for j in bound.dropFirst()  // same as firstIndex
//            for j in stride(from: bound.min+1, to: bound.max+1, by: gap)
            for j in stride(from: bound.min, through: bound.range + bound.min, by: gap)
            {
                
                prevPrev = prev
                prev = cur
                cur = nextIndex == j ? next : dataSet.entryForIndex(j)
                
                //第一个点不画，要不然会出现一个对两个重合点的曲线
                if (j == bound.min && prevPrev == prev && prev == cur ){continue}
//                nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
//                nextIndex = j + 1 < entryCount ? j + 1 : j
                nextIndex = j + 1 <= bound.max ? j + 1 : j
                
                next = dataSet.entryForIndex(nextIndex)
                
                if next == nil { break }
//                print("nextIndex:",nextIndex)
                prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                curDx = CGFloat(next.x - prev.x) * intensity
                curDy = CGFloat(next.y - prev.y) * intensity
                

                if dataSet.lineDashLengths == nil && isDrawLastPointDashPath && j == _xBounds.max  {
                    //最后一个点虚线
                    lastPointDashCubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                }else{
                    lastPointDashCubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                    cubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                }
            }
        }
        
        context.saveGState()
        defer { context.restoreGState() }

        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = isDrawLastPointDashPath ? lastPointDashCubicPath.mutableCopy() :   cubicPath.mutableCopy()

            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: bound)
        }

        if dataSet.isDrawLineWithGradientEnabled
        {
            drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
        }
        else
        {
            drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
            if isDrawLastPointDashPath{
                context.setLineDash(phase: 0.0, lengths: [2, 2])
                drawLine(context: context, spline: lastPointDashCubicPath, drawingColor: drawingColor)
            }
        }
    }
    @objc open func drawHorizontalBezier(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prev: ChartDataEntry! = dataSet.entryForIndex(_xBounds.min)
            var cur: ChartDataEntry! = prev
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in _xBounds.dropFirst()
            {
                prev = cur
                cur = dataSet.entryForIndex(j)
                
                let cpx = CGFloat(prev.x + (cur.x - prev.x) / 2.0)
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y * phaseY)),
                    control1: CGPoint(
                        x: cpx,
                        y: CGFloat(prev.y * phaseY)),
                    control2: CGPoint(
                        x: cpx,
                        y: CGFloat(cur.y * phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }

        if dataSet.isDrawLineWithGradientEnabled
        {
            drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
        }
        else
        {
            drawLine(context: context, spline: cubicPath, drawingColor: drawingColor)
        }
    }
    
    open func drawCubicFill(
        context: CGContext,
        dataSet: LineChartDataSetProtocol,
        spline: CGMutablePath,
        matrix: CGAffineTransform,
        bounds: XBounds)
    {
        guard
            let dataProvider = dataProvider
        else { return }
        
        if bounds.range <= 0
        {
            return
        }
        
        let fillMin = dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0

        var pt1 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min + bounds.range)?.x ?? 0.0), y: fillMin)
        var pt2 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min)?.x ?? 0.0), y: fillMin)
        pt1 = pt1.applying(matrix)
        pt2 = pt2.applying(matrix)
        
        spline.addLine(to: pt1)
        spline.addLine(to: pt2)
        spline.closeSubpath()
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: spline, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    private var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
            
    
    @objc open func drawLinear(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let entryCount = dataSet.entryCount
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // if drawing filled is enabled
        if dataSet.isDrawFilledEnabled && entryCount > 0
        {
            drawLinearFill(context: context, dataSet: dataSet, trans: trans, bounds: _xBounds)
        }
        
        context.saveGState()
        defer { context.restoreGState() }

        // more than 1 color
        if dataSet.colors.count > 1, !dataSet.isDrawLineWithGradientEnabled
        {
            if _lineSegments.count != pointsPerEntryPair
            {
                // Allocate once in correct size
                _lineSegments = [CGPoint](repeating: CGPoint(), count: pointsPerEntryPair)
            }

            for j in _xBounds.dropLast()
            {
                var e: ChartDataEntry! = dataSet.entryForIndex(j)
                
                if e == nil { continue }
                
                _lineSegments[0].x = CGFloat(e.x)
                _lineSegments[0].y = CGFloat(e.y * phaseY)
                
                if j < _xBounds.max
                {
                    // TODO: remove the check.
                    // With the new XBounds iterator, j is always smaller than _xBounds.max
                    // Keeping this check for a while, if xBounds have no further breaking changes, it should be safe to remove the check
                    e = dataSet.entryForIndex(j + 1)
                    
                    if e == nil { break }
                    
                    if isDrawSteppedEnabled
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: _lineSegments[0].y)
                        _lineSegments[2] = _lineSegments[1]
                        _lineSegments[3] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                    else
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }

                _lineSegments = _lineSegments.map { $0.applying(valueToPixelMatrix) }

                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }

                // Determine the start and end coordinates of the line, and make sure they differ.
                guard
                    let firstCoordinate = _lineSegments.first,
                    let lastCoordinate = _lineSegments.last,
                    firstCoordinate != lastCoordinate else { continue }
                
                // make sure the lines don't do shitty things outside bounds
                if !viewPortHandler.isInBoundsLeft(lastCoordinate.x) ||
                    !viewPortHandler.isInBoundsTop(max(firstCoordinate.y, lastCoordinate.y)) ||
                    !viewPortHandler.isInBoundsBottom(min(firstCoordinate.y, lastCoordinate.y))
                {
                    continue
                }
                
                // get the color that is set for this line-segment
                context.setStrokeColor(dataSet.color(atIndex: j).cgColor)
                context.strokeLineSegments(between: _lineSegments)
            }
        }
        else
        { // only one color per dataset
            guard dataSet.entryForIndex(_xBounds.min) != nil else {
                return
            }

            var firstPoint = true

            let path = CGMutablePath()
            for x in stride(from: _xBounds.min, through: _xBounds.range + _xBounds.min, by: 1)
            {
                guard let e1 = dataSet.entryForIndex(x == 0 ? 0 : (x - 1)) else { continue }
                guard let e2 = dataSet.entryForIndex(x) else { continue }
                
                let startPoint =
                    CGPoint(
                        x: CGFloat(e1.x),
                        y: CGFloat(e1.y * phaseY))
                    .applying(valueToPixelMatrix)
                
                if firstPoint
                {
                    path.move(to: startPoint)
                    firstPoint = false
                }
                else
                {
                    path.addLine(to: startPoint)
                }
                
                if isDrawSteppedEnabled
                {
                    let steppedPoint =
                        CGPoint(
                            x: CGFloat(e2.x),
                            y: CGFloat(e1.y * phaseY))
                        .applying(valueToPixelMatrix)
                    path.addLine(to: steppedPoint)
                }

                let endPoint =
                    CGPoint(
                        x: CGFloat(e2.x),
                        y: CGFloat(e2.y * phaseY))
                    .applying(valueToPixelMatrix)
                path.addLine(to: endPoint)
            }
            
            if !firstPoint
            {
                if dataSet.isDrawLineWithGradientEnabled {
                    drawGradientLine(context: context, dataSet: dataSet, spline: path, matrix: valueToPixelMatrix)
                } else {
                    context.beginPath()
                    context.addPath(path)
                    context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                    context.strokePath()
                }
            }
        }
    }
    
    func calcStepBounds(context: CGContext, dataSet: LineChartDataSetProtocol)-> [XBounds]{
        guard let dataProvider = dataProvider else { return [_xBounds]}
        
        //设置range，多画一个后面的点，方便做平滑动画
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        let t = ceil(Double(_xBounds.max - _xBounds.min) * animator.phaseX)
        _xBounds.range = Int(t)
        //裁剪绘图区域，根据动画来
        var clipRect = viewPortHandler.contentRect
        clipRect.size.width = clipRect.width*CGFloat(animator.phaseX)
        context.clip(to: clipRect)
        
        //检查数据
        guard _xBounds.range >= 1 else { return [_xBounds] }
        var bounds : [XBounds] = []
        var tMin = -1//Double.greatestFiniteMagnitude
        var tMax = -1//-Double.greatestFiniteMagnitude
  
        var j = _xBounds.min
        while(j <= _xBounds.max){
            if let entry = dataSet.entryForIndex(j){
                if entry.y > dataSet.minValidateValue{
                    tMin = j
                    var hasEndIndex = false
                    let tmpBound = XBounds()
                    tmpBound.min = min(_xBounds.max, tMin+1)
                    tmpBound.max = _xBounds.max
                    tmpBound.range = tmpBound.max - tmpBound.min
                    
                    for s in tmpBound{
                        if let entry2 = dataSet.entryForIndex(s){
                            if entry2.y < dataSet.minValidateValue{
                                tMax = s-1
                                hasEndIndex = true
                                break
                            }
                        }
                    }
                    if hasEndIndex{
                        j = tMax
                    }else{
                        j = _xBounds.max
                        tMax = j
                    }
                    //构建
                    let b = XBounds()
                    b.min = tMin
                    b.max = tMax
                    b.range = tMax - tMin
                    bounds.append(b)
                }
            }
            j += 1
        }
        return bounds
    }
    
    @objc open func drawStepLinear(context: CGContext, dataSet: LineChartDataSetProtocol){
        let bounds = calcStepBounds(context: context, dataSet: dataSet)
        
        for bound in bounds{
            self.drawPartStepLinear(context: context, dataSet: dataSet, bound: bound)
        }
    }
    
    //TODO:分段划线目前只处理了dataSet.colors.count==1的情况，dataSet.colors.count>1时，也不会处理虚线等
    open func drawPartStepLinear(context: CGContext, dataSet: LineChartDataSetProtocol, bound: XBounds){
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let entryCount = dataSet.entryCount
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
        
        let phaseY = animator.phaseY
        
//        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // if drawing filled is enabled
        if dataSet.isDrawFilledEnabled && entryCount > 0
        {
//            drawLinearFill(context: context, dataSet: dataSet, trans: trans, bounds: _xBounds)
            drawLinearFill(context: context, dataSet: dataSet, trans: trans, bounds: bound)
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        var isDrawLastPointDashPath = false
        let dataSet1 = dataSet as? LineChartDataSet
        if dataSet1 != nil && dataSet1!.isDashLastPoint && bound.max == dataSet.entryCount-1{
            isDrawLastPointDashPath = true
        }

        // more than 1 color
        if dataSet.colors.count > 1, !dataSet.isDrawLineWithGradientEnabled
        {
            if _lineSegments.count != pointsPerEntryPair
            {
                // Allocate once in correct size
                _lineSegments = [CGPoint](repeating: CGPoint(), count: pointsPerEntryPair)
            }

            for j in bound.dropLast()
            {
                var e: ChartDataEntry! = dataSet.entryForIndex(j)
                
                if e == nil { continue }
                
                _lineSegments[0].x = CGFloat(e.x)
                _lineSegments[0].y = CGFloat(e.y * phaseY)
                
                if j < bound.max
                {
                    // TODO: remove the check.
                    // With the new XBounds iterator, j is always smaller than _xBounds.max
                    // Keeping this check for a while, if xBounds have no further breaking changes, it should be safe to remove the check
                    e = dataSet.entryForIndex(j + 1)
                    
                    if e == nil { break }
                    
                    if isDrawSteppedEnabled
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: _lineSegments[0].y)
                        _lineSegments[2] = _lineSegments[1]
                        _lineSegments[3] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                    else
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }

                _lineSegments = _lineSegments.map { $0.applying(valueToPixelMatrix) }

                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }

                // Determine the start and end coordinates of the line, and make sure they differ.
                guard
                    let firstCoordinate = _lineSegments.first,
                    let lastCoordinate = _lineSegments.last,
                    firstCoordinate != lastCoordinate else { continue }
                
                // make sure the lines don't do shitty things outside bounds
                if !viewPortHandler.isInBoundsLeft(lastCoordinate.x) ||
                    !viewPortHandler.isInBoundsTop(max(firstCoordinate.y, lastCoordinate.y)) ||
                    !viewPortHandler.isInBoundsBottom(min(firstCoordinate.y, lastCoordinate.y))
                {
                    continue
                }
                
                // get the color that is set for this line-segment
                context.setStrokeColor(dataSet.color(atIndex: j).cgColor)
                context.strokeLineSegments(between: _lineSegments)
            }
        }
        else
        { // only one color per dataset
            guard dataSet.entryForIndex(_xBounds.min) != nil else {
                return
            }

            var firstPoint = true

            let path = CGMutablePath()
            
            let lastPointDashPath = CGMutablePath()
            var isLastPt = false
            
            for x in stride(from: bound.min, through: bound.range + bound.min, by: 1)
            {
                guard let e1 = dataSet.entryForIndex(x == bound.min ? bound.min : (x - 1)) else { continue }
                
//                guard let e1 = dataSet.entryForIndex(x == 0 ? 0 : (x - 1)) else { continue }
                guard let e2 = dataSet.entryForIndex(x) else { continue }
                
                if dataSet.lineDashLengths == nil && isDrawLastPointDashPath && x == _xBounds.max  {
                    //最后一个点虚线
                    isLastPt = true

                }
                
                let startPoint =
                    CGPoint(
                        x: CGFloat(e1.x),
                        y: CGFloat(e1.y * phaseY))
                    .applying(valueToPixelMatrix)
                
                if firstPoint
                {
                    path.move(to: startPoint)
                    firstPoint = false
                }
                else
                {
                    if !isLastPt{
                        path.addLine(to: startPoint)
                    }else{
                        lastPointDashPath.move(to: startPoint)
                        lastPointDashPath.addLine(to: startPoint)
                    }
                    
                }
                
                if isDrawSteppedEnabled
                {
                    let steppedPoint =
                        CGPoint(
                            x: CGFloat(e2.x),
                            y: CGFloat(e1.y * phaseY))
                        .applying(valueToPixelMatrix)
                    path.addLine(to: steppedPoint)
                }

                let endPoint =
                    CGPoint(
                        x: CGFloat(e2.x),
                        y: CGFloat(e2.y * phaseY))
                    .applying(valueToPixelMatrix)
                if !isLastPt{
                    path.addLine(to: endPoint)
                }else{
                    lastPointDashPath.addLine(to: endPoint)
                }
                
            }
            
            if !firstPoint
            {
                if dataSet.isDrawLineWithGradientEnabled {
                    drawGradientLine(context: context, dataSet: dataSet, spline: path, matrix: valueToPixelMatrix)
                } else {
                    context.beginPath()
                    context.addPath(path)
                    context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                    context.strokePath()
                    
                    if isDrawLastPointDashPath{
                        context.setLineDash(phase: 0.0, lengths: [2, 2])
                        context.beginPath()
                        context.addPath(lastPointDashPath)
                        context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                        context.strokePath()
                    }
                }
            }
        }
    }
    
    open func drawLinearFill(context: CGContext, dataSet: LineChartDataSetProtocol, trans: Transformer, bounds: XBounds)
    {
        guard let dataProvider = dataProvider else { return }
        
        let filled = generateFilledPath(
            dataSet: dataSet,
            fillMin: dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0,
            bounds: bounds,
            matrix: trans.valueToPixelMatrix)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: filled, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    /// Generates the path that is used for filled drawing.
    private func generateFilledPath(dataSet: LineChartDataSetProtocol, fillMin: CGFloat, bounds: XBounds, matrix: CGAffineTransform) -> CGPath
    {
        let phaseY = animator.phaseY
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let matrix = matrix
        
        var e: ChartDataEntry!
        
        let filled = CGMutablePath()
        
        e = dataSet.entryForIndex(bounds.min)
        if e != nil
        {
            filled.move(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // create a new path
        for x in stride(from: (bounds.min + 1), through: bounds.range + bounds.min, by: 1)
        {
            guard let e = dataSet.entryForIndex(x) else { continue }
            
            if isDrawSteppedEnabled
            {
                guard let ePrev = dataSet.entryForIndex(x-1) else { continue }
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(ePrev.y * phaseY)), transform: matrix)
            }
            
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // close up
        e = dataSet.entryForIndex(bounds.range + bounds.min)
        if e != nil
        {
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
        }
        filled.closeSubpath()
        
        return filled
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }

        if isDrawingValuesAllowed(dataProvider: dataProvider)
        {
            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            
            for i in lineData.indices
            {
                guard let
                        dataSet = lineData[i] as? LineChartDataSetProtocol,
                      shouldDrawValues(forDataSet: dataSet)
                else { continue }
                
                let valueFont = dataSet.valueFont
                
                let formatter = dataSet.valueFormatter
                
                let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                let iconsOffset = dataSet.iconsOffset
                
                // make sure the values do not interfear with the circles
                var valOffset = Int(dataSet.circleRadius * 1.75)
                
                if !dataSet.isDrawCirclesEnabled
                {
                    valOffset = valOffset / 2
                }
                
                _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)

                for j in _xBounds
                {
                    guard let e = dataSet.entryForIndex(j) else { break }
                    
                    pt.x = CGFloat(e.x)
                    pt.y = CGFloat(e.y * phaseY)
                    pt = pt.applying(valueToPixelMatrix)
                    
                    if (!viewPortHandler.isInBoundsRight(pt.x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                    {
                        continue
                    }
                    
                    if dataSet.isDrawValuesEnabled
                    {
                        context.drawText(formatter.stringForValue(e.y,
                                                                  entry: e,
                                                                  dataSetIndex: i,
                                                                  viewPortHandler: viewPortHandler),
                                         at: CGPoint(x: pt.x,
                                                     y: pt.y - CGFloat(valOffset) - valueFont.lineHeight),
                                         align: .center,
                                         angleRadians: angleRadians,
                                         attributes: [.font: valueFont,
                                                      .foregroundColor: dataSet.valueTextColorAt(j)])
                    }
                    
                    if let icon = e.icon, dataSet.isDrawIconsEnabled
                    {
                        context.drawImage(icon,
                                          atCenter: CGPoint(x: pt.x + iconsOffset.x,
                                                            y: pt.y + iconsOffset.y),
                                          size: icon.size)
                    }
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        drawCircles(context: context)
    }
    
    private func drawCircles(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }
        
        let phaseY = animator.phaseY
        
        var pt = CGPoint()
        var rect = CGRect()
        
        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        accessibleChartElements.removeAll()
        accessibilityOrderedElements = accessibilityCreateEmptyOrderedElements()

        // Make the chart header the first element in the accessible elements array
        if let chart = dataProvider as? LineChartView {
            let element = createAccessibleHeader(usingChart: chart,
                                                 andData: lineData,
                                                 withDefaultDescription: "Line Chart")
            accessibleChartElements.append(element)
        }

        context.saveGState()

        for i in lineData.indices
        {
            guard let dataSet = lineData[i] as? LineChartDataSetProtocol else { continue }

            // Skip Circles and Accessibility if not enabled,
            // reduces CPU significantly if not needed
            if !dataSet.isVisible || !dataSet.isDrawCirclesEnabled || dataSet.entryCount == 0
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            let circleRadius = dataSet.circleRadius
            let circleDiameter = circleRadius * 2.0
            let circleHoleRadius = dataSet.circleHoleRadius
            let circleHoleDiameter = circleHoleRadius * 2.0
            
            let drawCircleHole = dataSet.isDrawCircleHoleEnabled &&
                circleHoleRadius < circleRadius &&
                circleHoleRadius > 0.0
            let drawTransparentCircleHole = drawCircleHole &&
                (dataSet.circleHoleColor == nil ||
                    dataSet.circleHoleColor == NSUIColor.clear)
            
            for j in _xBounds
            {
                guard let e = dataSet.entryForIndex(j) else { break }

                pt.x = CGFloat(e.x)
                pt.y = CGFloat(e.y * phaseY)
                pt = pt.applying(valueToPixelMatrix)
                
                if (!viewPortHandler.isInBoundsRight(pt.x))
                {
                    break
                }
                
                // make sure the circles don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                {
                    continue
                }
                
                // Accessibility element geometry
                let scaleFactor: CGFloat = 3
                let accessibilityRect = CGRect(x: pt.x - (scaleFactor * circleRadius),
                                               y: pt.y - (scaleFactor * circleRadius),
                                               width: scaleFactor * circleDiameter,
                                               height: scaleFactor * circleDiameter)
                // Create and append the corresponding accessibility element to accessibilityOrderedElements
                if let chart = dataProvider as? LineChartView
                {
                    let element = createAccessibleElement(withIndex: j,
                                                          container: chart,
                                                          dataSet: dataSet,
                                                          dataSetIndex: i)
                    { (element) in
                        element.accessibilityFrame = accessibilityRect
                    }

                    accessibilityOrderedElements[i].append(element)
                }

                context.setFillColor(dataSet.getCircleColor(atIndex: j)!.cgColor)

                rect.origin.x = pt.x - circleRadius
                rect.origin.y = pt.y - circleRadius
                rect.size.width = circleDiameter
                rect.size.height = circleDiameter

                if drawTransparentCircleHole
                {
                    // Begin path for circle with hole
                    context.beginPath()
                    context.addEllipse(in: rect)
                    
                    // Cut hole in path
                    rect.origin.x = pt.x - circleHoleRadius
                    rect.origin.y = pt.y - circleHoleRadius
                    rect.size.width = circleHoleDiameter
                    rect.size.height = circleHoleDiameter
                    context.addEllipse(in: rect)
                    
                    // Fill in-between
                    context.fillPath(using: .evenOdd)
                }
                else
                {
                    context.fillEllipse(in: rect)
                    
                    if drawCircleHole
                    {
                        context.setFillColor(dataSet.circleHoleColor!.cgColor)

                        // The hole rect
                        rect.origin.x = pt.x - circleHoleRadius
                        rect.origin.y = pt.y - circleHoleRadius
                        rect.size.width = circleHoleDiameter
                        rect.size.height = circleHoleDiameter
                        
                        context.fillEllipse(in: rect)
                    }
                }
            }
        }
        
        context.restoreGState()

        // Merge nested ordered arrays into the single accessibleChartElements.
        accessibleChartElements.append(contentsOf: accessibilityOrderedElements.flatMap { $0 } )
        accessibilityPostLayoutChangedNotification()
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }
        
        let chartXMax = dataProvider.chartXMax
        
        context.saveGState()
        
        for high in indices
        {
            guard let set = lineData[high.dataSetIndex] as? LineChartDataSetProtocol,
                  set.isHighlightEnabled
            else { continue }
            
            guard let e = set.entryForXValue(high.x, closestToY: high.y) else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }

            context.setStrokeColor(set.highlightColor.cgColor)
            context.setLineWidth(set.highlightLineWidth)
            if set.highlightLineDashLengths != nil
            {
                context.setLineDash(phase: set.highlightLineDashPhase, lengths: set.highlightLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            let x = e.x // get the x-position
            let y = e.y * Double(animator.phaseY)
            
            if x > chartXMax * animator.phaseX
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
            
            let pt = trans.pixelForValues(x: x, y: y)
            
            high.setDraw(pt: pt)
            
            // draw the lines
            drawHighlightLines(context: context, point: pt, set: set)
        }
        
        context.restoreGState()
    }

    func drawGradientLine(context: CGContext, dataSet: LineChartDataSetProtocol, spline: CGPath, matrix: CGAffineTransform)
    {
        guard let gradientPositions = dataSet.gradientPositions else
        {
            assertionFailure("Must set `gradientPositions if `dataSet.isDrawLineWithGradientEnabled` is true")
            return
        }

        // `insetBy` is applied since bounding box
        // doesn't take into account line width
        // so that peaks are trimmed since
        // gradient start and gradient end calculated wrong
        let boundingBox = spline.boundingBox
            .insetBy(dx: -dataSet.lineWidth / 2, dy: -dataSet.lineWidth / 2)

        guard !boundingBox.isNull, !boundingBox.isInfinite, !boundingBox.isEmpty else {
            return
        }

        let gradientStart = CGPoint(x: 0, y: boundingBox.minY)
        let gradientEnd = CGPoint(x: 0, y: boundingBox.maxY)
        let gradientColorComponents: [CGFloat] = dataSet.colors
            .reversed()
            .reduce(into: []) { (components, color) in
                guard let (r, g, b, a) = color.nsuirgba else {
                    return
                }
                components += [r, g, b, a]
            }
        let gradientLocations: [CGFloat] = gradientPositions.reversed()
            .map { (position) in
                let location = CGPoint(x: boundingBox.minX, y: position)
                    .applying(matrix)
                let normalizedLocation = (location.y - boundingBox.minY)
                    / (boundingBox.maxY - boundingBox.minY)
                return normalizedLocation.clamped(to: 0...1)
            }

        let baseColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
                colorSpace: baseColorSpace,
                colorComponents: gradientColorComponents,
                locations: gradientLocations,
                count: gradientLocations.count) else {
            return
        }

        context.saveGState()
        defer { context.restoreGState() }

        context.beginPath()
        context.addPath(spline)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
    }
    
    /// Creates a nested array of empty subarrays each of which will be populated with NSUIAccessibilityElements.
    /// This is marked internal to support HorizontalBarChartRenderer as well.
    private func accessibilityCreateEmptyOrderedElements() -> [[NSUIAccessibilityElement]]
    {
        guard let chart = dataProvider as? LineChartView else { return [] }

        let dataSetCount = chart.lineData?.dataSetCount ?? 0

        return Array(repeating: [NSUIAccessibilityElement](),
                     count: dataSetCount)
    }

    /// Creates an NSUIAccessibleElement representing the smallest meaningful bar of the chart
    /// i.e. in case of a stacked chart, this returns each stack, not the combined bar.
    /// Note that it is marked internal to support subclass modification in the HorizontalBarChart.
    private func createAccessibleElement(withIndex idx: Int,
                                         container: LineChartView,
                                         dataSet: LineChartDataSetProtocol,
                                         dataSetIndex: Int,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement
    {
        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        let xAxis = container.xAxis

        guard let e = dataSet.entryForIndex(idx) else { return element }
        guard let dataProvider = dataProvider else { return element }

        // NOTE: The formatter can cause issues when the x-axis labels are consecutive ints.
        // i.e. due to the Double conversion, if there are more than one data set that are grouped,
        // there is the possibility of some labels being rounded up. A floor() might fix this, but seems to be a brute force solution.
        let label = xAxis.valueFormatter?.stringForValue(e.x, axis: xAxis) ?? "\(e.x)"

        let elementValueText = dataSet.valueFormatter.stringForValue(e.y,
                                                                     entry: e,
                                                                     dataSetIndex: dataSetIndex,
                                                                     viewPortHandler: viewPortHandler)

        let dataSetCount = dataProvider.lineData?.dataSetCount ?? -1
        let doesContainMultipleDataSets = dataSetCount > 1

        element.accessibilityLabel = "\(doesContainMultipleDataSets ? (dataSet.label ?? "")  + ", " : "") \(label): \(elementValueText)"

        modifier(element)

        return element
    }
}
