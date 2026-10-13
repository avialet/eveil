import Foundation

/// Calendrier fixe des tests : gregorien, Europe/Paris (changements d'heure reels), lundi en tete.
let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

/// Date a Paris : `at(2026, 10, 14, 15, 40)`.
func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    paris.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}
