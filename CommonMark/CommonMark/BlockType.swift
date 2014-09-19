//
//  BlockType.swift
//  CommonMark
//
//  Created by Brian Nickel on 9/18/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

enum BlockType {
    case Document
    case List(data:ListData, tight:Bool)
    case ListItem(ListData)
    case Paragraph
    case BlockQuote
    case ATXHeader(Int)
    case SetextHeader(Int)
    case IndentedCode
    case FencedCode(offset:Int, length:Int, character:Character, info:String)
    case HtmlBlock
    case ReferenceDef
    case HorizontalRule
}

extension BlockType : Printable {
    
    var description:String {
        
        switch self {
        case .Document: return "Document"
        case .List(let data, let tight):
            switch data.type {
            case .Bullet(let character): return "List(type:bullet, tight:\(tight), character:\(character)"
            case .Ordered(let start, _): return "List(type:ordered, tight:\(tight), start:\(start)"
            }
            
        case .ListItem: return "ListItem"
        case .Paragraph: return "Paragraph"
        case .BlockQuote: return "BlockQuote"
        case .ATXHeader(let level): return "ATXHeader(level:\(level))"
        case .SetextHeader(let level): return "SetextHeader(level:\(level))"
        case .IndentedCode: return "IndentedCode"
        case .FencedCode(_, let length, _, let info): return ("FencedCode(length:\(length), info:\(info))")
        case .HtmlBlock: return "HtmlBlock"
        case .ReferenceDef: return "ReferenceDef"
        case .HorizontalRule: return "HorizontalRule"
        }
    }
}

extension BlockType {
    
    // Returns true if parent block can contain child block.
    func canContain(childType:BlockType) -> Bool {
        switch self {
        case .Document: return true
        case .BlockQuote: return true
        case .ListItem: return true
        case .List:
            switch childType {
            case .ListItem: return true
            default: return false
            }
        default: return false
        }
    }
    
    // Returns true if block type can accept lines of text.
    var acceptsLines:Bool {
        switch self {
        case .Paragraph: fallthrough
        case .IndentedCode: fallthrough
        case .FencedCode: return true
        default: return false
        }
    }
    
    var containsPlainText:Bool {
        switch self {
        case .FencedCode: fallthrough
        case .IndentedCode: fallthrough
        case .HtmlBlock: return true
        default: return false
        }
    }
    
    func isListOfType(type:ListType) -> Bool {
        switch self {
        case .List(let data, _): return data.type == type
        default: return false
        }
    }
}