#Requires AutoHotkey v2.0
#Warn
; ^ Enable warnings to assist with detecting common errors.
#SingleInstance Force
; ^ Force new executions to replace the script's running process (if any)
SendMode("Input")
; ^ Recommended for new scripts due to its superior speed and reliability. (https://www.autohotkey.com/docs/v2/lib/SendMode.htm#ExBasic)
FileEncoding('UTF-8')
; ^ To allow for umlauts in window titles etc.
; ----------<

; Include AutoHotUnit. The path will be different on your system.
#Include ..\AutoHotUnit.ahk

; Include each test file (See individual test files for more information)
#Include math.test.ahk
#Include other.test.ahk

/** A random class which should not be able to be registered as a test suite, because it does not inherit from {@link AutoHotUnitSuite}. */
class RandomClass {
}
try {
    OutputDebug("trying to register a random class (should fail)`n")
    ahu.RegisterSuite(RandomClass)
} catch Error as err {
    OutputDebug("trying to register a random class failed as expected: " err.Message "`n")
}
else {
    throw Error("trying to register a random class should have thrown an error but it didn't!?")
}

; Register the test suites with AutoHotUnit..
ahu.RegisterSuite(MathSuite, OtherSuite)

; Run all test suites
try {
    ahu.PrintStackTrace := true
    ahu.Verbose := true
    OutputDebug("running test suites`n")
    ahu.RunSuites()
    OutputDebug("done running test suites`n")
} catch AutoHotUnitAbortSignal as abort {
    OutputDebug("received AHU abort message: " abort.Message "`n")
}

; To execute all tests from the command line, use the following command:
; autohotkey tests.ahk | echo
; The echo is required in order to print output to the terminal.
