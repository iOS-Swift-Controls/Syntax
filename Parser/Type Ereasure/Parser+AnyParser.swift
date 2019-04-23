//
//  Parser+AnyParser.swift
//  Llama
//
//  Created by Mathias Quintero on 25.02.19.
//  Copyright © 2019 Mathias Quintero. All rights reserved.
//

import Foundation

extension Parser {
    
    public func any() -> AnyParser<Token, Output> {
        return AnyParser(self)
    }
    
}