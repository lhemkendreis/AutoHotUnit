#SingleInstance Force

#Include "math.ahk"

; Define your test suite, extending from the AutoHotUnitSuite class
class MathSuite extends AutoHotUnitSuite {

    isTest(methName) {
        static _ := ahu.reporter.printLine("the " this.__Class " consideres methods to be tests if the start with 'can'")
        return SubStr(methName,1,3) = "can"
    }

    canMultiplyCorrectly() {
        this.assert.equal(Multiply(5, 3), 15)
    }

    canAddCorrectly() {
        this.assert.equal(Add(1, 2), 3)
    }
}