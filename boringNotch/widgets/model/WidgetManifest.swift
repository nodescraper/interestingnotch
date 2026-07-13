//
//  WidgetManifest.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

struct WidgetManifest: Codable, Identifiable, Hashable, Sendable {
    let schema: Int
    let kind: Kind
    let id: String
    let name: String
    let author: String?
    let source: Source?
    let extract: Extract?
    let render: Render
    let onTap: DeclaredAction?
    let permissions: [String]?
    let interactive: Interactive?

    init(
        schema: Int,
        kind: Kind,
        id: String,
        name: String,
        author: String?,
        source: Source?,
        extract: Extract?,
        render: Render,
        onTap: DeclaredAction?,
        permissions: [String]?,
        interactive: Interactive? = nil
    ) {
        self.schema = schema
        self.kind = kind
        self.id = id
        self.name = name
        self.author = author
        self.source = source
        self.extract = extract
        self.render = render
        self.onTap = onTap
        self.permissions = permissions
        self.interactive = interactive
    }

    enum Kind: String, Codable, Sendable {
        case data
        case interactive
    }

    struct Source: Codable, Hashable, Sendable {
        let type: ChannelType
        let run: String?
        let url: String?
        let method: String?
        let headers: [String: String]?
        let api: String?
        let interval: TimeInterval
        let timeout: TimeInterval?
        let cwd: String?
        let env: [String: String]?

        enum ChannelType: String, Codable, Sendable {
            case command
            case http
            case framework
        }
    }

    struct Extract: Codable, Hashable, Sendable {
        let method: Method
        let pattern: String?
        let path: String?
        let table: [String: WidgetValue]?

        enum Method: String, Codable, Sendable {
            case raw
            case trim
            case lineCount = "line-count"
            case regex
            case jsonPath = "json-path"
            case firstLine = "first-line"
            case map
        }
    }

    struct Render: Codable, Hashable, Sendable {
        let template: Template
        let slots: [String: WidgetValue]

        enum Template: String, Codable, Sendable {
            case iconLabel = "icon-label"
            case text
            case progress
            case gauge
            case list
            case button
        }
    }

    struct DeclaredAction: Codable, Hashable, Sendable {
        let action: String?
        let type: ActionType?
        let run: String?
        let url: String?
        let copy: String?
        let then: String?

        enum ActionType: String, Codable, Sendable {
            case screenColorPick = "screen-color-pick"
            case copy
            case copyHex = "copy-hex"
            case openURL = "open-url"
            case run
        }
    }

    struct Interactive: Codable, Hashable, Sendable {
        let type: Kind

        enum Kind: String, Codable, Sendable {
            case colorPicker = "color-picker"
        }
    }
}
