import XCTest
@testable import BrowCore

final class WebLinkTests: XCTestCase {
    func testAcceptsWebAddresses() {
        XCTAssertEqual(WebLink.parse("https://books.yandex.ru/books/abc"), URL(string: "https://books.yandex.ru/books/abc"))
        XCTAssertEqual(WebLink.parse("  http://example.com  "), URL(string: "http://example.com"))
        XCTAssertEqual(WebLink.parse("books.yandex.ru/books/abc"), URL(string: "https://books.yandex.ru/books/abc"))
    }

    func testRejectsEverythingElse() {
        for text in ["", "привет мир", "javascript:alert(1)", "file:///etc/passwd", "mailto:a@b.ru",
                     "ftp://example.com", "https://", "просто текст.", "two\nlines.com", "localhost"] {
            XCTAssertNil(WebLink.parse(text), text)
        }
    }
}

final class LinkStoreTests: XCTestCase {
    var store = LinkStore()
    let book = URL(string: "https://books.yandex.ru/books/abc")!
    let news = URL(string: "https://example.com/news")!

    func testNewestFirstAndNoDuplicates() {
        store.add(book); store.add(news); store.add(URL(string: "https://books.yandex.ru/books/abc/")!)
        XCTAssertEqual(store.links.map(\.url), [book, news])
    }

    func testDisplayTitlePrefersCustomThenPageTitleThenAddress() {
        let id = store.add(book)
        XCTAssertEqual(store.links[0].displayTitle, "books.yandex.ru/books/abc")
        store.setPageInfo(id: id, title: "Мастер и Маргарита — Яндекс Книги", icon: nil)
        XCTAssertEqual(store.links[0].displayTitle, "Мастер и Маргарита — Яндекс Книги")
        store.rename(id: id, to: "  Моя книга ")
        XCTAssertEqual(store.links[0].displayTitle, "Моя книга")
        store.rename(id: id, to: "   ")
        XCTAssertEqual(store.links[0].displayTitle, "Мастер и Маргарита — Яндекс Книги")
    }

    func testReAddingKeepsCustomName() {
        let id = store.add(book)
        store.rename(id: id, to: "Моя книга")
        store.add(news)
        XCTAssertEqual(store.add(book), id)
        XCTAssertEqual(store.links.first?.displayTitle, "Моя книга")
    }

    func testRemoveAndRemoveAll() {
        let id = store.add(book); store.add(news)
        store.remove(id: id)
        XCTAssertEqual(store.links.map(\.url), [news])
        store.removeAll()
        XCTAssertTrue(store.links.isEmpty)
    }

    func testLinksWithoutPageTitleNeedInfo() {
        let id = store.add(book); store.add(news)
        store.setPageInfo(id: id, title: "Книга", icon: nil)
        XCTAssertEqual(store.linksNeedingPageInfo.map(\.url), [news])
    }
}

final class PageInfoTests: XCTestCase {
    func testPrefersOpenGraphTitle() {
        let html = #"<html><head><title>Яндекс Книги</title><meta property="og:title" content="Мастер и Маргарита"></head></html>"#
        XCTAssertEqual(PageInfo.title(fromHTML: html), "Мастер и Маргарита")
    }

    func testFallsBackToTitleTagAndDecodesEntities() {
        let html = "<head><TITLE>\n  Tom &amp; Jerry &#8212; &quot;серия&quot;  </TITLE></head>"
        XCTAssertEqual(PageInfo.title(fromHTML: html), "Tom & Jerry — \"серия\"")
    }

    func testNoTitle() {
        XCTAssertNil(PageInfo.title(fromHTML: "<html><head></head></html>"))
        XCTAssertNil(PageInfo.title(fromHTML: "<title>   </title>"))
    }

    func testIconFromLinkTagResolvedAgainstPage() {
        let base = URL(string: "https://books.yandex.ru/books/abc")!
        let html = #"<link rel="stylesheet" href="/a.css"><link rel="icon" type="image/png" href="/favicon-32.png">"#
        XCTAssertEqual(PageInfo.iconURL(fromHTML: html, page: base), URL(string: "https://books.yandex.ru/favicon-32.png"))
    }

    func testIconDefaultsToFaviconIco() {
        let base = URL(string: "https://example.com/news/1")!
        XCTAssertEqual(PageInfo.iconURL(fromHTML: "<html></html>", page: base), URL(string: "https://example.com/favicon.ico"))
    }
}
