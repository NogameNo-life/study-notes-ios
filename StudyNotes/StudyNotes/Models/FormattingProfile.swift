//
//  FormattingProfile.swift
//  StudyNotes
//

import CoreGraphics

/// A named preset that controls the visual density of a generated PDF.
///
/// Profiles adjust body font size and page margins. Heading sizes always scale
/// relative to the body size, so a "Lecture" profile makes all text proportionally
/// larger while keeping the visual hierarchy intact.
nonisolated enum FormattingProfile: String, CaseIterable, Identifiable, Sendable {
    case standard = "Standard"
    case lecture  = "Lecture"
    case compact  = "Compact"

    var id: String { rawValue }
    var name: String { rawValue }

    var bodyFontSize: CGFloat {
        switch self {
        case .standard: return 12
        case .lecture:  return 14
        case .compact:  return 10
        }
    }

    var margin: CGFloat {
        switch self {
        case .standard: return 50
        case .lecture:  return 40
        case .compact:  return 35
        }
    }

    var description: String {
        switch self {
        case .standard: return "12 pt · 50 pt margin"
        case .lecture:  return "14 pt · 40 pt margin"
        case .compact:  return "10 pt · 35 pt margin"
        }
    }
}
