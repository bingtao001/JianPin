//
//  SpecialSurnames.swift
//  JianPin
//
//  多音字姓氏词典：CFStringTransform 无法正确识别的姓氏
//  优先使用此词典，未命中则回退 CFStringTransform
//

import Foundation

/// 多音字/特殊读音姓氏词典
/// key: 姓氏原文, value: 拼音（小写）
public let SPECIAL_SURNAMES: [String: String] = [
    // 常见多音字姓氏
    "柏": "bai",
    "鲍": "bao",
    "贲": "ben",
    "秘": "bi",
    "薄": "bo",
    "卜": "bu",
    "岑": "cen",
    "晁": "chao",
    "谌": "chen",
    "种": "chong",
    "褚": "chu",
    "啜": "chuai",
    "单": "chan",
    "郗": "chi",
    "邸": "di",
    "都": "du",
    "缪": "miao",
    "宓": "mi",
    "费": "fei",
    "苻": "fu",
    "睢": "sui",
    "区": "ou",
    "华": "hua",
    "庞": "pang",
    "朴": "piao",
    "查": "zha",
    "佘": "she",
    "仇": "qiu",
    "靳": "jin",
    "解": "xie",
    "繁": "po",
    "折": "she",
    "员": "yun",
    "祭": "zhai",
    "芮": "rui",
    "覃": "tan",
    "牟": "mou",
    "蕃": "pi",
    "戚": "qi",
    "瞿": "qu",
    "冼": "xian",
    "洗": "xian",
    "郤": "xi",
    "庹": "tuo",
    "彤": "tong",
    "佟": "tong",
    "妫": "gui",
    "句": "gou",
    "郝": "hao",
    "曾": "zeng",
    "乐": "yue",
    "蔺": "lin",
    "隽": "juan",
    "臧": "zang",
    "庾": "yu",
    "詹": "zhan",
    "禚": "zhuo",
    "盖": "ge",
    "翟": "zhai",
    "迮": "ze",
    "沈": "shen",

    // 复姓
    "尉迟": "yuchi",
    "长孙": "zhangsun",
    "中行": "zhonghang",
    "万俟": "moqi",
    "单于": "chanyu",
]

/// 从特殊姓氏词典查询拼音
/// - Parameter surname: 姓氏
/// - Returns: 拼音（首字母大写），未命中返回 nil
public func lookupSpecialSurname(_ surname: String) -> String? {
    guard let pinyin = SPECIAL_SURNAMES[surname] else {
        return nil
    }
    return pinyin.upcaseInitial()
}