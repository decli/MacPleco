import MacPlecoKit

// SwiftUI's `App` protocol supplies `static func main()`. Keeping the entry
// point here (rather than an `@main` type inside the library) lets the test
// target link MacPlecoKit without tripping over a duplicate `main` symbol.
MacPlecoApp.main()
