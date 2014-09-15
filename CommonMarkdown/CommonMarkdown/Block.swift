//
//  Block.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/8/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

public class Block {
    var tag:String
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
    
    init(tag:String, startLine:Int, startColumn:Int) {
        self.tag = tag
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = startLine
    }
    
    // TODO: Messy duck type stuff that should be fixed with subclasses maybe.
    var fenceOffset:Int!
    var fenceLength:Int!
    var fenceCharacter:Character!
    var listData:ListData!
    var level:Int!
    var info:String!
    var tight:Bool!
}

extension Block {

    func highestBlockWithTag(tag:String) -> Block? {
        return self.parent?.highestBlockWithTag(tag) ?? ( self.tag == tag ? self : nil)
    }
    
    var endsWithBlankLine:Bool {
        if lastLineBlank {
            return true
        }
        
        if (tag == "List" || tag == "ListItem") && children.count > 0 {
            return children.last!.endsWithBlankLine
        } else {
            return false
        }
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