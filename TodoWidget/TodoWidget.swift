import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [
            TodoItem(id: "1", title: "Buy groceries", isCompleted: false, createdAt: Date(), dueDate: nil, userId: "preview", priority: 1),
            TodoItem(id: "2", title: "Call mom", isCompleted: false, createdAt: Date(), dueDate: nil, userId: "preview", priority: 0)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        // Read from shared UserDefaults App Group
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Here you would fetch active tasks from an App Group UserDefaults 
        // to populate the timeline.
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [TodoItem]
}

struct TodoWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Tasks")
                .font(.headline)
            
            if entry.tasks.isEmpty {
                Text("All caught up!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.tasks.prefix(3)) { task in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.blue)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
    }
}

@main
struct TodoWidget: Widget {
    let kind: String = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Tasks")
        .description("View your active tasks for the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
