#SingleInstance Force

#Requires AutoHotkey v2.0

class OtherSuite extends AutoHotUnitSuite {
    isDisabled(testMethodName) {
        return testMethodName = 'dyntest_2'
    }

    __New() {
        /**
         * @param {String} name 
         * @param {OtherSuite} suite 
         */
        dynTestFunc(name, suite) {
            ahu.reporter.printLine("this is dynamic test " name)
            suite.assert.isFalse(InStr(name, "4"))
        }
        loop 5 {
            testName := "dyntest_" A_Index
            this.registerTest(testName, dynTestFunc.Bind(testName, this))
        }
    }

    isTest(testName) {
        if testName = 'test_notReallyATest' {
            OutputDebug("considering " testName " to not be a test method`n")
            return false
        }
        return super.isTest(testName)
    }

    test_notReallyATest() {
        throw "This test should not be called."
    }

    test_exampleSucc() {
        OutputDebug("Dieser Test läuft erfolgreich :-)")
        this.assert.equal("Apple", "Apple")
    }

    test_exampleFail() {
        OutputDebug("Dieser Test schlägt fehl :-(")
        this.assert.equal("Apple", "Orange")
    }

    test_exampleError() {
        OutputDebug("Dieser Test wirft eine ausnahme. >:O")
        throw Error("this is the error message", -1, "this is the error extra")
    }

    test_compareLineEndings() {
        OutputDebug("Dieser Test schlägt fehl, weil der eine string ein '``r' enthält und der andere nicht.")
        this.assert.assertEqualStructure("line1`r`nline2", "line1`nline2")
    }
}