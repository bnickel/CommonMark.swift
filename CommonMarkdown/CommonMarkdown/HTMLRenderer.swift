//
//  HTMLRenderer.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/11/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

import Foundation

public class HTMLRenderer {
    
    public var blockSeparator = "\n"  // space between blocks
    public var innerSeparator = "\n"  // space between block container tag and contents
    public var softBreak = "\n" // by default, soft breaks are rendered as newlines in HTML
    // set to "<br />" to make them hard breaks
    // set to " " if you want to ignore line wrapping in source
    
    public init() {}
    
    // Render a single block element.
    public func renderBlock(block:Block, inTightList:Bool = false) -> String {
        
        switch block.type {
            
        case .Document:
            
            let wholeDoc = renderBlocks(block.children, inTightList:false)
            return wholeDoc.isEmpty ? wholeDoc : (wholeDoc + "\n")
            
        case .Paragraph:
            
            if inTightList {
                return renderInlines(block.inlineContent)
            } else {
                return inTags("p", contents: renderInlines(block.inlineContent))
            }
            
        case .BlockQuote:
            
            let filling = renderBlocks(block.children, inTightList: false)
            return inTags("blockquote", contents: filling.isEmpty ? innerSeparator : (innerSeparator + filling + innerSeparator))
            
        case .ListItem:
            
            return inTags("li", contents: trim(renderBlocks(block.children, inTightList: inTightList)))
            
        case .List:
            
            var tag:String
            var attributes = [String: String]()
            
            switch block.listData.type {
            case .Bullet(_):
                tag = "ul"
                
            case .Ordered(let start, _):
                tag = "ol"
                if start != 1 {
                    attributes = ["start": "\(start)"]
                }
            }
            
            return inTags(tag, attributes: attributes, contents: innerSeparator + renderBlocks(block.children, inTightList: block.tight) + innerSeparator)
            
        case .ATXHeader(let level):
            
            return inTags("h\(level)", contents: renderInlines(block.inlineContent))
            
        case .SetextHeader(let level):
            
            return inTags("h\(level)", contents: renderInlines(block.inlineContent))
            
        case .IndentedCode:
            
            return inTags("pre", contents: inTags("code", contents: escape(block.stringContent)))
            
        case .FencedCode(_, _, _):
            
            var attributes = [String: String]()
            let infoWords = split(block.info, { $0 == " " }, maxSplit: 1, allowEmptySlices: true)
            if !infoWords.isEmpty && !infoWords[0].isEmpty {
                attributes = ["class": infoWords[0]]
            }
            
            return inTags("pre", attributes: attributes, contents: inTags("code", contents: escape(block.stringContent)))
        
        case .HtmlBlock:
            
            return block.stringContent
            
        case .ReferenceDef:
            
            return ""
        
        case .HorizontalRule:
            
            return inTags("hr", selfClosing: true)
        }
    }
    
    func renderBlocks(blocks:[Block], inTightList:Bool) -> String {
        return join(blockSeparator, map(filter(blocks) { $0.type != .ReferenceDef }, { self.renderBlock($0, inTightList: inTightList) }))
    }
    
    func renderInline(inline:Inline) -> String {
        switch inline {
        case .Str(let text):
            return escape(text)
            
        case .Softbreak:
            return softBreak
            
        case .Hardbreak:
            return inTags("br", selfClosing: true) + "\n"
            
        case .Emphasis(let inlines):
            return inTags("em", contents: renderInlines(inlines))
            
        case .Strong(let inlines):
            return inTags("strong", contents: renderInlines(inlines))
            
        case .HTML(let text):
            return text
            
        case .Entity(let text):
            return text
            
        case .Link(let destination, let title, let label):
            
            var attributes = ["href": escape(destination, preserveEntities: true)]
            if !title.isEmpty {
                attributes.updateValue(escape(title, preserveEntities: true), forKey:"title")
            }
            return inTags("a", attributes: attributes, contents: renderInlines(label))
            
        case .Image(let destination, let title, let label):
            
            var attributes = ["src": escape(destination, preserveEntities: true), "alt": escape(renderInlines(label), preserveEntities: true)]
            if !title.isEmpty {
                attributes.updateValue(escape(title, preserveEntities: true), forKey: "title")
            }
            return inTags("img", attributes: attributes, selfClosing: true)
            
        case .Code(let text):
            return inTags("code", contents: escape(text))
        }
    }
    
    func renderInlines(inlines:[Inline]) -> String {
        return join("", map(inlines, { self.renderInline($0)}))
    }
    
    // Helper function to produce content in a pair of HTML tags.
    func inTags(tag:String, attributes:[String: String] = [:], contents:String = "", selfClosing:Bool = false) -> String {
        
        var result = "<" + tag + join("", map(attributes, { " \($0)=\"\($1)\"" }))
        
        if !contents.isEmpty {
            result += ">" + contents + "</" + tag + ">"
        } else if selfClosing {
            result += " />"
        } else {
            result += "></" + tag + ">"
        }
        
        return result
    }
    
    func escape(var string:String, preserveEntities: Bool = false) -> String {
        
        let ampRegex = preserveEntities ? regex("[&](?![#](x[a-f0-9]{1,8}|[0-9]{1,8});|[a-z][a-z0-9]{1,31};)", options: .CaseInsensitive) : regex("[&]")
        string.replaceAll(ampRegex, withTemplate: "&amp;")
        string.replaceAll(regex("[<]"), withTemplate: "&lt;")
        string.replaceAll(regex("[>]"), withTemplate: "&gt;")
        string.replaceAll(regex("[\"]"), withTemplate: "&quot;")
        return string
    }
}
