//
//  Inline.swift
//  CommonMark
//
//  Created by Brian Nickel on 9/18/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

enum Inline {
    case Entity(String)
    case Str(String)
    case HTML(String)
    case Code(String)
    case Hardbreak
    case Softbreak
    case Emphasis([Inline])
    case Strong([Inline])
    case Link(destination:String, title:String, label:[Inline])
    case Image(destination:String, title:String, label:[Inline])
}

extension Inline : Printable {
    
    var description:String {
        
        func escape(var s:String) -> String {
            s.replaceAll(regex("\n"), withTemplate: "\\n")
            return s
        }
        
        func indentedInlines(i:[Inline]) -> String {
            return join("\n", map(i, { join("\n", map(split($0.description, { $0 == "\n" }), { "  " + $0 })) }))
        }
        
        switch self {
        case .Entity(let string): return "Entity(\(string))"
        case .Str(let string): return "Str(\(escape(string)))"
        case .HTML(let string): return "HTML(\(escape(string)))"
        case .Code(let string): return "Code(\(escape(string)))"
        case .Hardbreak: return "Hardbreak"
        case .Softbreak: return "Softbreak"
        case Emphasis(let inlines): return "Emphasis:\n\(indentedInlines(inlines))"
        case Strong(let inlines): return "Strong:\n\(indentedInlines(inlines))"
        case Link(let destination, let title, let inlines): return "Link(destination:\(destination), title:\(title):\n\(indentedInlines(inlines))"
        case Image(let destination, let title, let inlines): return "Image(destination:\(destination), title:\(title):\n\(indentedInlines(inlines))"
        }
    }
}