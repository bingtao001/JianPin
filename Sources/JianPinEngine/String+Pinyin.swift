//
//  String+Pinyin.swift
//  JianPin
//

import Foundation

extension String {

    /// 首字母大写
    public func upcaseInitial() -> String {
        guard let firstChar = first else { return "" }
        return String(firstChar).uppercased() + dropFirst()
    }

    /// 将中文转换为拼音（去掉声调、首字母大写后拼接）
    /// 非中文字符保持原样
    public func phonetic() -> String {
        let src = NSMutableString(string: self) as CFMutableString

        // Step 1: 中文 → 带声调拼音 (如 "你好" → "nǐ hǎo")
        CFStringTransform(src, nil, kCFStringTransformMandarinLatin, false)

        // Step 2: 去掉声调 (如 "nǐ hǎo" → "ni hao")
        CFStringTransform(src, nil, kCFStringTransformStripCombiningMarks, false)

        let result = src as String
        guard result != self else {
            // 没有变化，说明没有中文，直接返回原文
            return self
        }

        // 分隔、首字母大写、拼接
        return result
            .components(separatedBy: " ")
            .map { $0.upcaseInitial() }
            .reduce("", +)
    }

    /// 获取姓氏拼音（优先使用特殊姓氏词典）
    public func phoneticSurname() -> String {
        if let special = lookupSpecialSurname(self) {
            return special
        }
        return phonetic()
    }

    /// 判断字符串是否包含中文字符
    public var containsChinese: Bool {
        return unicodeScalars.contains { $0.properties.isIdeographic }
    }
}