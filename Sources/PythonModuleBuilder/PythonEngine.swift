//
//  PythonHandler.swift
//  touchBay editor
//
//  Created by MusicMaker on 04/11/2022.
//

import Foundation
import PythonLib
import PythonSwiftCore
//import SwiftyMonaco
import Combine
import SwiftUI


public class PythonEngine: ObservableObject {
    
    public static let shared = PythonEngine(imports: {})
    var threadState: UnsafeMutablePointer<PyThreadState>?
    
    public var python_module: PyPointer?
    public var globals: PyPointer?
    //var fusedGlobals: FusedDict
    
    //public var globals_dictionary: ObservableDictionary?
    @Published public var main_globals: DictionaryPyPointer = [:]
    var err_io: PythonObject?
    
    var extra_modules: [String:PyPointer] = [:]
    
    var builtins: PyPointer?
    //var stderr: PyObject
    var custom_functions: [PyModuleCustomFunctions] = []
    
    public var swiftonize_imports: [PySwiftModuleImport]?
    
    public init(file: URL? = nil, @PySwiftModuleImports imports: @escaping ()->[PySwiftModuleImport] ) {
        let resourcePath = Bundle.main.resourcePath!
        //print(try! FileManager.default.contentsOfDirectory(atPath: resourcePath))
        var config: PyConfig = .init()
        Swift.print("Configuring isolated Python...")
        PyConfig_InitIsolatedConfig(&config)
        
        // Configure the Python interpreter:
        // Run at optimization level 1
        // (remove assertions, set __debug__ to False)
        config.optimization_level = 1
        // Don't buffer stdio. We want output to appears in the log immediately
        config.buffered_stdio = 0
        // Don't write bytecode; we can't modify the app bundle
        // after it has been signed.
        config.write_bytecode = 0
        // Isolated apps need to set the full PYTHONPATH manually.
        config.module_search_paths_set = 1
        
        var status: PyStatus
        
        let python_home = "\(resourcePath)/Support/Python/Resources"
        
        var wtmp_str = Py_DecodeLocale(python_home, nil)
        
        var config_home: UnsafeMutablePointer<wchar_t>!// = config.home
        
        status = PyConfig_SetString(&config, &config_home, wtmp_str)
        
        PyMem_RawFree(wtmp_str)
        
        config.home = config_home
        
        status = PyConfig_Read(&config)
        
        Swift.print("PYTHONPATH:")
        
        let path = "\(resourcePath)/Support/Python/Resources/lib/python3.10"
        //let path = "\(resourcePath)/"
        
        Swift.print("- \(path)")
        wtmp_str = Py_DecodeLocale(path, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str)
        
        
        
        PyMem_RawFree(wtmp_str)
        let _imports = imports()
        for imp in _imports {
            PyImport_AppendInittab(imp.name, imp.module)
        }
        swiftonize_imports = _imports
        
        Swift.print("Initializing Python runtime...")
        status = Py_InitializeFromConfig(&config)
        

        builtins = PyEval_GetBuiltins()
        
        if let file = file {
            fileToModule(url: file, locals: nil)
        }
//        let _globals = PyModule_GetDict(__main__.module)!
//        globals = _globals
//        globals_dictionary = .init(nil)
        
    }
    
    
    
    public func requestGlobals() {
        Swift.print(self, "requesting globals")
//        /globals_dictionary?.request()
    }
    
    private func fileToModule(url: URL, locals: PyPointer?) {
        if
            let g = PyDict_New(),
            let l: PyPointer = ( (locals == nil) ? PyDict_New() : locals )
        {
            let m = PyRun_URL(url: url, flag: .file, globals: g, locals: l)
            python_module = m
            main_globals = try! .init(object: g)
            l.decref()
            g.decref()
        }
        
    }
    
    deinit {
        Py_Finalize()
    }
}


extension PythonEngine {
    public func withCustomModule(_ module: PySwiftModule) -> PythonEngine {
        do {
            let m = module.module
            
            let g = PyModule_GetDict(m)!
            self.main_globals = try .init(object: g)
            self.python_module = m
            
        } catch _ {
            PyErr_Print()
        }
        return self
    }
}

private let python_handler = PythonEngine.shared

public let pythonPrint = PyDict_GetItemString(python_handler.builtins, "print")
public let pyPrint = pythonPrint
public let pythonDir = PyDict_GetItemString(python_handler.builtins, "print")

private struct PythonHandlerKey: EnvironmentKey {
    static var defaultValue: PythonEngine = .shared
}

public extension EnvironmentValues {
    var pythonInstance: PythonEngine {
        get { self[PythonHandlerKey.self] }
        set { self[PythonHandlerKey.self] = newValue }
    }
    var pythonGlobals: ObservableDictionary? {
        nil
        //pythonInstance.globals_dictionary
    }
    
}
