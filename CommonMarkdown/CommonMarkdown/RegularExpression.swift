//
//  RegularExpression.swift
//  CommonMarkdown
//
//  Created by Brian Nickel on 9/8/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

import Foundation

struct RegularExpression {
    let expr:NSRegularExpression
    
    init(pattern:String, options:NSRegularExpressionOptions = nil) {
        var error:NSError?
        let potentialExpression:NSRegularExpression? = NSRegularExpression(pattern: pattern, options: options, error: &error)
        assert(potentialExpression != nil, "Could not parse pattern: \(pattern), error:\(error!)")
        expr = potentialExpression!
    }
}

extension RegularExpression : Printable {
    
    var description:String {
        return "\(expr.pattern) (options:\(expr.options.toRaw()), groups:\(expr.numberOfCaptureGroups))"
    }
}

func regex(pattern:String, options:NSRegularExpressionOptions = nil) -> RegularExpression {
    return RegularExpression(pattern: pattern, options: options)
}

extension String {
    
    func matches(expression:RegularExpression, options:NSMatchingOptions = nil) -> Bool {
        return matches(expression, options: options, subrange: startIndex ..< endIndex)
    }
    
    func matches(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index) -> Bool {
        return matches(expression, options: options, subrange: fromIndex ..< endIndex)
    }
    
    func matches(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>) -> Bool {
        let foundationString: NSString = substringWithRange(subrange)
        
        let match = expression.expr.rangeOfFirstMatchInString(foundationString, options: nil, range: NSMakeRange(0, foundationString.length))
        
        return match.location != NSNotFound
    }
}

func rangeFromResultRange(originalSubrange:Range<String.Index>, foundationSubstring:NSString, foundationSubstringSubrange:NSRange) -> Range<String.Index>? {

    if foundationSubstringSubrange.location != NSNotFound {
        let matchOffset = advance(originalSubrange.startIndex, countElements(foundationSubstring.substringToIndex(foundationSubstringSubrange.location) as String))
        let matchLength = countElements(foundationSubstring.substringWithRange(foundationSubstringSubrange) as String)
            
        return matchOffset ..< advance(matchOffset, matchLength)
    } else {
        return nil
    }
}

extension String {

    func rangeOfFirstMatch(expression:RegularExpression, options:NSMatchingOptions = nil) -> Range<Index>? {
        return rangeOfFirstMatch(expression, options: options, subrange: startIndex ..< endIndex)
    }

    func rangeOfFirstMatch(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index) -> Range<Index>? {
        return rangeOfFirstMatch(expression, options: options, subrange: fromIndex ..< endIndex)
    }

    func rangeOfFirstMatch(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>) -> Range<Index>? {
        let foundationString: NSString = substringWithRange(subrange)
        
        let match = expression.expr.rangeOfFirstMatchInString(foundationString, options: nil, range: NSMakeRange(0, foundationString.length))

        return rangeFromResultRange(subrange, foundationString, match)
    }
}

struct Match {
    private let string:String
    private let subrange:Range<String.Index>
    private let foundationString:NSString
    private let result:NSTextCheckingResult
    let flags:NSMatchingFlags
    
    var text:String {
        return self[0]!
    }
    
    var range:Range<String.Index> {
        return rangeAtIndex(0)!
    }
    
    var numberOfRanges: Int {
        return result.numberOfRanges
    }
    
    subscript(index: Int) -> String? {
        assert(index >= 0 && index < result.numberOfRanges, "Index \(index) must be in 0..<\(result.numberOfRanges).")

        let range = result.rangeAtIndex(index)
        
        if range.location == NSNotFound {
            return nil
        } else {
            return foundationString.substringWithRange(range)
        }
    }
    
    func rangeAtIndex(index: Int) -> Range<String.Index>? {
        assert(index >= 0 && index < result.numberOfRanges, "Index \(index) must be in 0..<\(result.numberOfRanges).")

        return rangeFromResultRange(subrange, foundationString, result.rangeAtIndex(index))
    }
}

extension String {

    func firstMatch(expression:RegularExpression, options:NSMatchingOptions = nil) -> Match? {
        return firstMatch(expression, options: options, subrange: startIndex ..< endIndex)
    }

    func firstMatch(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index) -> Match? {
        return firstMatch(expression, options: options, subrange: fromIndex ..< endIndex)
    }

    func firstMatch(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>) -> Match? {
        let foundationString: NSString = substringWithRange(subrange)
        
        if let match = expression.expr.firstMatchInString(foundationString, options: options, range: NSMakeRange(0, foundationString.length)) {
            if match.range.location != NSNotFound {
                return Match(string: self, subrange: subrange, foundationString: foundationString, result: match, flags:.Completed)
            }
        }
        
        return nil
    }
}

extension String {

    func forEachMatch(expression:RegularExpression, options:NSMatchingOptions = nil, block:(Match) -> Bool) {
        return forEachMatch(expression, options: options, subrange: startIndex ..< endIndex, block: block)
    }

    func forEachMatch(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index, block:(Match) -> Bool) {
        return forEachMatch(expression, options: options, subrange: fromIndex ..< endIndex, block: block)
    }

    func forEachMatch(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>, block:(Match) -> Bool) {
        let foundationString: NSString = substringWithRange(subrange)

        expression.expr.enumerateMatchesInString(foundationString, options: options, range: NSMakeRange(0, foundationString.length)) {
            (result, flags, var stop) in

            let match = Match(string: self, subrange: subrange, foundationString: foundationString, result: result, flags: flags)

            if block(match) {
                stop.put(true)
            }
        }
    }
}

extension String {

    mutating func replaceAll(expression:RegularExpression, options:NSMatchingOptions = nil, withTemplate template:String) {
        replaceAll(expression, options: options, subrange: startIndex ..< endIndex, withTemplate: template)
    }

    mutating func replaceAll(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index, withTemplate template:String) {
        replaceAll(expression, options: options, subrange: fromIndex ..< endIndex, withTemplate: template)
    }

    mutating func replaceAll(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>, withTemplate template:String) {
        let foundationString: NSString = substringWithRange(subrange)
        
        let result = expression.expr.stringByReplacingMatchesInString(foundationString, options: options, range: NSMakeRange(0, foundationString.length), withTemplate: template)

        self = substringToIndex(subrange.startIndex) + result + substringFromIndex(subrange.endIndex)

    }
}

extension String {

    func stringByReplacingAll(expression:RegularExpression, options:NSMatchingOptions = nil, withTemplate template:String) -> String {
        return stringByReplacingAll(expression, options: options, subrange: startIndex ..< endIndex, withTemplate: template)
    }

    func stringByReplacingAll(expression:RegularExpression, options:NSMatchingOptions, from fromIndex:Index, withTemplate template:String) -> String {
        return stringByReplacingAll(expression, options: options, subrange: fromIndex ..< endIndex, withTemplate: template)
    }

    func stringByReplacingAll(expression:RegularExpression, options:NSMatchingOptions, subrange:Range<Index>, withTemplate template:String) -> String {
        var transformedString = self
        transformedString.replaceAll(expression, options: options, subrange: subrange, withTemplate: template)
        return transformedString
    }
}