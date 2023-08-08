// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation
#if BEEWARE
import PythonLib
import PythonSwiftCore
#endif

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
    let methods_ptr: PyMethodsPointer
    var items: [PyMethodDefWrap]
    public init(name: String, @_PyModuleBuilder input: () -> ([PyBuildingSyntax]) ) {
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
        let methods_ptr: PyMethodsPointer
        let method_count = methods.count
        if method_count > 0 {
            methods_ptr = .allocate(capacity: method_count + 1)
            for method in methods { methods_ptr?.advanced(by: 1).pointee = method.pyMethod }
            methods_ptr?.advanced(by: 1).pointee = .init()
            PyModule_AddFunctions(m, methods_ptr)
        } else {
            methods_ptr = nil
        }
        self.module = m
        self.methods_ptr = methods_ptr
        self.items = methods
        
    }
    
}


