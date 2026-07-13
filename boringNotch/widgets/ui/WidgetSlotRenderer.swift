//
//  WidgetSlotRenderer.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

enum WidgetSlotRenderer {
    static func resolvedString(
        forSlotNamed name: String,
        in slots: [String: WidgetValue],
        value: WidgetValue?,
        fallback: String
    ) -> String {
        guard let slotValue = slots[name] else { return fallback }

        switch slotValue {
        case .string(let template):
            return resolveText(template, value: value)
        default:
            return displayString(for: slotValue)
        }
    }

    static func resolveText(_ template: String, value: WidgetValue?) -> String {
        template.replacingOccurrences(of: "$value", with: value.map(displayString(for:)) ?? "—")
    }

    static func displayString(for value: WidgetValue) -> String {
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .double(let double):
            return String(double)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .list(let list):
            return list.map(displayString(for:)).joined(separator: ", ")
        case .object(let object):
            guard JSONSerialization.isValidJSONObject(object.mapValues(jsonObject(for:))) else {
                return "{}"
            }

            let dictionary = object.mapValues(jsonObject(for:))

            guard
                let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
                let string = String(data: data, encoding: .utf8)
            else {
                return "{}"
            }

            return string
        case .null:
            return "null"
        }
    }

    static func numericValue(from value: WidgetValue?) -> Double? {
        guard let value else { return nil }

        switch value {
        case .integer(let integer):
            return Double(integer)
        case .double(let double):
            return double
        case .string(let string):
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func jsonObject(for value: WidgetValue) -> Any {
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return integer
        case .double(let double):
            return double
        case .bool(let bool):
            return bool
        case .list(let list):
            return list.map(jsonObject(for:))
        case .object(let object):
            return object.mapValues(jsonObject(for:))
        case .null:
            return NSNull()
        }
    }
}
