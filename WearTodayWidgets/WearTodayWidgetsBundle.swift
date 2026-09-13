import WidgetKit
import SwiftUI

@main
struct WearTodayWidgetsBundle: WidgetBundle {
    var body: some Widget {
        EmojiWidget()
        DescriptionWidget()
        CombinedWidget()
    }
}
