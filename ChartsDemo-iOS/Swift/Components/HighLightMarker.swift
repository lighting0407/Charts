//
//  HighLightMarker.swift
//  ChartsDemo-iOS-Swift
//
//  Created by lighting on 2021/3/5.
//  Copyright © 2021 dcg. All rights reserved.
//

import Foundation
import Charts
#if canImport(UIKit)
    import UIKit
#endif

open class HighlightMarker: MarkerImage
{
    var color: UIColor = UIColor.white
    var radius: CGFloat = 3.0
    var shadowWidth: CGFloat = 3.0
    @objc public init(color: UIColor, circleRadius: CGFloat, shadowWidth: CGFloat)
    {
        self.color = color
        self.radius = circleRadius
        self.shadowWidth = shadowWidth
        
        super.init()
        size = CGSize(width: (circleRadius + shadowWidth)*2, height:  (circleRadius + shadowWidth)*2)
    }
    
    open override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint
    {
        return super.offsetForDrawing(atPoint: point)
    }
    
    open override func draw(context: CGContext, point: CGPoint)
    {
        context.setFillColor(color.withAlphaComponent(0.4).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1)
        context.beginPath()
        let sW: CGFloat = self.radius + self.shadowWidth
        context.addArc(center: point, radius: sW, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
        context.fillPath(using: .evenOdd)


        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.beginPath()
        context.addArc(center: point, radius: self.radius, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
        context.fillPath(using: .evenOdd)
//        context.closePath()
}
    
//    open override func refreshContent(entry: ChartDataEntry, highlight: Highlight)
//    {
//        setLabel(String(entry.y))
//    }

}
