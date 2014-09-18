//
//  Document.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/5/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

public enum IncorporationResult {
    case Success
    case Error(String)
    
    var isError:Bool {
        switch self {
        case .Error(_):
            return true
        case .Success:
            return false
        }
    }
}

public func parse(markdown:String) -> Block {
    let parser = DocumentParser()
    var lines = split(markdown.stringByReplacingAll(regex("\r\n|\n|\r"), withTemplate: "\n"), { $0 == "\n" }, maxSplit: Int.max, allowEmptySlices: true)
    
    if !lines.isEmpty && lines.last!.isEmpty {
        lines.removeLast()
    }
    
    for (index, line) in enumerate(lines) {
        parser.incorporateLine(line, index + 1)
    }
    
    return parser.finalize(lines.count)
}

public class DocumentParser {
    
    let doc = Block(type: .Document, startLine: 1, startColumn: 1)
    var tip: Block!
    let inlineParser = InlineParser()
    
    public init() {
        tip = doc
    }
    
    public func incorporateLine(var line: String, _ lineNumber:Int) -> IncorporationResult {
        
        var allMatched = true
        let CODE_INDENT = 4
        
        var container = doc
        var oldTip = tip
        
        // Convert tabs to spaces:
        line = detabLine(line)
        
        var offset = line.startIndex
        var blank:Bool = false
        
        // For each containing block, try to parse the associated line start.
        // Bail out on failure: container will point to the last matching block.
        // Set all_matched to false if not all containers match.
        while let lastChild = container.children.last {
            
            if !lastChild.open {
                break
            }
            
            container = lastChild
            
            var firstNonspace: String.Index
            
            if let match = line.rangeOfFirstMatch(regex("[^ ]"), options: nil, from: offset) {
                firstNonspace = match.startIndex
                blank = false
            } else {
                firstNonspace = line.endIndex
                blank = true
            }
            
            let indent = distance(offset, firstNonspace)
            
            switch container.type {
            case .BlockQuote:
                
                if indent <= 3 && !blank && line[firstNonspace] == ">" {
                    offset = advance(firstNonspace, 1)
                    if offset != line.endIndex && line[offset] == " " {
                        offset = advance(offset, 1)
                    }
                } else {
                    allMatched = false
                }
                
            case .ListItem:
                
                if indent >= container.listData.markerOffset + container.listData.padding {
                    offset = advance(offset, container.listData.markerOffset + container.listData.padding)
                } else if (blank) {
                    offset = firstNonspace
                } else {
                    allMatched = false
                }
                
            case .IndentedCode:
                
                if indent >= CODE_INDENT {
                    offset = advance(offset, CODE_INDENT)
                } else if blank {
                    offset = firstNonspace
                } else {
                    allMatched = false
                }
                
            case .ATXHeader:
                fallthrough
                
            case .SetextHeader:
                fallthrough
                
            case .HorizontalRule:
                // a header can never container > 1 line, so fail to match:
                allMatched = false
                
            case .FencedCode:
                
                // skip optional spaces of fence offset
                var index = container.fenceOffset!
                while (index > 0 && offset != line.endIndex && line[offset] == " ") {
                    offset = advance(offset, 1);
                    index -= 1
                }
                
            case .HtmlBlock:
                if (blank) {
                    allMatched = false
                }
                
                
            case .Paragraph:
                if (blank) {
                    container.lastLineBlank = true
                    allMatched = false
                }
                
            default:
                break
            
            }
            
            if !allMatched {
                container = container.parent!
                break
            }
        }
        
        let lastMatchedContainer = container
        
        // This function is used to finalize and close any unmatched
        // blocks.  We aren't ready to do this now, because we might
        // have a lazy paragraph continuation, in which case we don't
        // want to close unmatched blocks.  So we store this closure for
        // use later, when we have more information.
        var alreadyClosedUnmatchedBlocks = false
        func closeUnmatchedBlocks() {
            while !alreadyClosedUnmatchedBlocks && oldTip !== lastMatchedContainer {
                finalize(oldTip, lineNumber: lineNumber)
                oldTip = oldTip.parent
            }
            alreadyClosedUnmatchedBlocks = true
        }
        
        // Check to see if we've hit 2nd blank line; if so break out of list:
        if (blank && container.lastLineBlank) {
            breakOutOfLists(container, lineNumber: lineNumber);
        }
        
        // Unless last matched container is a code block, try new container starts,
        // adding children to the last matched container:
        while !contains([.FencedCode, .IndentedCode, .HtmlBlock], container.type) && line.rangeOfFirstMatch(regex("^[ #`~*+_=<>0-9-]"), options: nil, from: offset) != nil {
            
            
            var firstNonspace: String.Index
                
            if let match = line.rangeOfFirstMatch(regex("[^ ]"), options: nil, from: offset) {
                firstNonspace = match.startIndex
                blank = false
            } else {
                firstNonspace = line.endIndex
                blank = true
            }
            
            let indent = distance(offset, firstNonspace)
            
            if indent >= CODE_INDENT {
                
                // indented code
                if tip.type != .Paragraph && !blank {
                    offset = advance(offset, CODE_INDENT)
                    closeUnmatchedBlocks()
                    container = addChild(.IndentedCode, lineNumber, distance(line.startIndex, offset))
                } else { // indent > 4 in a lazy paragraph continuation
                    break
                }
                
            } else if !blank && line[firstNonspace] == ">" {
                
                // blockquote
                offset = advance(firstNonspace, 1)
                // optional following space
                if offset != line.endIndex && line[offset] == " " {
                    offset = advance(offset, 1)
                }
                closeUnmatchedBlocks()
                container = addChild(.BlockQuote, lineNumber, distance(line.startIndex, offset))
                
            } else if let match = line.substringFromIndex(firstNonspace).firstMatch(regex("^#{1,6}(?: +|$)"))?.text {
                // ATX header
                offset = advance(firstNonspace, countElements(match))
                closeUnmatchedBlocks()
                container = addChild(.ATXHeader, lineNumber, distance(line.startIndex, firstNonspace))
                container.level = countElements(trim(match)) // number of #s
                // remove trailing ###s:
                container.strings = [line.substringFromIndex(offset).stringByReplacingFirst(regex("(?:(\\\\#) *#*| *#+) *$"), withTemplate: "$1")]
                break

            } else if let match = line.substringFromIndex(firstNonspace).firstMatch(regex("^`{3,}(?!.*`)|^~{3,}(?!.*~)"))?.text {
                
                // fenced code block
                let fenceLength = countElements(match)
                closeUnmatchedBlocks()
                container = addChild(.FencedCode, lineNumber, distance(line.startIndex, firstNonspace))
                container.fenceLength = fenceLength
                container.fenceOffset = distance(offset, firstNonspace)
                container.fenceCharacter = match[match.startIndex]
                offset = advance(firstNonspace, fenceLength)
                break
                
            } else if line.firstMatch(reHtmlBlockOpen, options: nil, from: firstNonspace) != nil {
                
                // html block
                closeUnmatchedBlocks()
                container = addChild(.HtmlBlock, lineNumber, distance(line.startIndex, firstNonspace))
                // note, we don't adjust offset because the tag is part of the text
                break
                
            } else if container.type == .Paragraph && container.strings.count == 1 && line.substringFromIndex(firstNonspace).firstMatch(regex("^(?:=+|-+) *$")) != nil {
                let match = line.substringFromIndex(firstNonspace).firstMatch(regex("^(?:=+|-+) *$"))!.text
                
                // setext header line
                closeUnmatchedBlocks()
                container.type = .SetextHeader // convert Paragraph to SetextHeader
                container.level = match.hasPrefix("=") ? 1 : 2
                offset = line.endIndex
                
            } else if line.firstMatch(reHrule, options: nil, from: firstNonspace) != nil {
                // hrule
                closeUnmatchedBlocks()
                container = addChild(.HorizontalRule, lineNumber, distance(line.startIndex, firstNonspace));
                offset = line.endIndex
                break
                
            } else if let data = parseListMarker(line, firstNonspace, indent) {
                
                // list item
                closeUnmatchedBlocks()
                
                if data.padding < distance(firstNonspace, line.endIndex) {
                    offset = advance(firstNonspace, data.padding)
                } else {
                    offset = line.endIndex
                }
            
                // add the list if needed
                if container.type != .List || container.listData.type != data.type {
                    container = addChild(.List, lineNumber, distance(line.startIndex, firstNonspace))
                    container.listData = data
                }
                
                // add the list item
                container = addChild(.ListItem, lineNumber, distance(line.startIndex, firstNonspace))
                container.listData = data
                
            } else {
                
                break
                
            }
            
            if container.type.acceptsLines {
                // if it's a line container, it can't contain other containers
                break
            }
            
        }
        
        // What remains at the offset is a text line.  Add the text to the
        // appropriate container.
        
        var firstNonspace: String.Index
        
        if let match = line.rangeOfFirstMatch(regex("[^ ]"), options: nil, from: offset) {
            firstNonspace = match.startIndex
            blank = false
        } else {
            firstNonspace = line.endIndex
            blank = true
        }
        
        let indent = distance(offset, firstNonspace)
        
        // First check for a lazy paragraph continuation:
        if tip !== lastMatchedContainer && !blank && tip.type == .Paragraph && tip.strings.count > 0 {
            
            tip.lastLineBlank = false // TODO: Possible bug in stmd.js?
            let result = addLine(line, offset: offset)
            if result.isError {
                return result
            }
            
        } else { // not a lazy continuation
            
            // finalize any blocks not matched
            closeUnmatchedBlocks()
            
            // Block quote lines are never blank as they start with >
            // and we don't count blanks in fenced code for purposes of tight/loose
            // lists or breaking out of lists.  We also don't set last_line_blank
            // on an empty list item.
            container.lastLineBlank = blank &&
                !(container.type == .BlockQuote ||
                    container.type == .FencedCode ||
                        (container.type == .ListItem &&
                            container.children.count == 0 &&
                            container.startLine == lineNumber))
            
            var parent = container.parent
            while let c = parent {
                c.lastLineBlank = false
                parent = c.parent
            }
            
            switch container.type {
                
            case .IndentedCode:
                fallthrough
                
            case .HtmlBlock:
                addLine(line, offset: offset)
                
            case .FencedCode:
                
                var matched = false
                
                // check for closing code fence:
                if indent <= 3 && firstNonspace < line.endIndex && line[firstNonspace] == container.fenceCharacter {
                    if let match = line.substringFromIndex(firstNonspace).firstMatch(regex("^(?:`{3,}|~{3,})(?= *$)"))?.text {
                        if countElements(match) >= container.fenceLength {
                            // don't add closing fence to container; instead, close it:
                            finalize(container, lineNumber: lineNumber)
                            matched = true
                        }
                    }
                }
                
                if !matched {
                    addLine(line, offset: offset)
                }
                
            case .ATXHeader:
                fallthrough
                
            case .SetextHeader:
                fallthrough
                
            case .HorizontalRule:
                // nothing to do; we already added the contents.
                break
                
            default:
                
                if container.type.acceptsLines {
                    addLine(line, offset: firstNonspace)
                } else if blank {
                    // do nothing
                } else if container.type != .HorizontalRule && container.type != .SetextHeader {
                    // create paragraph container for line
                    container = addChild(.Paragraph, lineNumber, distance(line.startIndex, firstNonspace))
                    addLine(line, offset: firstNonspace)
                } else {
                    return .Error("Line \(lineNumber) with container type \(container.type) did not match any condition.")
                }
                
            }
        }
        
        return IncorporationResult.Success
    }
    
    func breakOutOfLists(var block:Block, lineNumber:Int) {
        
        if let lastList = block.highestBlockWithType(.List) {

            while block !== lastList {
                finalize(block, lineNumber: lineNumber)
                block = block.parent!
            }
        
            finalize(lastList, lineNumber: lineNumber)
            tip = lastList.parent
        }
    }
    
    // Add block of type tag as a child of the tip.  If the tip can't
    // accept children, close and finalize it and try its parent,
    // and so on til we find a block that can accept children.
    func addChild(type:BlockType, _ lineNumber:Int, _ offset:Int) -> Block {
        while !tip.type.canContain(type) {
            finalize(tip, lineNumber: lineNumber)
        }
        
        let columnNumber = offset + 1 // offset 0 = column 1
        let newBlock = Block(type: type, startLine: lineNumber, startColumn: columnNumber)
        tip.children += [newBlock]
        newBlock.parent = tip
        tip = newBlock
        return newBlock
    }
    
    func addLine(line:String, offset:String.Index) -> IncorporationResult {
        if !tip.open {
            return .Error("Attempted to add line (\(line)) to closed container.")
        }
        
        tip.strings += [line.substringFromIndex(offset)]
        return .Success
    }
    
    public func finalize(lineNumber:Int) -> Block {
        while let block = tip {
            finalize(block, lineNumber: lineNumber)
        }
        
        processInlines(doc)
        
        return doc
    }
    
    // Finalize a block.  Close it and do any necessary postprocessing,
    // e.g. creating string_content from strings, setting the 'tight'
    // or 'loose' status of a list, and parsing the beginnings
    // of paragraphs for reference definitions.  Reset the tip to the
    // parent of the closed block.
    func finalize(block:Block, lineNumber:Int) {
        
        // don't do anything if the block is already closed
        if !block.open {
            return
        }
        
        block.open = false
        if lineNumber > block.startLine {
            block.endLine = lineNumber - 1
        } else {
            block.endLine = lineNumber // TODO: Possible bug in stmd.js
        }
        
        switch block.type {
            
        case .Paragraph:
            
            block.stringContent = join("\n", block.strings).stringByReplacingAll(regex("^ *", options: .AnchorsMatchLines), withTemplate: "")
            
            // try parsing the beginning as link reference definitions:
            while block.stringContent.hasPrefix("[") && inlineParser.parseReference(&(block.stringContent)) {
                if block.stringContent.matches(regex("^\\s*$")) {
                    block.type = .ReferenceDef
                    break
                }
            }
        
        case .ATXHeader:    fallthrough
        case .SetextHeader: fallthrough
        case .HtmlBlock:
            
            block.stringContent = join("\n", block.strings)
            
        case .IndentedCode:
            
            block.stringContent = join("\n", block.strings).stringByReplacingFirst(regex("(\n *)*$"), withTemplate: "\n")
            
        case .FencedCode:
            
            // first line becomes info string
            block.info = unescape(trim(block.strings[0]))
            if block.strings.count == 1 {
                block.stringContent = ""
            } else {
                block.stringContent = join("\n", block.strings[1..<block.strings.endIndex]) + "\n"
            }
            
        case .List:
            
            block.tight = true // tight by default
            
            for (i, item) in enumerate(block.children) {
            
                // check for non-final list item ending with blank line:
                let lastItem = i == block.children.endIndex - 1
                if item.endsWithBlankLine && !lastItem {
                    block.tight = false
                    break
                }
                
                // recurse into children of list item, to see if there are
                // spaces between any of them:
                for (j, subitem) in enumerate(item.children) {
                    
                    let lastSubitem = j == item.children.endIndex - 1
                    if subitem.endsWithBlankLine && !(lastItem && lastSubitem) {
                        block.tight = false
                        break
                    }
                }
            }
        
        default:
            break
        }
        
        tip = block.parent // TODO: Possible bug in stmd.js
    }
    
    // Walk through a block & children recursively, parsing string content
    // into inline content where appropriate.
    func processInlines(block:Block) {
        
        switch block.type {
        case .Paragraph:    fallthrough
        case .SetextHeader: fallthrough
        case .ATXHeader:
            
            block.inlineContent = inlineParser.parse(trim(block.stringContent))
            block.stringContent = ""
            
        default:
            
            break
        }
        
        for child in block.children {
            processInlines(child)
        }
    }
}

