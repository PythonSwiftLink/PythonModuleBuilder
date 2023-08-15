// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation
#if BEEWARE
import PythonLib
import PythonSwiftCore
#endif
import Combine

public typealias DictionaryPyPointer = [String: PyPointer]




public class ObservableDictionary: Subscriber, Publisher {
    
    
    class DictSubscription: Combine.Subscription {
        func request(_ demand: Subscribers.Demand) {
            
        }
        
        func cancel() {
            
        }
        
        
    }
    
    public enum Action {
        case new(value: DictionaryPyPointer)
        case update(newValues: DictionaryPyPointer)
        case add(key: String, value: PyPointer)
        case delete(key: String)
        case none
    }
    
    public typealias Input = Action
    
    public typealias Failure = Never
    
    public typealias Output = Action
    
    public var combineIdentifier: CombineIdentifier = .init()
    
    public var wrapped: DictionaryPyPointer
    
    public var subscribers = [AnySubscriber<Action, Never>]()
    
    public init() { wrapped = [:] }
    public init(_ pyDict: PyPointer ) {
        wrapped = try! .init(object: pyDict)
    }
    
    public func receive(completion: Subscribers.Completion<Never>) {
        Swift.print("\(self.self).receive(completion: \(completion))")
        subscribers.removeAll { s in
            if s.combineIdentifier.hashValue == completion.hashValue {
                Swift.print("removing subscriber - id:\n\t\(s.combineIdentifier)\n\t\(s)")
                return true
            }
            return false
        }
    }
    
    public func receive(_ input: Action) -> Subscribers.Demand {
        //Swift.print(self, "receive", input)
        switch input {
        case .new(let value):
            wrapped = value
            for s in subscribers { _ = s.receive(input) }
        case .update(let newValues):
            wrapped.merge(newValues) { _, new in
                return new
            }
            for s in subscribers { _ = s.receive(input) }
        case .add(let key, let value):
            wrapped[key] = value
            for s in subscribers { _ = s.receive(input) }
        case .delete(let key):
            fatalError()
        case .none:
            return .none
        }
        return .none
    }
    
    public func receive(subscription: Subscription) {
        subscription.request(.unlimited)
        Swift.print("\(self.self).receive(subscription: \(subscription))")
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, ObservableDictionary.Action == S.Input {
        subscribers.append(.init(subscriber))
        Swift.print("adding subscriber - id:\n\t\(subscriber.combineIdentifier)\n\t\(subscriber)\n\t\(subscribers)")
    }
    public func request() {
        Swift.print(self, subscribers)
        for s in subscribers {
            _ = s.receive(.new(value: wrapped))
        }
    }
}


extension ObservableDictionary: PyEncodable {
    public var pyObject: PythonSwiftCore.PythonObject {
        .init(getter: pyPointer)
    }
    
    public var pyPointer: PythonSwiftCore.PyPointer {
        wrapped.pyDict
    }
}


public protocol PyBuildObject {
    
}

public protocol PyBuildingSyntax {
    
    func addToModule(_ m: PyPointer)
}

public struct PyConstant<Constant>: PyBuildingSyntax {
    
    let name: String
    let value: Constant
    
    public init(name: String, _ value: Constant) where Constant == String {
        self.name = name
        self.value = value
    }
    
    public init(name: String, _ value: Constant) where Constant == Int {
        self.name = name
        self.value = value
    }
    public func addToModule(_ m: PyPointer) {
        switch value {
        case let str as String:
            PyModule_AddStringConstant(m, name, str)
        case let int as Int:
            PyModule_AddIntConstant(m, name, int)
        default: break
        }
    }
}

public struct ModulePySwiftObject<T: PyEncodable>: PyBuildingSyntax {
    
    public func addToModule(_ m: PyPointer) {
        
    }
}


extension UnsafeMutablePointer: PyBuildingSyntax where Pointee: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
    }
}
extension PyMethodDefWrap: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
        
    }
}
extension PyMethodDef: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
        fatalError()
    }
}
extension PyTypeObject: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
        fatalError()
    }
}
extension PySwiftModuleImport: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
        fatalError()
    }
}

public typealias PyMethodsPointer = UnsafeMutablePointer<PyMethodDef>?
@resultBuilder
public struct _PyModuleBuilder {
    
    public static func buildBlock(_ components: PyBuildingSyntax...) -> ([PyBuildingSyntax]) {
        components
    }
    
}


public final class PySwiftModule: PyBuildingSyntax {
    public func addToModule(_ m: PyPointer) {
        PyModule_AddObject(m, name, module )
    }
    
    public let module: PyPointer
    public let name: String
    //let methods_ptr: PyMethodsPointer
    public var swift_methods: [PyMethodDef] = []
    //var items: [PyMethodDefWrap]
    var pyMethodNamesStorage: [UnsafePointer<CChar>] = []
    public init(_ name: String, @_PyModuleBuilder input: () -> ([PyBuildingSyntax]) ) {
        self.name = name
        
        let m = PyImport_AddModule(name)!
        
        var methods: [PyMethodDefWrap] = []
        
        
        for component in input() {
            switch component {
            case let method as PyMethodDefWrap:
                methods.append(method)
            case let type as UnsafeMutablePointer<PyTypeObject>:
                PyModule_AddType(m, type)
            case let methods as UnsafeMutablePointer<PyMethodDef>:
                PyModule_AddFunctions(m, methods)
            default: component.addToModule(m)
            }
        }
        //let methods_ptr: PyMethodsPointer
        let method_count = methods.count
        if method_count > 0 {
            //methods_ptr = .allocate(capacity: method_count + 1)
            //for method in methods { methods_ptr?.advanced(by: 1).pointee = method.pyMethod }
            for method in methods {
                method.auto_deallocate = false
                swift_methods.append(method.pyMethod)
                pyMethodNamesStorage.append(method.method_name)
            }
            swift_methods.append(.init())
            //methods_ptr?.advanced(by: 1).pointee = .init()
            PyModule_AddFunctions(m, &swift_methods)
        }
        self.module = m
        //self.methods_ptr = methods_ptr
        //self.items = methods
        
    }
    
}


