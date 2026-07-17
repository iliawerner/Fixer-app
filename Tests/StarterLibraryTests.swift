import Testing
@testable import fixer

struct StarterLibraryTests {

    @Test func everyStarterUsesTextPlaceholder() {
        for starter in StarterLibrary.all {
            #expect(starter.prompt.contains("{text}"), "\(starter.name) is missing the {text} placeholder")
        }
    }

    @Test func starterNamesAreUnique() {
        let names = StarterLibrary.all.map(\.name)
        #expect(Set(names).count == names.count)
    }
}
