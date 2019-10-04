//
//  RunScriptIntentHandler.swift
//  Pyto Intents
//
//  Created by Adrian Labbé on 30-07-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import Intents
import ios_system

class RunProgramIntentHandler: NSObject, RunProgramIntentHandling {
    
    func handle(intent: RunProgramIntent, completion: @escaping (RunProgramIntentResponse) -> Void) {
        sideLoading = true
        if intent.inApp?.boolValue == true {
            let userActivity = NSUserActivity(activityType: "RunProgramIntent")
            do {
                if let fileURL = intent.program?.fileURL {
                    let success = fileURL.startAccessingSecurityScopedResource()
                    userActivity.userInfo = ["bookmarkData" : try fileURL.bookmarkData(), "arguments" : intent.arguments ?? ""]
                    if success {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
            return completion(.init(code: .continueInApp, userActivity: userActivity))
        } else {
            
            _ = intent.program?.fileURL?.startAccessingSecurityScopedResource()
            
            let output = Pipe()
                        
            let _stdout = fdopen(output.fileHandleForWriting.fileDescriptor, "w")
            let _stderr = fdopen(output.fileHandleForWriting.fileDescriptor, "w")
            let _stdin = fopen(Bundle.main.path(forResource: "input", ofType: "txt")!.cValue, "r")
            
            initializeEnvironment()
            unsetenv("TERM")
            unsetenv("LSCOLORS")
            unsetenv("CLICOLOR")
            try? FileManager.default.copyItem(at: Bundle.main.url(forResource: "cacert", withExtension: "pem")!, to: FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)[0].appendingPathComponent("cacert.pem"))
            
            ios_switchSession(_stdout)
            ios_setStreams(_stdin, _stdout, _stderr)
                        
            let response = RunProgramIntentResponse(code: ios_system("lli \((intent.program?.fileURL?.path ?? "").replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")) \(intent.arguments ?? "")") == 0 ? .success : .failure, userActivity: nil)
                        
            let outputStr = String(data: output.fileHandleForReading.availableData, encoding: .utf8) ?? ""
            if !outputStr.replacingOccurrences(of: "\n", with: "").isEmpty {
                response.output = outputStr
            }
            
            return completion(response)
        }
    }
    
    func resolveProgram(for intent: RunProgramIntent, with completion: @escaping (INFileResolutionResult) -> Void) {
        guard let file = intent.program else {
            return
        }
        return completion(.success(with: file))
    }
    
    func resolveArguments(for intent: RunProgramIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let arguments = intent.arguments else {
            return completion(.success(with: ""))
        }
        
        return completion(.success(with: arguments))
    }
    
    func resolveInApp(for intent: RunProgramIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        completion(.success(with: intent.inApp?.boolValue ?? false))
    }
}
