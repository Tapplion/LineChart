//
//  https://github.com/Tapplion/LineChart
//  Copyright (c) Pascal Kimmel 2020-present
//  Licensed under the MIT license. See LICENSE file.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var chart: LineChart!
    @IBOutlet private weak var curvedChart: LineChart!
    
    private let backgroundColor = #colorLiteral(red: 0, green: 0.3529411765, blue: 0.6156862745, alpha: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let entries = generateRandomEntries()
        
        view.backgroundColor = backgroundColor
        
        chart.chartItems = entries
        chart.mainViewBackGroundColor = backgroundColor
        chart.lineColor = .white
        chart.axisLabelsColor = .white
        chart.axisColor = .white
        chart.showsGradientLayer = true
        
        curvedChart.chartItems = entries
        curvedChart.mainViewBackGroundColor = backgroundColor
        curvedChart.lineColor = .white
        curvedChart.axisLabelsColor = .white
        curvedChart.axisColor = .white
        curvedChart.drawsCurvedLine = true
        curvedChart.showsGradientLayer = true
    }
}

private extension ViewController {
    func generateRandomEntries() -> [ChartItem] {
        var result: [ChartItem] = []
        for i in 0..<10 {
            let value = Int(arc4random() % 500)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "dd"
            var date = Date()
            date.addTimeInterval(TimeInterval(24*60*60*i))
            
            result.append(ChartItem(value: value, label: formatter.string(from: date)))
        }
        return result
    }
}
