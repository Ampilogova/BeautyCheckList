//
//  ContentView.swift
//  BeautyCheckList
//
//  Created by Tatiana Ampilogova on 4/23/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("savedRoutineStore") private var savedRoutineStore = ""

    @State private var selectedDate = Date()
    @State private var routinesByDay = [String: DailyRoutine]()

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beauty Checklist")
                            .font(.largeTitle.bold())
                        Text("Choose a day and adjust the AM and PM routine for that date.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    calendarStrip

                    HStack(alignment: .top, spacing: 16) {
                        routineColumn(
                            title: "AM",
                            subtitle: "Morning routine",
                            tint: .orange,
                            items: bindingForMorningItems()
                        )

                        routineColumn(
                            title: "PM",
                            subtitle: "Evening routine",
                            tint: .indigo,
                            items: bindingForEveningItems()
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadRoutines()
            ensureRoutineExists(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            ensureRoutineExists(for: newValue)
        }
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleDates, id: \.self) { date in
                        calendarDayButton(for: date)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private var visibleDates: [Date] {
        (-7...14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: selectedDate)
        }
    }

    private func calendarDayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption.weight(.semibold))
                Text(date.formatted(.dateTime.day()))
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 52, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.pink : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.pink : Color.pink.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func routineColumn(
        title: String,
        subtitle: String,
        tint: Color,
        items: Binding<[RoutineItem]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Button {
                        toggleItem(id: item.wrappedValue.id, in: items)
                    } label: {
                        Image(systemName: item.wrappedValue.isDone ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)

                    TextField("Add a step", text: item.title)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Button {
                items.wrappedValue.append(RoutineItem(title: "", isDone: false))
                saveRoutines()
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func bindingForMorningItems() -> Binding<[RoutineItem]> {
        Binding(
            get: {
                routine(for: selectedDate).morning
            },
            set: { newValue in
                var updated = routine(for: selectedDate)
                updated.morning = newValue
                updateRoutine(updated, for: selectedDate)
            }
        )
    }

    private func bindingForEveningItems() -> Binding<[RoutineItem]> {
        Binding(
            get: {
                routine(for: selectedDate).evening
            },
            set: { newValue in
                var updated = routine(for: selectedDate)
                updated.evening = newValue
                updateRoutine(updated, for: selectedDate)
            }
        )
    }

    private func toggleItem(id: UUID, in items: Binding<[RoutineItem]>) {
        guard let index = items.wrappedValue.firstIndex(where: { $0.id == id }) else {
            return
        }

        items.wrappedValue[index].isDone.toggle()
        saveRoutines()
    }

    private func routine(for date: Date) -> DailyRoutine {
        let key = dayKey(for: date)
        return routinesByDay[key] ?? DailyRoutine.defaultRoutine
    }

    private func updateRoutine(_ routine: DailyRoutine, for date: Date) {
        routinesByDay[dayKey(for: date)] = routine
        saveRoutines()
    }

    private func ensureRoutineExists(for date: Date) {
        let key = dayKey(for: date)

        if routinesByDay[key] == nil {
            routinesByDay[key] = DailyRoutine.defaultRoutine
            saveRoutines()
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func loadRoutines() {
        guard
            !savedRoutineStore.isEmpty,
            let data = savedRoutineStore.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String: DailyRoutine].self, from: data)
        else {
            return
        }

        routinesByDay = decoded
    }

    private func saveRoutines() {
        guard let data = try? JSONEncoder().encode(routinesByDay),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        savedRoutineStore = json
    }
}

private struct DailyRoutine: Codable {
    var morning: [RoutineItem]
    var evening: [RoutineItem]

    static let defaultRoutine = DailyRoutine(
        morning: [
            RoutineItem(title: "Cleanser", isDone: false),
            RoutineItem(title: "Serum", isDone: false),
            RoutineItem(title: "Moisturizer", isDone: false),
            RoutineItem(title: "Sunscreen", isDone: false)
        ],
        evening: [
            RoutineItem(title: "Makeup remover", isDone: false),
            RoutineItem(title: "Cleanser", isDone: false),
            RoutineItem(title: "Treatment", isDone: false),
            RoutineItem(title: "Night cream", isDone: false)
        ]
    )
}

private struct RoutineItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool
}

#Preview {
    ContentView()
}
