import XCTest
@testable import BrowCore

final class CoverLookupTests: XCTestCase {
    func testBrowsersAreRecognised() {
        XCTAssertTrue(CoverLookup.isBrowser("com.google.Chrome"))
        XCTAssertTrue(CoverLookup.isBrowser("com.apple.Safari"))
        XCTAssertTrue(CoverLookup.isBrowser("company.thebrowser.Browser"))   // Arc
        XCTAssertFalse(CoverLookup.isBrowser("com.spotify.client"))          // the Spotify app sends real covers
        XCTAssertFalse(CoverLookup.isBrowser(nil))
    }

    func testChromiumBrowsersSendTheirIconInsteadOfCover() {
        XCTAssertTrue(CoverLookup.sendsPlaceholderArtwork("com.google.Chrome"))
        XCTAssertTrue(CoverLookup.sendsPlaceholderArtwork("ru.yandex.desktop.yandex-browser"))
        XCTAssertFalse(CoverLookup.sendsPlaceholderArtwork("com.apple.Safari"))
        XCTAssertFalse(CoverLookup.sendsPlaceholderArtwork("com.apple.Music"))
    }

    func testSearchURL() throws {
        let url = try XCTUnwrap(CoverLookup.searchURL(artist: "Егор Крид", title: "Таро", country: "RU"))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "https")
        XCTAssertEqual(parts.host, "itunes.apple.com")
        XCTAssertEqual(parts.path, "/search")
        let query = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["term"], "Егор Крид Таро")
        XCTAssertEqual(query["media"], "music")
        XCTAssertEqual(query["entity"], "song")
        XCTAssertEqual(query["country"], "RU")
    }

    func testSearchURLNeedsATitle() {
        XCTAssertNil(CoverLookup.searchURL(artist: "Кто-то", title: "  ", country: "US"))
    }

    func testPicksTheMatchingResultAndAsksForALargeCover() {
        let json = #"""
        {"resultCount":2,"results":[
          {"artistName":"Другой исполнитель","trackName":"Таро","artworkUrl100":"https://is1.mzstatic.com/a/100x100bb.jpg"},
          {"artistName":"Егор Крид","trackName":"Таро (feat. X)","artworkUrl100":"https://is1.mzstatic.com/b/100x100bb.jpg"}]}
        """#
        XCTAssertEqual(CoverLookup.artworkURL(from: Data(json.utf8), artist: "Егор Крид", title: "Таро"),
                       URL(string: "https://is1.mzstatic.com/b/600x600bb.jpg"))
    }

    func testOtherSongsOfTheArtistAreNotUsed() {
        // A wrong cover is worse than none: the search may return the artist's other songs.
        let json = #"{"resultCount":1,"results":[{"artistName":"Егор Крид","trackName":"Голос","artworkUrl100":"https://is1.mzstatic.com/c/100x100bb.jpg"}]}"#
        XCTAssertNil(CoverLookup.artworkURL(from: Data(json.utf8), artist: "Егор Крид", title: "Таро"))
    }

    func testSameTitleByAnotherArtistIsNotUsed() {
        let json = #"{"resultCount":1,"results":[{"artistName":"Кто-то ещё","trackName":"Таро","artworkUrl100":"https://is1.mzstatic.com/d/100x100bb.jpg"}]}"#
        XCTAssertNil(CoverLookup.artworkURL(from: Data(json.utf8), artist: "Егор Крид", title: "Таро"))
    }

    func testTitleAloneIsEnoughWhenArtistIsUnknown() {
        let json = #"{"resultCount":1,"results":[{"artistName":"Кто-то","trackName":"Таро","artworkUrl100":"https://is1.mzstatic.com/e/100x100bb.jpg"}]}"#
        XCTAssertEqual(CoverLookup.artworkURL(from: Data(json.utf8), artist: "", title: "Таро"),
                       URL(string: "https://is1.mzstatic.com/e/600x600bb.jpg"))
    }

    func testNoResultsOrGarbage() {
        XCTAssertNil(CoverLookup.artworkURL(from: Data(#"{"resultCount":0,"results":[]}"#.utf8), artist: "A", title: "B"))
        XCTAssertNil(CoverLookup.artworkURL(from: Data("not json".utf8), artist: "A", title: "B"))
    }

    func testCacheKeyIgnoresCaseAndSpaces() {
        XCTAssertEqual(CoverLookup.cacheKey(artist: " Егор Крид ", title: "ТАРО"),
                       CoverLookup.cacheKey(artist: "егор крид", title: "таро"))
    }

    func testResultWithoutNamesIsNotUsed() {
        let json = #"{"resultCount":1,"results":[{"artistName":"","trackName":"","artworkUrl100":"https://is1.mzstatic.com/f/100x100bb.jpg"}]}"#
        XCTAssertNil(CoverLookup.artworkURL(from: Data(json.utf8), artist: "Егор Крид", title: "Таро"))
    }
}
