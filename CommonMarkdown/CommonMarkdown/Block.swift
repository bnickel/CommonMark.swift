//
//  Block.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/8/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

enum BlockType {
    case Document
    case List
    case ListItem
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
        case .List: return "List"
        case .ListItem: return "ListItem"
        case .Paragraph: return "Paragraph"
        case .BlockQuote: return "BlockQuote"
        case .ATXHeader(let level): return "ATXHeader(level:\(level))"
        case .SetextHeader(let level): return "SetextHeader(level:\(level))"
        case .IndentedCode: return "IndentedCode"
        case .FencedCode(let offset, let length, let character, let info): return ("FencedCode(offset:\(offset), length:\(length), character:\(character), info:\(info))")
        case .HtmlBlock: return "HtmlBlock"
        case .ReferenceDef: return "ReferenceDef"
        case .HorizontalRule: return "HorizontalRule"
        }
    }
}

extension BlockType : Equatable {}

func == (lhs: BlockType, rhs:BlockType) -> Bool {
    
    switch (lhs, rhs) {
    case (.Document, .Document):             return true
    case (.List, .List):                     return true
    case (.ListItem, .ListItem):             return true
    case (.Paragraph, .Paragraph):           return true
    case (.BlockQuote, .BlockQuote):         return true
    case (.ATXHeader(let a), .ATXHeader(let b)): return a == b
    case (.SetextHeader(let a), .SetextHeader(let b)): return a == b
    case (.FencedCode(let a, let b, let c, let d), .FencedCode(let w, let x, let y, let z)): return a == w && b == x && c == y && d == z
    case (.IndentedCode, .IndentedCode):     return true
    case (.HtmlBlock, .HtmlBlock):           return true
    case (.ReferenceDef, .ReferenceDef):     return true
    case (.HorizontalRule, .HorizontalRule): return true
    default:                                 return false
    }
}

func ~= (lhs: BlockType, rhs:BlockType) -> Bool {
    
    switch (lhs, rhs) {
    case (.ATXHeader, .ATXHeader):           return true
    case (.SetextHeader, .SetextHeader):     return true
    case (.FencedCode, .FencedCode):         return true
    default: return lhs == rhs
    }
}

extension BlockType {
    
    // Returns true if parent block can contain child block.
    func canContain(childType:BlockType) -> Bool {
        return contains([.Document, .BlockQuote, .ListItem], self) || (self == .List && childType == .ListItem)
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
}

public class Block {
    var type:BlockType
    let startLine:Int
    let startColumn:Int
    
    var open = true
    var lastLineBlank = false
    var endLine:Int
    var children = [Block]()
    weak var parent:Block? = nil
    var stringContent = ""
    var strings = [String]()
    var inlineContent = [Inline]()
    
    init(type:BlockType, startLine:Int, startColumn:Int) {
        self.type = type
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = startLine
    }
    
    // TODO: Messy duck type stuff that should be fixed with subclasses maybe.
    var listData:ListData!
    var info:String!
    var tight:Bool!
}

extension Block {

    func highestBlockWithType(type:BlockType) -> Block? {
        if let block = parent?.highestBlockWithType(type) {
            return block
        }
        
        return self.type == type ? self : nil
    }
    
    var endsWithBlankLine:Bool {
        if lastLineBlank {
            return true
        }
        
        switch type {
        case .List: fallthrough
        case .ListItem:
            return children.count > 0 && children.last!.endsWithBlankLine
        default:
            return false
        }
    }
    
    func shouldRememberBlankLine(lineNumber:Int) -> Bool {
        switch type {
        case .BlockQuote: return false
        case .FencedCode: return false
        case .ListItem:
            return !(children.count == 0 && startLine == lineNumber)
        default: return true
        }
    }
}

extension Block : Printable {
    
    public var description: String {
        
        if children.count > 0 {
            
            var description = "\(type) (\(children.count) children)\n"
            
            for child in children {
                description += join("\n", split(child.description, { $0 == "\n" }, maxSplit: .max, allowEmptySlices: true).map({ "  \($0)"})) + "\n\n"
            }
            
            return description
        }
        
        if inlineContent.count > 0 {
            
            var description = "\(type) (\(children.count) inlines)\n"
            
            for inline in inlineContent {
                description += "\(inline)\n\n"
            }
            
            return description
            
        }
        
        return "\(type) \(stringContent)"
    }
}

struct Link {
    let destination:String
    let title:String?
}

enum ListType : Equatable {
    case Bullet(Character)
    case Ordered(start:Int, delimiter:Character)
}

func == (lhs:ListType, rhs:ListType) -> Bool {
    
    switch (lhs, rhs) {
    case let (.Bullet(leftChar), .Bullet(rightChar)):
        return leftChar == rightChar
    case let (.Ordered(_, leftChar), .Ordered(_, rightChar)):
        return leftChar == rightChar
    default:
        return false
    }
    
}

struct ListData {
    let type:ListType
    let markerOffset:Int
    let padding:Int
}

func parseListMarker(line:String, offset:String.Index, markerOffset: Int) -> ListData? {
    
    let rest = line.substringFromIndex(offset)
    
    var text:String!
    var spacesAfterMarker = 0
    var type:ListType!
    
    if rest.firstMatch(reHrule) != nil {
        return nil
    }
    
    func firstChar(string:String) -> Character {
        return string[string.startIndex]
    }
    
    if let match = rest.firstMatch(regex("^[*+-]( +|$)")) {
        text = match.text
        spacesAfterMarker = countElements(match[1]!)
        type = .Bullet(firstChar(text))
    } else if let match = rest.firstMatch(regex("^(\\d+)([.)])( +|$)")) {
        text = match.text
        spacesAfterMarker = countElements(match[3]!)
        type = .Ordered(start: match[1]!.toInt()!, delimiter: firstChar(match[2]!))
    } else {
        return nil
    }
    
    let blankItem = countElements(text) == countElements(rest)
    
    let padding = spacesAfterMarker >= 5 || spacesAfterMarker < 1 || blankItem ? countElements(text) - spacesAfterMarker + 1 : countElements(text)
    
    return ListData(type: type, markerOffset: markerOffset, padding: padding)

}