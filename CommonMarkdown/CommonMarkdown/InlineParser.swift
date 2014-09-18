//
//  InlineParser.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/12/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

struct Text {
    let string:String
    var position:String.Index
    
    init(string:String) {
        self.string = string
        position = string.startIndex
    }
    
    func prev() -> Character? {
        return position > string.startIndex ? string[advance(position, -1)] : nil
    }
    
    func peek() -> Character? {
        return position < string.endIndex ? string[position] : nil
    }
    
    func prev(count:Int) -> String {
        let newPosition = advance(position, -count, string.startIndex)
        return string.substringWithRange(newPosition..<position)
    }
    
    mutating func read(count:Int) -> String {
        let newPosition = advance(position, count)
        let text = string.substringWithRange(position..<newPosition)
        position = newPosition
        return text
    }
    
    mutating func skip(count:Int) {
        position = advance(position, count)
    }
    
    func startsWithAny(chars:Character...) -> Bool {
        if let char = peek() {
            return contains(chars, char)
        } else {
            return false
        }
    }
    
    mutating func match(expr:RegularExpression) -> String? {
        let substring = string.substringFromIndex(position)
        if let match = substring.firstMatch(expr) {
            position = advance(position, distance(substring.startIndex, match.range.endIndex))
            return match.text
        } else {
            return nil
        }
    }
    
    mutating func spln() {
        match(regex("^ *(?:\n *)?"))
    }
    
    var isEmpty:Bool {
        return position == string.endIndex
    }
    
    func since(other:Text) -> String {
        return string.substringWithRange(other.position ..< position)
    }
    
    var stringValue: String {
        return string.substringFromIndex(position)
    }
}


class InlineParser {
    
    var refmap = [String: Link]()
    var labelNestLevel = 0
    
    // Attempt to parse a link reference, modifying refmap.
    func parseReference(inout possibleReference:String) -> Bool {
        
        var text = Text(string: possibleReference)
        
        if let rawLabel = parseLinkLabel(&text) {
            
            if text.startsWithAny(":") {
                text.skip(1)
                text.spln()
                
                if let destination = parseLinkDestination(&text) {
                    
                    if !destination.isEmpty {
                    
                        let beforeTitle = text
                        
                        text.spln()
                        let title = parseLinkTitle(&text)
                        
                        if title == nil {
                            text = beforeTitle
                        }
                        
                        // make sure we're at line end:
                        if text.match(regex("^ *(?:\n|$)")) != nil {
                            let label = normalizeReference(rawLabel)
                            
                            if refmap[label] == nil {
                                refmap.updateValue(Link(destination: destination, title: title), forKey: label)
                            }
                            
                            possibleReference = text.stringValue
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    func parse(subject:String) -> [Inline] {
        var inlines = [Inline]()
        var text = Text(string: subject)
        
        while parseInline(&text, inlines: &inlines) {}
        return inlines
    }
    
    func parseInline(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if let next = text.peek() {
            
            var result:Bool = false
            
            switch next {
            case "\n": result = parseNewline(&text, inlines: &inlines)
            case "\\": result = parseEscaped(&text, inlines: &inlines)
            case "`":  result = parseBackticks(&text, inlines: &inlines)
            case "*":  fallthrough
            case "_":  result = parseEmphasis(&text, inlines: &inlines)
            case "[":  result = parseLink(&text, inlines: &inlines)
            case "!":  result = parseImage(&text, inlines: &inlines)
            case "<":  result = parseAutolink(&text, inlines: &inlines) || parseHTMLTag(&text, inlines: &inlines)
            case "&":  result = parseEntity(&text, inlines: &inlines)
            default: break
            }
            
            return result || parseString(&text, inlines: &inlines)
            
        } else {
            return false
        }
    }
    
    // Parse a newline.  If it was preceded by two spaces, return a hard
    // line break; otherwise a soft line break.
    func parseNewline(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if !text.startsWithAny("\n") {
            return false
        }
        
        text.skip(1)
        
        if let last = inlines.last {
            switch last {
            case .Str(var text):
                
                if let endingWhitespace = text.rangeOfFirstMatch(regex(" +$")) {
                    let spaceCount = distance(endingWhitespace.startIndex, text.endIndex)
                    text.removeRange(endingWhitespace)
                    inlines.removeLast()
                    inlines.append(.Str(text))
                    
                    if spaceCount >= 2 {
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
    
    // Parse a backslash-escaped special character, adding either the escaped
    // character, a hard line break (if the backslash is followed by a newline),
    // or a literal backslash to the 'inlines' list.
    func parseEscaped(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if !text.startsWithAny("\\") {
            return false
        }
        
        text.skip(1)
        
        if let character = text.peek() {
            
            if character == "\n" {
                text.skip(1)
                inlines.append(.Hardbreak)
                return true
            }
            
            if String(character).matches(reEscapable) {
                text.skip(1)
                inlines.append(.Str(String(character)))
                return true
            }
        }
        
        inlines.append(.Str("\\"))
        
        return true
    }
    
    // Attempt to parse backticks, adding either a backtick code span or a
    // literal sequence of backticks to the 'inlines' list.
    func parseBackticks(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if let ticks = text.match(regex("^`+")) {
            
            let textAfterTicks = text
            
            while let match = text.match(regex("`+")) {
                if match == ticks {
                    var textBeforeTicks = text
                    textBeforeTicks.skip(-countElements(match))
                    inlines.append(.Code(trim(textBeforeTicks.since(textAfterTicks).stringByReplacingAll(regex("[ \n]+"), withTemplate: " "))))
                    return true
                }
            }
            
            // If we got here, we didn't match a closing backtick sequence.
            inlines.append(.Str(ticks))
            text = textAfterTicks
            return true
            
        } else {
            return false
        }
    }
    
    // Attempt to parse emphasis or strong emphasis in an efficient way,
    // with no backtracking.
    func parseEmphasis(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if !text.startsWithAny("*", "_") {
            return false
        }
        
        let character = text.peek()!
        
        // Get opening delimiters.
        let (delimiterCount, canOpen, _) = scanDelims(text, character)
        
        // We provisionally add a literal string.  If we match appropriate
        // closing delimiters, we'll change this to Strong or Emph.
        let openDelimiterText = text.read(delimiterCount)
        inlines.append(.Str(openDelimiterText))
        
        // Record the position of this opening delimiter:
        let delimiterPosition = inlines.endIndex - 1
        
        if !canOpen || delimiterCount == 0 {
            return false
        }
        
        switch delimiterCount {
        case 1:  // we started with * or _
            
            while true {
                let (closeDelimiterCount, _, canClose) = scanDelims(text, character)
                if closeDelimiterCount >= 1 && canClose {
                    text.skip(1)
                    // Convert the inline at delimpos, currently a string with the delim,
                    // into an Emph whose contents are the succeeding inlines
                    let inlinesToEmphasize = delimiterPosition + 1 ..< inlines.endIndex
                    inlines[delimiterPosition] = .Emphasis(Array(inlines[inlinesToEmphasize]))
                    inlines.removeRange(inlinesToEmphasize)
                    break
                } else if !parseInline(&text, inlines: &inlines) {
                    break
                }
            }
            return true
            
        case 2:   // We started with ** or __
            
            while true {
                let (closeDelimiterCount, _, canClose) = scanDelims(text, character)
                if closeDelimiterCount >= 2 && canClose {
                    text.skip(2)
                    
                    let inlinesToEmphasize = delimiterPosition + 1 ..< inlines.endIndex
                    inlines[delimiterPosition] = .Strong(Array(inlines[inlinesToEmphasize]))
                    inlines.removeRange(inlinesToEmphasize)
                    break
                } else if !parseInline(&text, inlines: &inlines) {
                    break
                }
            }
            return true
            
        case 3:  // We started with *** or ___
            
            var firstClose:(position:Int, delimiterCount:Int)! = nil
            
            while true {
                var (closeDelimiterCount, _, canClose) = scanDelims(text, character)
                if canClose && (firstClose == nil || closeDelimiterCount != firstClose.delimiterCount) {
                    
                    if firstClose != nil { // if we've already passed the first closer:
                        
                        if closeDelimiterCount > 3 - firstClose.delimiterCount {
                            closeDelimiterCount = 3 - firstClose.delimiterCount
                        }
                        text.skip(closeDelimiterCount)
                        
                        let deepInlines = Array(inlines[delimiterPosition+1..<firstClose.position])
                        let shallowInlines = Array(inlines[firstClose.position+1..<inlines.endIndex])
                        let subinlines = [firstClose.delimiterCount == 1 ? .Emphasis(deepInlines) : .Strong(deepInlines)] + shallowInlines
                        inlines[delimiterPosition] = firstClose.delimiterCount == 1 ? .Strong(subinlines) : .Emphasis(subinlines)
                        inlines.removeRange(delimiterPosition+1..<inlines.endIndex)
                        break
                    } else {
                        
                        if closeDelimiterCount == 3 {
                            // If we opened with ***, then we interpret *** as * followed by **
                            // giving us <strong><em>
                            closeDelimiterCount = 1
                        }
                        text.skip(closeDelimiterCount)
                        
                        // this is the first closer; for now, add literal string;
                        // we'll change this when he hit the second closer
                        inlines.append(.Str(text.prev(closeDelimiterCount)))
                        firstClose = (inlines.endIndex - 1, closeDelimiterCount)
                    }
                } else  if !parseInline(&text, inlines: &inlines) {
                    break
                }
            }
            return true
            
        default:
            return false
            
        }
    }
    
    func parseLink(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        let originalText = text
        
        if let rawLabel = parseLinkLabel(&text) {
            
            let textAfterLabel = text
            
            // if we got this far, we've parsed a label.
            // Try to parse an explicit link: [label](url "title")
            if text.startsWithAny("(") {
                text.skip(1)
                text.spln()
                
                if let destination = parseLinkDestination(&text) {
                    text.spln()
                    let title = parseLinkTitle(&text)
                    text.spln()
                    
                    if text.match(regex("^\\)")) != nil {
                        inlines.append(.Link(destination: destination, title: title ?? "", label: parseRawLabel(rawLabel)))
                        return true
                    }
                }
                
                // Something failed to match. Revert.
                text = originalText
                return false
            }
            
            // If we're here, it wasn't an explicit link. Try to parse a reference link.
            
            text.spln()
            
            let beforeSecondLabel = text
            
            var refLabel:String
            
            if let label = parseLinkLabel(&text) {
                if countElements(label) > 2 {
                    refLabel = label
                } else {
                    refLabel = rawLabel
                }
            } else {
                text = textAfterLabel
                refLabel = rawLabel
            }
            
            // lookup rawlabel in refmap
            if let link = refmap[normalizeReference(refLabel)] {
                inlines.append(.Link(destination: link.destination, title: link.title ?? "", label: parseRawLabel(rawLabel)))
                return true
            }
            
            // Nothing worked, rewind:
            text = originalText
            return false
            
        } else {
            return false
        }
    }
    
    // Attempt to parse a link label, returning number of characters parsed.
    func parseLinkLabel(inout text:Text) -> String? {
        let originalText = text
        
        if !text.startsWithAny("[") {
            return nil
        }
        
        var nestLevel = 0
        
        if labelNestLevel > 0 {
            // If we've already checked to the end of this subject
            // for a label, even with a different starting [, we
            // know we won't find one here and we can just return.
            // This avoids lots of backtracking.
            // Note:  nest level 1 would be: [foo [bar]
            //        nest level 2 would be: [foo [bar [baz]
            labelNestLevel -= 1
            return nil
        }
        
        text.skip(1) // advance past [
        
        while let character = text.peek() {
            if character == "]" && nestLevel == 0 {
                break
            }
            
            var dummyInlines = [Inline]()
            
            switch character {
            case "`": parseBackticks(&text, inlines: &dummyInlines)
            case "<": parseAutolink(&text, inlines: &dummyInlines) || parseHTMLTag(&text, inlines: &dummyInlines) || parseString(&text, inlines: &dummyInlines)
            case "[":
                nestLevel += 1
                text.skip(1)
            case "]":
                nestLevel -= 1
                text.skip(1)
            case "\\": parseEscaped(&text, inlines: &dummyInlines)
            default: parseString(&text, inlines: &dummyInlines)
            }
        }
        
        if text.startsWithAny("]") {
            labelNestLevel = 0
            text.skip(1)
            return text.since(originalText)
        } else {
            if text.peek() == nil {
                labelNestLevel = nestLevel
            }
            text = originalText
            return nil
        }
    }
    
    // Attempt to parse link title (sans quotes), returning the string
    // or null if no match.
    func parseLinkTitle(inout text:Text) -> String? {
        let previousCharacter = text.prev()!
        
        if !String(previousCharacter).matches(regex("\\s")) {
            return nil
        }
        
        if let match = text.match(reLinkTitle) {
            // chop off quotes from title and unescape:
            return unescape(shave(match, 1, 1))
        } else {
            return nil
        }
    };
    
    // Attempt to parse link destination, returning the string or
    // null if no match.
    func parseLinkDestination(inout text:Text) -> String? {
        if let match = text.match(reLinkDestinationBraces) { // chop off surrounding <..>:
            return unescape(shave(match, 1, 1))
        } else if let match = text.match(reLinkDestination) {
            return unescape(match)
        } else {
            return nil
        }
    }
    
    func parseRawLabel(string:String) -> [Inline] {
        return InlineParser().parse(shave(string, 1, 1))
    }
    
    // Attempt to parse an image.  If the opening '!' is not followed
    // by a link, add a literal '!' to inlines.
    func parseImage(inout text:Text, inout inlines:[Inline]) -> Bool {
        if !text.startsWithAny("!") {
            return false
        }
        
        text.skip(1)
        
        if parseLink(&text, inlines: &inlines) {
            switch inlines.last! {
            case .Link(let destination, let title, let label):
                inlines[inlines.endIndex - 1] = .Image(destination: destination, title: title, label: label)
            default:
                assertionFailure("Expected a link")
            }
        } else {
            inlines.append(.Str("!"))
        }
        
        return true
    }
    
    // Attempt to parse an autolink (URL or email in pointy brackets).
    func parseAutolink(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if let match = text.match(regex("^<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>")) {  // email autolink
            let destination = match.substringWithRange(advance(match.startIndex, 1)..<advance(match.endIndex, -1))
            inlines.append(.Link(destination: "mailto:" + destination, title: "", label: [.Str(destination)]))
            return true
        }
        
        if let match = text.match(regex("^<(?:coap|doi|javascript|aaa|aaas|about|acap|cap|cid|crid|data|dav|dict|dns|file|ftp|geo|go|gopher|h323|http|https|iax|icap|im|imap|info|ipp|iris|iris.beep|iris.xpc|iris.xpcs|iris.lwz|ldap|mailto|mid|msrp|msrps|mtqp|mupdate|news|nfs|ni|nih|nntp|opaquelocktoken|pop|pres|rtsp|service|session|shttp|sieve|sip|sips|sms|snmp|soap.beep|soap.beeps|tag|tel|telnet|tftp|thismessage|tn3270|tip|tv|urn|vemmi|ws|wss|xcon|xcon-userid|xmlrpc.beep|xmlrpc.beeps|xmpp|z39.50r|z39.50s|adiumxtra|afp|afs|aim|apt|attachment|aw|beshare|bitcoin|bolo|callto|chrome|chrome-extension|com-eventbrite-attendee|content|cvs|dlna-playsingle|dlna-playcontainer|dtn|dvb|ed2k|facetime|feed|finger|fish|gg|git|gizmoproject|gtalk|hcp|icon|ipn|irc|irc6|ircs|itms|jar|jms|keyparc|lastfm|ldaps|magnet|maps|market|message|mms|ms-help|msnim|mumble|mvn|notes|oid|palm|paparazzi|platform|proxy|psyc|query|res|resource|rmi|rsync|rtmp|secondlife|sftp|sgn|skype|smb|soldat|spotify|ssh|steam|svn|teamspeak|things|udp|unreal|ut2004|ventrilo|view-source|webcal|wtai|wyciwyg|xfire|xri|ymsgr):[^<>\\x00-\\x20]*>", options: .CaseInsensitive)) {
            
            let destination = match.substringWithRange(advance(match.startIndex, 1)..<advance(match.endIndex, -1))
            inlines.append(.Link(destination: destination, title: "", label: [.Str(destination)]))
            return true
        }
        
        return false
    }
    
    // Attempt to parse a raw HTML tag.
    func parseHTMLTag(inout text:Text, inout inlines:[Inline]) -> Bool {
        if let match = text.match(reHtmlTag) {
            inlines.append(.HTML(match))
            return true
        } else {
            return false
        }
    }
    
    func parseEntity(inout text:Text, inout inlines:[Inline]) -> Bool {
        
        if let match = text.match(regex("^&(?:#x[a-f0-9]{1,8}|#[0-9]{1,8}|[a-z][a-z0-9]{1,31});", options: .CaseInsensitive)) {
            inlines.append(.Entity(match))
            return true
        } else {
            return false
        }
    }
    
    func parseString(inout text:Text, inout inlines:[Inline]) -> Bool {
        if let match = text.match(reMain) {
            inlines.append(.Str(match))
            return true
        } else {
            return false
        }
    }
}

// Scan a sequence of characters == c, and return information about
// the number of delimiters and whether they are positioned such that
// they can open and/or close emphasis or strong emphasis.  A utility
// function for strong/emph parsing.
func scanDelims(var text:Text, character:Character) -> (count:Int, canOpen:Bool, canClose:Bool) {
    
    var count = 0
    let charBefore = text.prev() ?? "\n"
    
    while text.peek() == character {
        count += 1
        text.skip(1)
    }
    
    let charAfter = text.peek() ?? "\n"
    
    let canOpen = count > 0 && count <= 3 && !String(charAfter).matches(regex("\\s")) && (character != "_" || !String(charBefore).matches(regex("[a-z0-9]", options: .CaseInsensitive)))
    let canClose = count > 0 && count <= 3 && !String(charBefore).matches(regex("\\s")) && (character != "_" || !String(charAfter).matches(regex("[a-z0-9]", options: .CaseInsensitive)))
    
    return (count, canOpen, canClose)
}

// Normalize reference label: collapse internal whitespace
// to single space, remove leading/trailing whitespace, case fold.
func normalizeReference(reference:String) -> String {
    return trim(reference).stringByReplacingAll(regex("\\s+"), withTemplate: " ").uppercaseString
}

func shave(string:String, leading:Int, trailing:Int) -> String {
    return string.substringWithRange(advance(string.startIndex, leading) ..< advance(string.endIndex, -trailing))
}
