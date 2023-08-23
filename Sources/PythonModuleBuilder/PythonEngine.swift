//
//  PythonHandler.swift
//  touchBay editor
//
//  Created by MusicMaker on 04/11/2022.
//

import Foundation
import PythonLib
import PythonSwiftCore

import Combine
import SwiftUI

public protocol PyConfigSyntax {}

extension URL: PyConfigSyntax {}
extension PySwiftModuleImport: PyConfigSyntax {}
extension PySwiftModule: PyConfigSyntax {}

@resultBuilder
public struct PyConfigBuilder {
    public static func buildBlock(_ components: PyConfigSyntax...) -> [PyConfigSyntax] {
        components
    }
}

public class PythonEngineConfiguration {
    
    public var main_file: URL?
    public var custom_swift_main: PySwiftModule?
    
    public var package_folders: [URL]
    public var pyswift_imports: [PySwiftModuleImport]
    
    public init(main_file: URL? = nil, swift_main: PySwiftModule? = nil, @PyConfigBuilder config: () -> [PyConfigSyntax]) {
        self.main_file = main_file
        self.custom_swift_main = swift_main
        var folders = [URL]()
        var pyswiftmods = [PySwiftModuleImport]()
        for item in config() {
            switch item {
            case let folder as URL:
                folders.append(folder)
            case let pyimport as PySwiftModuleImport:
                pyswiftmods.append(pyimport)
            default: continue
            }
        
        }
        
        
        self.package_folders = folders
        self.pyswift_imports = pyswiftmods
    }
}


public class PythonEngine: ObservableObject {
    
    public static let shared = PythonEngine()
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
    
    public var engineConfig: PythonEngineConfiguration?
    
    public init(config engineConfig: PythonEngineConfiguration? = nil ) {
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
        
        if let engineConfig = engineConfig {
            self.engineConfig = engineConfig
            
            for imp in engineConfig.pyswift_imports {
                PyImport_AppendInittab(imp.name, imp.module)
            }
            
            for package_folder in engineConfig.package_folders {
                let path = package_folder.path
                NSLog("- \(path)")
                wtmp_str = Py_DecodeLocale(path, nil)
                status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
                if ((PyStatus_Exception(status)) != 0) {
                    NSLog("Unable to set app packages path: \(String(cString: status.err_msg))")
                    PyConfig_Clear(&config);
                    Py_ExitStatusException(status);
                }
                PyMem_RawFree(wtmp_str);
            }
            //swiftonize_imports = _imports
        }
        
        
        Swift.print("Initializing Python runtime...")
        status = Py_InitializeFromConfig(&config)
        

        builtins = PyEval_GetBuiltins()
        
        if let file = engineConfig?.main_file {
            fileToModule(url: file, locals: nil)
        } else if let custom = engineConfig?.custom_swift_main {
            custom.build()
            addCustomModule(custom)
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
    
    fileprivate func addCustomModule(_ module: PySwiftModule) {
        do {
            let m = module.module
            
            let g = PyModule_GetDict(m)!
            self.main_globals = try .init(object: g)
            self.python_module = m
            
        } catch _ {
            PyErr_Print()
        }
    }
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
