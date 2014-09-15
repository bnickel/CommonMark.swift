//
//  InlineParser.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/12/14.
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


class InlineParser {
    
    var refmap = [String: Link]()
    
    func parseReference(inout possibleReference:String) -> Bool {
        return false
    }
    
    func parse(var subject:String) -> [Inline] {
        var inlines = [Inline]()
        while parseInline(&subject, inlines: &inlines) {}
        return inlines
    }
    
    func parseInline(inout string:String, inout inlines:[Inline]) -> Bool {
        
        if string.isEmpty {
            return false
        }
        
        var result:Bool = false
        
        switch string[string.startIndex] {
        case "\n": result = parseNewline(&string, inlines: &inlines)
        case "\\": result = parseEscaped(&string, inlines: &inlines)
        case "`":  result = parseBackticks(&string, inlines: &inlines)
        case "*":  fallthrough
        case "_":  result = parseEmphasis(&string, inlines: &inlines)
        case "[":  result = parseLink(&string, inlines: &inlines)
        case "!":  result = parseImage(&string, inlines: &inlines)
        case "<":  result = parseAutolink(&string, inlines: &inlines) || parseHTMLTag(&string, inlines: &inlines)
        case "&":  result = parseEntity(&string, inlines: &inlines)
        default: break
        }
        
        return result || parseString(&string, inlines: &inlines)
        
    }
    
    // Parse a newline.  If it was preceded by two spaces, return a hard
    // line break; otherwise a soft line break.
    func parseNewline(inout string:String, inout inlines:[Inline]) -> Bool {
        
        if !string.hasPrefix("\n") {
            return false
        }
        
        string.removeAtIndex(string.startIndex)
        
        if let last = inlines.last {
            switch last {
            case .Str(var text):
                
                if let endingWhitespace = text.rangeOfFirstMatch(regex(" +$")) {
                    text.removeRange(endingWhitespace)
                    inlines.removeLast()
                    inlines.append(.Str(text))
                    
                    if distance(endingWhitespace.startIndex, text.endIndex) >= 2 {
                        inlines.append(.Hardbreak)
                        return true
                    }
                }
                
            default:
                break
            }
        }
        
        inlines.append(.Softbreak)
        return true
    }
    
    func parseEscaped(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseBackticks(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseEmphasis(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseLink(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseImage(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseAutolink(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseHTMLTag(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseEntity(inout string:String, inout inlines:[Inline]) -> Bool {
        return false
    }
    
    func parseString(inout string:String, inout inlines:[Inline]) -> Bool {
        if let text = match(&string, regularExpression: reMain) {
            inlines.append(.Str(text))
            return true
        } else {
            return false
        }
    }
    
    func match (inout string:String, regularExpression:RegularExpression) -> String? {
        if let match = string.firstMatch(regularExpression) {
            string = string.substringFromIndex(match.range.endIndex)
            return match.text
        } else {
            return nil
        }
    }
}