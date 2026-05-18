//
//  PinyinEngineTests.swift
//  JianPinTests
//

import XCTest
@testable import JianPinEngine

final class PinyinEngineTests: XCTestCase {

    // MARK: - 基本拼音转换

    func testSimpleChinese() {
        XCTAssertEqual("张三".phonetic(), "ZhangSan")
        XCTAssertEqual("王小明".phonetic(), "WangXiaoMing")
        XCTAssertEqual("李".phonetic(), "Li")
    }

    func testMultipleCharName() {
        XCTAssertEqual("欧阳修".phonetic(), "OuYangXiu")
        XCTAssertEqual("司马光".phonetic(), "SiMaGuang")
    }

    // MARK: - 特殊多音字姓氏

    func testSpecialSurnameZeng() {
        XCTAssertEqual("曾".phoneticSurname(), "Zeng")
        XCTAssertNotEqual("曾".phoneticSurname(), "Ceng")
    }

    func testSpecialSurnameXie() {
        XCTAssertEqual("解".phoneticSurname(), "Xie")
        XCTAssertNotEqual("解".phoneticSurname(), "Jie")
    }

    func testSpecialSurnameChan() {
        XCTAssertEqual("单".phoneticSurname(), "Chan")
        XCTAssertNotEqual("单".phoneticSurname(), "Dan")
    }

    func testSpecialSurnameQiu() {
        XCTAssertEqual("仇".phoneticSurname(), "Qiu")
        XCTAssertNotEqual("仇".phoneticSurname(), "Chou")
    }

    func testSpecialSurnameOu() {
        XCTAssertEqual("区".phoneticSurname(), "Ou")
        XCTAssertNotEqual("区".phoneticSurname(), "Qu")
    }

    func testSpecialSurnameZha() {
        XCTAssertEqual("查".phoneticSurname(), "Zha")
        XCTAssertNotEqual("查".phoneticSurname(), "Cha")
    }

    func testSpecialSurnameGe() {
        XCTAssertEqual("盖".phoneticSurname(), "Ge")
        XCTAssertNotEqual("盖".phoneticSurname(), "Gai")
    }

    func testSpecialSurnameZhai() {
        XCTAssertEqual("翟".phoneticSurname(), "Zhai")
        XCTAssertNotEqual("翟".phoneticSurname(), "Di")
    }

    func testSpecialSurnamePiao() {
        XCTAssertEqual("朴".phoneticSurname(), "Piao")
        XCTAssertNotEqual("朴".phoneticSurname(), "Pu")
    }

    // MARK: - 复姓

    func testCompoundSurnameYuchi() {
        XCTAssertEqual("尉迟".phoneticSurname(), "Yuchi")
        XCTAssertNotEqual("尉迟".phoneticSurname(), "WeiChi")
    }

    func testCompoundSurnameMoqi() {
        XCTAssertEqual("万俟".phoneticSurname(), "Moqi")
    }

    func testCompoundSurnameChanyu() {
        XCTAssertEqual("单于".phoneticSurname(), "Chanyu")
    }

    // MARK: - 非中文名

    func testEnglishName() {
        XCTAssertEqual("John".phonetic(), "John")
        XCTAssertEqual("Robert".phonetic(), "Robert")
    }

    func testEmptyString() {
        XCTAssertEqual("".phonetic(), "")
        XCTAssertEqual("".phoneticSurname(), "")
    }

    // MARK: - 含中文判断

    func testContainsChinese() {
        XCTAssertTrue("张三".containsChinese)
        XCTAssertTrue("张".containsChinese)
        XCTAssertTrue("abc张".containsChinese)
        XCTAssertFalse("John".containsChinese)
        XCTAssertFalse("123".containsChinese)
        XCTAssertFalse("".containsChinese)
    }

    // MARK: - 完整姓名转换

    func testFullNameConversion() {
        let familyName = "曾".phoneticSurname()
        let givenName = "小贤".phonetic()
        XCTAssertEqual(familyName + givenName, "ZengXiaoXian")
    }

    func testFullNameWithSpecialSurname() {
        let familyName = "尉迟".phoneticSurname()
        let givenName = "恭".phonetic()
        XCTAssertEqual(familyName + givenName, "YuchiGong")
    }

    func testEnglishContact() {
        // 英文名不应被转换
        let familyName = "Smith".phoneticSurname()
        let givenName = "John".phonetic()
        XCTAssertEqual(familyName + givenName, "SmithJohn")
    }

    // MARK: - upcaseInitial

    func testUpcaseInitial() {
        XCTAssertEqual("hello".upcaseInitial(), "Hello")
        XCTAssertEqual("h".upcaseInitial(), "H")
        XCTAssertEqual("".upcaseInitial(), "")
    }

    // MARK: - SpecialSurnames 字典完整性

    func testAllSpecialSurnamesAreValid() {
        for (surname, pinyin) in SPECIAL_SURNAMES {
            XCTAssertFalse(surname.isEmpty, "姓氏 key 不应为空")
            XCTAssertFalse(pinyin.isEmpty, "拼音 value 不应为空")
            // 拼音应为小写
            XCTAssertEqual(pinyin, pinyin.lowercased(), "拼音应小写: \(pinyin)")
        }
    }

    func testDictionaryDoesNotContainShen() {
        // 沉 不应出现在词典中（非标准姓氏）
        XCTAssertNil(SPECIAL_SURNAMES["沉"], "沉不是姓氏，不应在字典中")
    }
}