# PythonModuleBuilder


```swift

let __main__ = PySwiftModule(name: "__main__") {
    
    PyConstant(name: "hw", "hello_world") // add Str Constant
    PyConstant(name: "int_value", 1) // add Int Constant
    
    PyWidgetKnobType.pytype // PySwift Wrapped Object type added to module
    
    OscMessagePyType.pytype // Another type Added
    
    // function my_swift_func added to module
    PyMethodDefWrap(withArgs: "my_swift_func") { _, args, nargs in
        let result = GenericPyCFuncCall(args: args, count: nargs) { x, y, z in
            let _x: Double = x * 2.0
            let _y: Double = y * 10.0
            let _z: Double = z * 13.5
            
            return _x + _y + _z
        }
        return result?.pyPointer
    }
    
}
```
