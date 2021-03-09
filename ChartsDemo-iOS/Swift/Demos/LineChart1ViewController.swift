//
//  LineChart1ViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-09.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit
import Charts

class UDLineChartV2 : LineChartView{
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }
    
    
    func initXAxis(){
        let xAxis = self.xAxis
        xAxis.drawLabelsEnabled = true
        xAxis.drawAxisLineEnabled = true
        xAxis.axisLineWidth = 0.5
        xAxis.drawGridLinesEnabled = false//是否绘制坐标轴的刻度线
        xAxis.avoidFirstLastClippingEnabled = true//设置首尾的值是否自动调整，避免被遮挡
        xAxis.labelPosition = .bottom
        xAxis.axisLineColor = .red //X轴颜色
        xAxis.labelTextColor = UIColor.red.withAlphaComponent(0.5) //X轴数据颜色
//        xAxis.labelCount = 4
        xAxis.setLabelCount(4, force: true)
        
        xAxis.valueFormatter = DateValueFormatter();
    }
    
    func initYAxis(){
        self.rightAxis.enabled = false
        
        let leftAxis = self.leftAxis
        //重置最大最小值，autoscale使用
        leftAxis.resetCustomAxisMin()
        leftAxis.resetCustomAxisMax()
        
        leftAxis.drawGridLinesEnabled = true //是否显示Y坐标轴上的刻度横线，默认是TRUE
        leftAxis.drawAxisLineEnabled = true //是否绘制坐标轴线，即含有坐标的那条线，默认TRUE
        leftAxis.drawZeroLineEnabled = false //是否绘制0刻度线
        leftAxis.drawLabelsEnabled = true //是否显示Y轴刻度
        leftAxis.gridLineDashLengths = nil
        leftAxis.labelPosition = .outsideChart
        leftAxis.labelCount = 4
//        leftAxis.spaceBottom = 1
//        leftAxis.spaceTop = 1
        leftAxis.inverted = false
        leftAxis.axisLineWidth = 0.5
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawTopYLabelEntryEnabled = true
        
        leftAxis.gridColor = .green//Y轴刻度线颜色
        leftAxis.axisLineColor = .blue//Y轴颜色
        leftAxis.labelTextColor = .blue//Y轴刻度颜色

//        leftAxis.axisMaximum = 200
//        leftAxis.axisMinimum = -50
    }
    func setupChartView(){
        self.chartDescription.enabled = false
        self.dragEnabled = true
        self.setScaleEnabled(true)
        self.pinchZoomEnabled = true
        
        //自动缩放
        self.scaleXEnabled = false
        self.scaleYEnabled = false
        self.autoScaleMinMaxEnabled = true
        self.minMaxFlagLineColor = UIColor.green
        self.isShowMaxMinFlag = true
        
        //长按手势
        self.longPressEnabled = true
        
        //x轴
        initXAxis()
        //y轴
        initYAxis()
        //图例
        self.legend.enabled = false
    }
    
    func initView(){
        initXAxis()
        initYAxis()
        setupChartView()
    }
    
    //scale function
    var startVisibleRange: Double = 0
    
    func doStartScale(){
        if (startVisibleRange != 0 && self.data != nil && self.data!.entryCount > 0){
            let scale = self.xAxis.axisRange / startVisibleRange
            self.setVisibleXRangeMinimum(startVisibleRange)
            print("startScale:\(scale)")
            let maxPt : CGPoint = self.getHighestVisibleCenterPoint()
            if let dataSet = data?.dataSet(at: 0){
                let p1 = self.getTransformer(forAxis: dataSet.axisDependency).pixelForValues(x: (Double)(maxPt.x), y: (Double)(maxPt.y))
                _ = self.viewPortHandler.resetZoom()
                
                zoom(scaleX: CGFloat(scale), scaleY: 1, x: p1.x*CGFloat(scale), y: p1.y/2)
            }
        }
    }
    
    //指定向左或向右移动一个X轴数据的间隔
    func doTranslace(stepXCount: Int){
        if (self.data != nil && self.data!.entryCount > 0){
            var delta = getTwoPointDelta() * Double(stepXCount)
            let newMatrix = viewPortHandler.touchMatrix.translatedBy(x: CGFloat(delta), y: 0)
            viewPortHandler.refresh(newMatrix: newMatrix, chart: self, invalidate: true)
        }
    }
    
    func getTwoPointDelta() -> Double{
        guard (self.data != nil && self.data!.entryCount > 0 ) else {
            return 0
        }
        guard let dataSet = data?.dataSet(at: 0) else {return 0}
        if dataSet.entryCount > 2{
            let p1 = self.getTransformer(forAxis: dataSet.axisDependency).pixelForValues(x: (Double)(dataSet.entryForIndex(0)?.x ?? 0), y: (Double)(dataSet.entryForIndex(0)?.y ?? 0))
            let p2 = self.getTransformer(forAxis: dataSet.axisDependency).pixelForValues(x: (Double)(dataSet.entryForIndex(1)?.x ?? 0), y: (Double)(dataSet.entryForIndex(1)?.y ?? 0))
            return Double(p2.x - p1.x)
        }
        return 0
    }
    //放大一步
    func doScaleX(stepXCount: Int){
        let maxScaleX = viewPortHandler.maxScaleY
        let minScaleX = viewPortHandler.minScaleX
        
        let oneStep = (maxScaleX - minScaleX) / 10
        let matrix = viewPortHandler.touchMatrix
        
        let curX = matrix.a
        var tartgetScale: CGFloat = 1
        if stepXCount > 0{
            tartgetScale = min(curX + oneStep*CGFloat(stepXCount), maxScaleX)
        }else{
            tartgetScale = max(curX - oneStep*CGFloat(stepXCount), minScaleX)
        }
        
        let newMatrix = viewPortHandler.touchMatrix.scaledBy(x: tartgetScale, y: 1)
        viewPortHandler.refresh(newMatrix: newMatrix, chart: self, invalidate: true)
    }
    
    func setDataInSacelable(_ data: LineChartData, hasAnimate: Bool = false){
        //setMinOffsetL(50)
        self.data = data
        self.notifyDataSetChanged()
        self.fitScreen()
        self.doStartScale()
        self.setNeedsDisplay()
        if (hasAnimate && data != nil){
            let entryCount = data.entryCount
            
            var animateTime: Double = 0
            if entryCount < 2{
                animateTime = 0.2
            }else if animateTime < 10{
                animateTime = 0.6
            }else{
                animateTime = 0.8
            }
            
            self.animate(xAxisDuration: animateTime)
        }
    }
    
}


class LineChart1ViewController: DemoBaseViewController {

    @IBOutlet var chartView: UDLineChartV2!//LineChartView!
    @IBOutlet var sliderX: UISlider!
    @IBOutlet var sliderY: UISlider!
    @IBOutlet var sliderTextX: UITextField!
    @IBOutlet var sliderTextY: UITextField!

    func initXAxis(){
        let xAxis = chartView.xAxis
        xAxis.drawLabelsEnabled = true
        xAxis.drawAxisLineEnabled = true
        xAxis.axisLineWidth = 0.5
        xAxis.drawGridLinesEnabled = false//是否绘制坐标轴的刻度线
        xAxis.avoidFirstLastClippingEnabled = true//设置首尾的值是否自动调整，避免被遮挡
        xAxis.labelPosition = .bottom
        xAxis.axisLineColor = .red //X轴颜色
        xAxis.labelTextColor = UIColor.red.withAlphaComponent(0.5) //X轴数据颜色
//        xAxis.labelCount = 4
        xAxis.setLabelCount(4, force: true)
        
        xAxis.valueFormatter = DateValueFormatter();
    }
    
    func initYAxis(){
        chartView.rightAxis.enabled = false
        
        let leftAxis = chartView.leftAxis
        //重置最大最小值，autoscale使用
        leftAxis.resetCustomAxisMin()
        leftAxis.resetCustomAxisMax()
        
        leftAxis.drawGridLinesEnabled = true //是否显示Y坐标轴上的刻度横线，默认是TRUE
        leftAxis.drawAxisLineEnabled = true //是否绘制坐标轴线，即含有坐标的那条线，默认TRUE
        leftAxis.drawZeroLineEnabled = false //是否绘制0刻度线
        leftAxis.drawLabelsEnabled = true //是否显示Y轴刻度
        leftAxis.gridLineDashLengths = nil
        leftAxis.labelPosition = .outsideChart
        leftAxis.labelCount = 4
//        leftAxis.spaceBottom = 1
//        leftAxis.spaceTop = 1
        leftAxis.inverted = false
        leftAxis.axisLineWidth = 0.5
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawTopYLabelEntryEnabled = true
        
        leftAxis.gridColor = .green//Y轴刻度线颜色
        leftAxis.axisLineColor = .blue//Y轴颜色
        leftAxis.labelTextColor = .blue//Y轴刻度颜色

//        leftAxis.axisMaximum = 200
//        leftAxis.axisMinimum = -50
    }
    func setupChartView(){
        chartView.chartDescription.enabled = false
        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        
        //自动缩放
        chartView.scaleXEnabled = false
        chartView.scaleYEnabled = false
        chartView.autoScaleMinMaxEnabled = true
        chartView.minMaxFlagLineColor = UIColor.green
        chartView.isShowMaxMinFlag = true
        //长按手势
        chartView.longPressEnabled = true
        
        //x轴
        initXAxis()
        //y轴
        initYAxis()
        //图例
        chartView.legend.enabled = false
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        

        // Do any additional setup after loading the view.
        self.title = "Line Chart 1"
        self.options = [.toggleValues,
                        .toggleFilled,
                        .toggleCircles,
                        .toggleCubic,
                        .toggleHorizontalCubic,
                        .toggleIcons,
                        .toggleStepped,
                        .toggleHighlight,
                        .toggleGradientLine,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .saveToGallery,
                        .togglePinchZoom,
                        .toggleAutoScaleMinMax,
                        .toggleData]

        chartView.delegate = self
//        self.setupChartView()


//        let marker = BalloonMarker(color: UIColor(white: 180/255, alpha: 1),
//                                   font: .systemFont(ofSize: 12),
//                                   textColor: .white,
//                                   insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8))
//        marker.chartView = chartView
//        marker.minimumSize = CGSize(width: 80, height: 40)
//        chartView.marker = marker
        
        let mr = HighlightMarker(color: UIColor.green, circleRadius: 3.0, shadowWidth: 3.0)
        mr.chartView = chartView
        mr.size = CGSize(width: 10, height: 10)
        chartView.marker = mr
//
//        chartView.legend.form = .line

        sliderX.value = 45
        sliderY.value = 100
        slidersValueChanged(nil)
        
        

//        chartView.animate(xAxisDuration: 2.5)
        
    }

    @objc override func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight){
        print("entry:\(entry)")
        guard let set = chartView.data![highlight.dataSetIndex] as? LineChartDataSetProtocol,
              set.isHighlightEnabled
        else { return }
            
        guard let e = set.entryForXValue(highlight.x, closestToY: highlight.y) else { return }
         let e1 = set.entryIndex(entry: e)
        
        print("e1 :\(e1)")
    }
    override func updateChartData() {
        if self.shouldHideData {
            chartView.data = nil
            return
        }

//        self.setDataCount(Int(sliderX.value), range: UInt32(sliderY.value))
        self.setDataCount(8, range: UInt32(sliderY.value))
//        self.setDataCount(10, range: UInt32(sliderY.value))
    }

    func setDataCount(_ count: Int, range: UInt32) {
        let v1: [Double] = [1,5,14,8,7,2]//[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]// [-1,1,2,3,-1,-1,4,5,6,7]
        let date: Double = 1612915200
        let values = (0..<count).map { (i) -> ChartDataEntry in
//            let val = Double(arc4random_uniform(range) + 3)
            let  val = v1[i % v1.count] * 1000
            let d = date + Double(i*60*60*24)
            return ChartDataEntry(x: d, y: val, icon: #imageLiteral(resourceName: "icon"))
//            return ChartDataEntry(x: Double(i), y: val, icon: #imageLiteral(resourceName: "icon"))
        }
//        let values = (0..<count).map { (i) -> ChartDataEntry in
//            let val = Double(arc4random_uniform(range) + 3)
//            return ChartDataEntry(x: Double(i), y: val, icon: #imageLiteral(resourceName: "icon"))
//        }
        

        chartView.startVisibleRange = 5*60*60*24//6.5*60*60*24
        
        let set1 = LineChartDataSet(entries: values, label: "DataSet 1")
        set1.drawIconsEnabled = false
        setup(set1)

//        let value = ChartDataEntry(x: Double(3), y: 3)
//        set1.addEntryOrdered(value)
        let gcolor = UIColor(red: 0.139412, green: 0.772745, blue: 0.780196, alpha: 1)
        let gradientColors = [gcolor.cgColor,
                              gcolor.cgColor,
                              gcolor.withAlphaComponent(0.9).cgColor,
                              gcolor.withAlphaComponent(0.4).cgColor,
                              gcolor.withAlphaComponent(0.1).cgColor,
                              gcolor.withAlphaComponent(0).cgColor]
//            [ChartColorTemplates.colorFromString("#00ff0000").cgColor,
//                              ChartColorTemplates.colorFromString("#ffff0000").cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!

        set1.fillAlpha = 0.06
        set1.fill = LinearGradientFill(gradient: gradient, angle: 270)
        set1.drawFilledEnabled = true

        let data = LineChartData(dataSet: set1)

//        chartView.data = data
        chartView.setDataInSacelable(data, hasAnimate: true)
        
        if let dataSet = chartView.data?.dataSet(at: 0){
            if dataSet.entryCount > 0{
                let entry = dataSet.entryForIndex(dataSet.entryCount-1)
                let h = Highlight(x: entry!.x, y: entry!.y, dataSetIndex: 0)
                chartView.highlightValue(h, callDelegate: false)
            }
        }
    }

    private func setup(_ dataSet: LineChartDataSet) {
        dataSet.mode = .cubicBezier
        dataSet.isDashLastPoint = false
        dataSet.isCheckStepCubicLine = true//false//true
        dataSet.drawValuesEnabled = false
        dataSet.drawCirclesEnabled = false
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.highlightColor = .red
        
//        dataSet.isss
        if dataSet.isDrawLineWithGradientEnabled {
            dataSet.lineDashLengths = nil
            dataSet.highlightLineDashLengths = nil
            dataSet.setColors(.black, .red, .white)
            dataSet.setCircleColor(.black)
            dataSet.gradientPositions = [0, 40, 100]
            dataSet.lineWidth = 1
            dataSet.circleRadius = 3
            dataSet.drawCircleHoleEnabled = false
            dataSet.valueFont = .systemFont(ofSize: 9)
            dataSet.formLineDashLengths = nil
            dataSet.formLineWidth = 1
            dataSet.formSize = 15
        } else {
            dataSet.lineDashLengths = nil
//            dataSet.lineDashLengths = [5, 2.5]
//            dataSet.highlightLineDashLengths = [5, 2.5]
            dataSet.setColor(.black)
            dataSet.setCircleColor(.black)
            dataSet.gradientPositions = nil
            dataSet.lineWidth = 1
            dataSet.circleRadius = 3
            dataSet.drawCircleHoleEnabled = false
            dataSet.valueFont = .systemFont(ofSize: 9)
            dataSet.formLineDashLengths = [5, 2.5]
            dataSet.formLineWidth = 1
            dataSet.formSize = 15
        }
    }

    override func optionTapped(_ option: Option) {
        guard let data = chartView.data else { return }

        switch option {
        case .toggleFilled:
            for case let set as LineChartDataSet in data {
                set.drawFilledEnabled = !set.drawFilledEnabled
            }
            chartView.setNeedsDisplay()

        case .toggleCircles:
            for case let set as LineChartDataSet in data {
                set.drawCirclesEnabled = !set.drawCirclesEnabled
            }
            chartView.setNeedsDisplay()

        case .toggleCubic:
            for case let set as LineChartDataSet in data {
                set.mode = (set.mode == .cubicBezier) ? .linear : .cubicBezier
            }
            chartView.setNeedsDisplay()

        case .toggleStepped:
            for case let set as LineChartDataSet in data {
                set.mode = (set.mode == .stepped) ? .linear : .stepped
            }
            chartView.setNeedsDisplay()

        case .toggleHorizontalCubic:
            for case let set as LineChartDataSet in data {
                set.mode = (set.mode == .cubicBezier) ? .horizontalBezier : .cubicBezier
            }
            chartView.setNeedsDisplay()
        case .toggleGradientLine:
            for set in chartView.data!.dataSets as! [LineChartDataSet] {
                set.isDrawLineWithGradientEnabled = !set.isDrawLineWithGradientEnabled
                setup(set)
            }
            chartView.setNeedsDisplay()
        default:
            super.handleOption(option, forChartView: chartView)
        }
    }

    @IBAction func slidersValueChanged(_ sender: Any?) {
        sliderTextX.text = "\(Int(sliderX.value))"
        sliderTextY.text = "\(Int(sliderY.value))"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//            self.contentView.backgroundColor = UTheme.color.content
            self.updateChartData()
        }
//        self.updateChartData()
    }
}
