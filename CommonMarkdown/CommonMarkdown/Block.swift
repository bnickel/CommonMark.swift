//
//  Block.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/8/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

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
}

extension Block {
    
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
        
        func escape(var s:String) -> String {
            s.replaceAll(regex("\n"), withTemplate: "\\n")
            return s
        }
        
        func indentedLines<T where T:Printable>(line:T) -> String {
            return join("\n", split(line.description, { $0 == "\n" }).map({ "  \($0)"}))
        }
        
        if children.count > 0 {
            
            var description = "\(type) (\(children.count) children)"
            
            for child in children {
                description += "\n" + indentedLines(child)
            }
            
            return description
        }
        
        if inlineContent.count > 0 {
            
            var description = "\(type) (\(inlineContent.count) inlines)"
            
            for inline in inlineContent {
                description += "\n" + indentedLines(inline)
            }
            
            return description
            
        }
        
        return "\(type) \(escape(stringContent))"
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

struct ListData : Equatable {
    let type:ListType
    let markerOffset:Int
    let padding:Int
}

func == (lhs:ListData, rhs:ListData) -> Bool {
    return lhs.type == rhs.type && lhs.markerOffset == rhs.markerOffset && lhs.padding == rhs.padding
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