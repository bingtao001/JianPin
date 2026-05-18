//
//  ContactProcessor.swift
//  JianPin
//

import Combine
import Contacts
import Foundation

/// 单个联系人处理结果
public struct ContactResult: Identifiable, CustomStringConvertible {
    public let id = UUID()
    public let givenName: String
    public let familyName: String
    public let phoneticGiven: String
    public let phoneticFamily: String
    public let status: Status

    public enum Status {
        case updated
        case skipped
        case failed(reason: String)
    }

    public var description: String {
        let fullName = "\(familyName)\(givenName)".trimmingCharacters(in: .whitespaces)
        switch status {
        case .updated:
            return "\(fullName) → \(phoneticFamily)\(phoneticGiven)"
        case .skipped:
            return "\(fullName) ⏭ 已跳过"
        case .failed(let reason):
            return "\(fullName) ❌ \(reason)"
        }
    }

    public init(
        givenName: String,
        familyName: String,
        phoneticGiven: String,
        phoneticFamily: String,
        status: Status
    ) {
        self.givenName = givenName
        self.familyName = familyName
        self.phoneticGiven = phoneticGiven
        self.phoneticFamily = phoneticFamily
        self.status = status
    }
}

/// 处理进度
public struct ProcessProgress {
    public let processed: Int
    public let total: Int
    public let current: ContactResult?

    public var fractionCompleted: Double {
        guard total > 0 else { return 1.0 }
        return min(Double(processed) / Double(total), 1.0)
    }

    public init(processed: Int, total: Int, current: ContactResult?) {
        self.processed = processed
        self.total = total
        self.current = current
    }
}

/// 联系人处理引擎
public final class ContactProcessor: ObservableObject {

    // MARK: - 状态枚举

    public enum State: Equatable {
        case idle
        case requestingPermission
        case denied
        case processing
        case paused
        case completed(ProcessResult)
        case error(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                (.requestingPermission, .requestingPermission),
                (.denied, .denied),
                (.processing, .processing),
                (.paused, .paused):
                return true
            case (.completed(let l), .completed(let r)):
                return l == r
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    public struct ProcessResult: Equatable {
        public let updated: Int
        public let skipped: Int
        public let failed: [(name: String, reason: String)]
        public let total: Int

        public init(updated: Int, skipped: Int, failed: [(name: String, reason: String)], total: Int) {
            self.updated = updated
            self.skipped = skipped
            self.failed = failed
            self.total = total
        }

        public static func == (lhs: ProcessResult, rhs: ProcessResult) -> Bool {
            lhs.updated == rhs.updated &&
            lhs.skipped == rhs.skipped &&
            lhs.total == rhs.total &&
            lhs.failed.count == rhs.failed.count
        }
    }

    // MARK: - Published

    @Published public private(set) var state: State = .idle
    @Published public private(set) var progress: ProcessProgress = .init(processed: 0, total: 0, current: nil)

    // MARK: - Private

    private let store = CNContactStore()
    private lazy var keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneticGivenNameKey as CNKeyDescriptor,
        CNContactPhoneticFamilyNameKey as CNKeyDescriptor,
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
    ]

    private var isPaused = false
    private var backup: [String: ContactBackup] = [:]
    private var cachedContacts: [CNContact]?
    @Published public private(set) var duplicateGroups: [DuplicateGroup] = []

    // MARK: - Public

    public init() {}

    /// 请求通讯录权限
    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// 开始处理
    public func start() async {
        guard state != .processing else { return }

        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .notDetermined:
            await MainActor.run { state = .requestingPermission }
            let granted = await requestPermission()
            guard granted else {
                await MainActor.run { state = .denied }
                return
            }
        case .denied, .restricted:
            await MainActor.run { state = .denied }
            return
        case .authorized:
            break
        @unknown default:
            await MainActor.run { state = .error("未知授权状态") }
            return
        }

        await MainActor.run {
            state = .processing
            isPaused = false
            backup = [:]
        }

        await processContacts()
    }

    /// 暂停
    public func pause() {
        isPaused = true
        state = .paused
    }

    /// 继续
    public func resume() async {
        isPaused = false
        state = .processing
        await processContacts()
    }

    /// 撤销
    public func undo() async -> (restored: Int, failed: Int) {
        let count = backup.count
        guard count > 0 else { return (0, 0) }

        let identifiers = Array(backup.keys)
        let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)

        do {
            let fetched = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            let saveRequest = CNSaveRequest()

            for contact in fetched {
                guard let data = backup[contact.identifier] else { continue }
                let mutable = contact.mutableCopy() as! CNMutableContact
                mutable.givenName = data.givenName
                mutable.familyName = data.familyName
                mutable.organizationName = data.organizationName
                mutable.phoneticGivenName = data.phoneticGiven
                mutable.phoneticFamilyName = data.phoneticFamily
                saveRequest.update(mutable)
            }

            try store.execute(saveRequest)
        } catch {
            return (0, count)
        }

        await MainActor.run {
            backup = [:]
            state = .idle
            progress = ProcessProgress(processed: 0, total: 0, current: nil)
        }

        return (count, 0)
    }

    /// 查找重复联系人
    public func findDuplicates() async {
        let contacts: [CNContact]

        if let cached = cachedContacts {
            contacts = cached
        } else {
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var all: [CNContact] = []
            do {
                try store.enumerateContacts(with: request) { c, _ in all.append(c) }
            } catch { return }
            cachedContacts = all
            contacts = all
        }

        var groups: [String: [CNContact]] = [:]
        for c in contacts {
            let key = "\(c.familyName)\(c.givenName)".trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(c)
        }

        let dupGroups = groups
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(name: $0.key, contacts: $0.value.map(DuplicateContact.init)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        await MainActor.run { duplicateGroups = dupGroups }
    }

    /// 合并指定重复联系人组
    /// 保留第一个联系人，合并其他联系人的电话和邮箱，然后删除被合并的
    public func mergeGroup(_ group: DuplicateGroup) async -> Bool {
        guard group.canMerge,
              let fullContacts = cachedContacts else { return false }

        let contacts = fullContacts.filter { c in
            let key = "\(c.familyName)\(c.givenName)".trimmingCharacters(in: .whitespaces)
            return key == group.name
        }
        guard contacts.count > 1,
              let primary = contacts.first?.mutableCopy() as? CNMutableContact else { return false }

        let toMerge = Array(contacts.dropFirst())
        var mergedPhones = Set(primary.phoneNumbers.map { $0.value.stringValue })
        var mergedEmails = Set(primary.emailAddresses.map { $0.value as String })

        for contact in toMerge {
            for phone in contact.phoneNumbers {
                if !mergedPhones.contains(phone.value.stringValue) {
                    primary.phoneNumbers.append(phone)
                    mergedPhones.insert(phone.value.stringValue)
                }
            }
            for email in contact.emailAddresses {
                let val = email.value as String
                if !mergedEmails.contains(val) {
                    primary.emailAddresses.append(email)
                    mergedEmails.insert(val)
                }
            }
        }

        let saveRequest = CNSaveRequest()
        saveRequest.update(primary)
        for contact in toMerge {
            saveRequest.delete(contact.mutableCopy() as! CNMutableContact)
        }

        do {
            try store.execute(saveRequest)
            return true
        } catch {
            return false
        }
    }

    /// 一键合并所有重复联系人
    public func mergeAllDuplicates() async -> (merged: Int, failed: Int) {
        let groups = duplicateGroups
        guard let allContacts = cachedContacts else { return (0, 0) }

        let saveRequest = CNSaveRequest()
        var mergedCount = 0

        for group in groups {
            guard group.canMerge else { continue }

            let matched = allContacts.filter { c in
                let key = "\(c.familyName)\(c.givenName)".trimmingCharacters(in: .whitespaces)
                return key == group.name
            }
            guard matched.count > 1,
                  let primary = matched.first?.mutableCopy() as? CNMutableContact else {
                continue
            }

            let toMerge = matched.dropFirst()
            var phoneSet = Set(primary.phoneNumbers.map { $0.value.stringValue })
            var emailSet = Set(primary.emailAddresses.map { $0.value as String })

            for contact in toMerge {
                for phone in contact.phoneNumbers where !phoneSet.contains(phone.value.stringValue) {
                    primary.phoneNumbers.append(phone)
                    phoneSet.insert(phone.value.stringValue)
                }
                for email in contact.emailAddresses {
                    let val = email.value as String
                    if !emailSet.contains(val) {
                        primary.emailAddresses.append(email)
                        emailSet.insert(val)
                    }
                }
            }

            saveRequest.update(primary)
            for contact in toMerge {
                saveRequest.delete(contact.mutableCopy() as! CNMutableContact)
            }
            mergedCount += 1
        }

        do {
            try store.execute(saveRequest)
        } catch {
            return (0, groups.count)
        }

        cachedContacts = nil
        await MainActor.run { duplicateGroups = [] }
        return (mergedCount, groups.count - mergedCount)
    }

    /// 重置
    public func reset() {
        state = .idle
        progress = ProcessProgress(processed: 0, total: 0, current: nil)
        isPaused = false
        cachedContacts = nil
    }

    // MARK: - Private

    private func processContacts() async {
        let allContacts: [CNContact]

        if let cached = cachedContacts {
            allContacts = cached
        } else {
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var contacts: [CNContact] = []
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    contacts.append(contact)
                }
            } catch {
                await MainActor.run { state = .error("读取通讯录失败: \(error.localizedDescription)") }
                return
            }
            cachedContacts = contacts
            allContacts = contacts
        }

        guard !allContacts.isEmpty else {
            let result = ProcessResult(updated: 0, skipped: 0, failed: [], total: 0)
            await MainActor.run { state = .completed(result) }
            return
        }

        let total = allContacts.count
        var updated = 0
        var skipped = 0
        var failures: [(name: String, reason: String)] = []
        let batchSize = 10
        var batch: [CNMutableContact] = []

        for (_, contact) in allContacts.enumerated() {
            if isPaused { return }

            // 判断是否需要处理
            let hasPhonetic = !(contact.phoneticGivenName.isEmpty && contact.phoneticFamilyName.isEmpty)
            let hasName = contact.givenName.containsChinese || contact.familyName.containsChinese
            let hasOrg = !hasName && contact.organizationName.containsChinese
            let needsProcess = hasName || hasOrg

            guard needsProcess, !hasPhonetic else {
                skipped += 1
                let result = ContactResult(
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    phoneticGiven: contact.phoneticGivenName,
                    phoneticFamily: contact.phoneticFamilyName,
                    status: .skipped
                )
                await publishProgress(processed: updated + skipped, total: total, current: result)
                continue
            }

            // 转换拼音
            let phoneticFamily: String
            let phoneticGiven: String
            if hasName {
                phoneticFamily = contact.familyName.phoneticSurname()
                phoneticGiven = contact.givenName.phonetic()
            } else {
                phoneticFamily = contact.organizationName.phonetic()
                phoneticGiven = ""
            }

            // 备份原始数据
            if backup[contact.identifier] == nil {
                backup[contact.identifier] = ContactBackup(
                    identifier: contact.identifier,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    organizationName: contact.organizationName,
                    phoneticGiven: contact.phoneticGivenName,
                    phoneticFamily: contact.phoneticFamilyName
                )
            }

            let mutable = contact.mutableCopy() as! CNMutableContact
            mutable.phoneticFamilyName = phoneticFamily
            mutable.phoneticGivenName = phoneticGiven
            batch.append(mutable)

            let result = ContactResult(
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneticGiven: phoneticGiven,
                phoneticFamily: phoneticFamily,
                status: .updated
            )
            await publishProgress(processed: updated + skipped + batch.count, total: total, current: result)

            // 批量保存
            if batch.count >= batchSize {
                do {
                    try saveBatch(batch)
                    updated += batch.count
                    batch.removeAll(keepingCapacity: true)
                } catch {
                    failures.append(("批量写入失败", error.localizedDescription))
                    updated += batch.count
                    batch.removeAll(keepingCapacity: true)
                }
            }
        }

        // 保存剩余
        if !batch.isEmpty {
            do {
                try saveBatch(batch)
                updated += batch.count
            } catch {
                failures.append(("批量写入失败", error.localizedDescription))
                updated += batch.count
            }
        }

        let result = ProcessResult(
            updated: updated,
            skipped: skipped,
            failed: failures,
            total: total
        )
        await MainActor.run { state = .completed(result) }
    }

    private func saveBatch(_ batch: [CNMutableContact]) throws {
        let request = CNSaveRequest()
        for contact in batch {
            request.update(contact)
        }
        try store.execute(request)
    }

    @MainActor
    private func publishProgress(processed: Int, total: Int, current: ContactResult) {
        progress = ProcessProgress(processed: processed, total: total, current: current)
    }
}

// MARK: - 重复联系人

public struct DuplicateGroup: Identifiable {
    public let id = UUID()
    public let name: String
    public let contacts: [DuplicateContact]
    public let canMerge: Bool

    public var count: Int { contacts.count }

    public init(name: String, contacts: [DuplicateContact]) {
        self.name = name
        self.contacts = contacts
        self.canMerge = contacts.count > 1
    }
}

public struct DuplicateContact: Identifiable {
    public let id: String
    public let givenName: String
    public let familyName: String
    public let phoneNumbers: [String]
    public let emailAddresses: [String]
    public let organizationName: String

    public var fullName: String { "\(familyName)\(givenName)" }

    public init(contact: CNContact) {
        self.id = contact.identifier
        self.givenName = contact.givenName
        self.familyName = contact.familyName
        self.phoneNumbers = contact.phoneNumbers.map {
            $0.value.stringValue
        }
        self.emailAddresses = contact.emailAddresses.map {
            $0.value as String
        }
        self.organizationName = contact.organizationName
    }
}

// MARK: - Backup

public struct ContactBackup {
    public let identifier: String
    public let givenName: String
    public let familyName: String
    public let organizationName: String
    public let phoneticGiven: String
    public let phoneticFamily: String

    public init(
        identifier: String,
        givenName: String,
        familyName: String,
        organizationName: String,
        phoneticGiven: String,
        phoneticFamily: String
    ) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.organizationName = organizationName
        self.phoneticGiven = phoneticGiven
        self.phoneticFamily = phoneticFamily
    }
}