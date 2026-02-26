import SwiftUI

struct DividendCalendarView: View {
    var body: some View {
        NavigationStack {
            // STORY-011: Dividend calendar content goes here
            ContentUnavailableView(
                "No upcoming dividends",
                systemImage: "calendar",
                description: Text("Add holdings to see your dividend schedule.")
            )
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    DividendCalendarView()
}
