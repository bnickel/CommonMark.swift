//
//  main.swift
//  stmd-wrapped
//
//  Created by Brian Nickel on 9/11/14.
//  Copyright (c) 2014 Brian Nickel. All rights reserved.
//

import Cocoa
import CommonMarkdown

let version = "1.0"

var outputAST = false
var files = [String]()
var lineNumber:Int = 1

func printUsage() {
    println("Usage:   stmd [FILE*]")
    println("Options: --help, -h    Print usage information")
    println("         --ast         Print AST instead of HTML")
    println("         --version     Print version")
}

func printVersion() {
    println("stmd \(version) - standard markdown converter (c) 2014 Brian Nickel")
}

var arguments = Process.arguments
arguments.removeAtIndex(0)

for argument in arguments {
    
    switch argument as String {
        
    case "--version":
        printVersion()
        exit(0)
        
    case "--help":
        fallthrough
        
    case "-h":
        printUsage()
        exit(0)
        
    case "--ast":
        outputAST = true
        
    case let arg where arg.hasPrefix("-"):
        printUsage()
        exit(1)
        
    case let file:
        files.append(file)
    }
}

let doc = DocumentParser()

func readLine(file:UnsafeMutablePointer<FILE>) -> String? {
    
    var length:UInt = 0
    let chars = fgetln(file, &length)
    
    if chars != nil {
        return NSString(bytes: chars, length: Int(length), encoding: NSUTF8StringEncoding)
    }
    
    return nil
}

func readFile(file:UnsafeMutablePointer<FILE>) -> IncorporationResult {
    
    while let line = readLine(file) {
        
        switch doc.incorporateLine(line, lineNumber) {
            
        case .Success:
            lineNumber += 1
            
        case .Error(let message):
            return IncorporationResult.Error("Error incorporating line \(lineNumber): \(message)")
        }
    }
    
    if feof(file) == 0 {
        return IncorporationResult.Error("Error reading line \(lineNumber): \(strerror(errno))")
    }
    
    return IncorporationResult.Success
}

if files.count == 0 {
    readFile(stdin)
}

for file in files {
    let fd = fopen(file, "r")
    if fd == nil {
        println("Error opening file \(file): \(strerror(errno))")
        exit(1)
    }
    
    let results = readFile(fd)
    
    fclose(fd)
    
    switch results {
    case .Success:
        break
    case .Error(let message):
        println(message)
        exit(1)
    }
}

let renderer = HTMLRenderer()

println(renderer.renderBlock(doc.finalize(lineNumber)))
