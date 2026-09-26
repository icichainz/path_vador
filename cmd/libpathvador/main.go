// Command libpathvador builds the c-shared library the Flutter UI loads.
// See ui/ENGINE.md for the C ABI and the JSON protocol.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"unsafe"

	"github.com/icichainz/path_vador/internal/engine"
)

// pv_eval evaluates one JSON request. The caller releases the result with pv_free.
//
//export pv_eval
func pv_eval(req *C.char) *C.char {
	return C.CString(string(engine.Eval([]byte(C.GoString(req)))))
}

// pv_free releases a string returned by pv_eval.
//
//export pv_free
func pv_free(p *C.char) {
	C.free(unsafe.Pointer(p))
}

func main() {}
