//
//  text.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/5/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

import Foundation

func detabLine(text:String) -> String {
    
    let TAB_COUNT = 4
    
    var output = ""
    var spacesToInsert = TAB_COUNT

    for character in text {
        
        if character == "\t" {
            while spacesToInsert > 0 {
                output.append(Character(" "))
                spacesToInsert -= 1
            }
        } else {
            output.append(character)
            spacesToInsert -= 1
        }
        
        if spacesToInsert == 0 {
            spacesToInsert = TAB_COUNT
        }
    }
    
    return output
}

func trim(text:String) -> String {
    return text.stringByReplacingAll(regex("(^\\s+)|(\\s+$)"), withTemplate: "")
}

let ESCAPABLE = "[!\"#$%&'()*+,./:;<=>?@\\[\\\\\\]^_`{|}~-]"
let ESCAPED_CHAR = "\\\\" + ESCAPABLE
let IN_DOUBLE_QUOTES = "\"(" + ESCAPED_CHAR + "|[^\"\\x00])*\""
let IN_SINGLE_QUOTES = "\'(" + ESCAPED_CHAR + "|[^\'\\x00])*\'"
let IN_PARENS = "\\((" + ESCAPED_CHAR + "|[^)\\x00])*\\)"
let REG_CHAR = "[^\\\\()\\x00-\\x20]"
let IN_PARENS_NOSP = "\\((" + REG_CHAR + "|" + ESCAPED_CHAR + ")*\\)"
let TAGNAME = "[A-Za-z][A-Za-z0-9]*"
let BLOCKTAGNAME = "(?:article|header|aside|hgroup|blockquote|hr|body|li|br|map|button|object|canvas|ol|caption|output|col|p|colgroup|pre|dd|progress|div|section|dl|table|td|dt|tbody|embed|textarea|fieldset|tfoot|figcaption|th|figure|thead|footer|footer|tr|form|ul|h1|h2|h3|h4|h5|h6|video|script|style)"
let ATTRIBUTENAME = "[a-zA-Z_:][a-zA-Z0-9:._-]*"
let UNQUOTEDVALUE = "[^\"'=<>`\\x00-\\x20]+"
let SINGLEQUOTEDVALUE = "\'[^\']*\'"
let DOUBLEQUOTEDVALUE = "\"[^\"]*\""
let ATTRIBUTEVALUE = "(?:" + UNQUOTEDVALUE + "|" + SINGLEQUOTEDVALUE + "|" + DOUBLEQUOTEDVALUE + ")"
let ATTRIBUTEVALUESPEC = "(?:" + "\\s*=" + "\\s*" + ATTRIBUTEVALUE + ")"
let ATTRIBUTE = "(?:" + "\\s+" + ATTRIBUTENAME + ATTRIBUTEVALUESPEC + "?)"
let OPENTAG = "<" + TAGNAME + ATTRIBUTE + "*" + "\\s*/?>"
let CLOSETAG = "</" + TAGNAME + "\\s*[>]"
let OPENBLOCKTAG = "<" + BLOCKTAGNAME + ATTRIBUTE + "*" + "\\s*/?>"
let CLOSEBLOCKTAG = "</" + BLOCKTAGNAME + "\\s*[>]"
let HTMLCOMMENT = "<!--([^-]+|[-][^-]+)*-->"
let PROCESSINGINSTRUCTION = "[<][?].*?[?][>]"
let DECLARATION = "<![A-Z]+" + "\\s+[^>]*>"
let CDATA = "<!\\[CDATA\\[([^\\]]+|\\][^\\]]|\\]\\][^>])*\\]\\]>"
let HTMLTAG = "(?:" + OPENTAG + "|" + CLOSETAG + "|" + HTMLCOMMENT + "|" + PROCESSINGINSTRUCTION + "|" + DECLARATION + "|" + CDATA + ")"
let HTMLBLOCKOPEN = "<(?:" + BLOCKTAGNAME + "[\\s/>]" + "|" + "/" + BLOCKTAGNAME + "[\\s>]" + "|" + "[?!])"

let reHtmlTag = regex("^" + HTMLTAG, options: .CaseInsensitive)

let reHtmlBlockOpen = regex("^" + HTMLBLOCKOPEN, options: .CaseInsensitive)

let reLinkTitle = regex(
    "^(?:\"(" + ESCAPED_CHAR + "|[^\"\\x00])*\"" +
    "|" +
        "\'(" + ESCAPED_CHAR + "|[^\'\\x00])*\"" +
    "|" +
       "\\((" + ESCAPED_CHAR + "|[^)\\x00])*\\))")

let reLinkDestinationBraces = regex("[<](?:[^<>\\n\\\\\\x00]" + "|" + ESCAPED_CHAR + "|" + "\\\\)*[>]")

let reLinkDestination = regex("(?:" + REG_CHAR + "+|" + ESCAPED_CHAR + "|" + IN_PARENS_NOSP + ")*")

let reEscapable = regex(ESCAPABLE)

let reAllEscapedChar = regex("\\\\(" + ESCAPABLE + ")")

let reEscapedChar = regex("^\\\\(" + ESCAPABLE + ")")

let reAllTab = regex("\t")

let reHrule = regex("^(?:(?:\\* *){3,}|(?:_ *){3,}|(?:- *){3,}) *$")

// Matches a character with a special meaning in markdown,
// or a string of non-special characters.
let reMain = regex("[\n`\\[\\]\\\\!<&*_]|[^\n`\\[\\]\\\\!<&*_]+", options: .AnchorsMatchLines)

func unescape(text:String) -> String {
    return text.stringByReplacingAll(reAllEscapedChar, withTemplate: "$1")
};

