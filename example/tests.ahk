#SingleInstance Force
SendMode("Input")
#Warn

; Include AutoHotUnit. The path will be different on your system.
#Include ..\AutoHotUnit.ahk

; Include each test file
; See individual test files for more information
#Include math.test.ahk

#Include other.test.ahk

; Run all test suites
ahu.RunSuites()

; To execute all tests from the command line, use the following command:
; autohotkey tests.ahk | echo
; The echo is required in order to print output to the terminal.
