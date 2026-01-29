#SingleInstance Force
#Warn All, StdOut
FileEncoding("UTF-8")
#Include <Join>


global ahu := AutoHotUnitManager(AutoHotUnitCLIReporter())

class AutoHotUnitSuite {
    Verbose := false

    assert := AutoHotUnitAsserter(this)

    ; Executed once before any tests execute
    beforeAll() {
    }

    ; Executed once before each test is executed
    beforeEach() {
    }

    ; Executed once after each test is executed
    afterEach() {
    }

    ; Executed once after all tests have executed
    afterAll() {
    }

    ; Execute once for each test, to determine weather or not it should be skipped
    isDisabled(testMethodName) {
        return false
    }
}

class AutoHotUnitManager {
    Suite := AutoHotUnitSuite
    suites := []

    __New(reporter) {
        this.reporter := reporter
    }

    RegisterSuite(SuiteSubclasses*)
    {
        for i, subclass in SuiteSubclasses {
            this.suites.push(subclass)
        }
    }

    /** @type {AutoHotUnitCLIReporter} */
    reporter := ''


    RunSuites() {
        this.reporter.onRunStart()
        for i, suiteClass in this.suites {
            suiteInstance := suiteClass()
            suiteName := suiteInstance.__Class
            this.reporter.onSuiteStart(suiteName)

            testNames := []
            for propertyName in suiteInstance.base.OwnProps() {
                ; If the property name starts with an underscore, skip it
                underScoreIndex := InStr(propertyName, "_")
                if (underScoreIndex == 1) {
                    continue
                }

                ; If the property name is one of the Suite base class methods, skip it
                if (propertyName == "beforeAll" || propertyName == "beforeEach" || propertyName == "afterEach" || propertyName == "afterAll" || propertyName == "isDisabled") {
                    continue
                }

                if (GetMethod(suiteInstance, propertyName) is Func) {
                    testNames.push(propertyName)
                }
            }

            try {
                suiteInstance.beforeAll()
            } catch Error as e {
                this.reporter.onTestResult("beforeAll", "failed", "", e)
                continue
            }

            for j, testName in testNames {
                if suiteInstance.isDisabled(testName) {
                    this.reporter.printLine("test '" testName "' is disabled -> skip", 'green')
                    continue
                }

                try {
                    suiteInstance.beforeEach()
                } catch Error as e {
                    this.reporter.onTestResult(testName, "failed", "beforeEach", e)
                    continue
                }

                try {
                    local method := GetMethod(suiteInstance, testName)
                    method(suiteInstance)
                } catch Error as e {
                    this.reporter.onTestResult(testName, "failed", "test", e)
                    continue
                }

                try {
                    suiteInstance.afterEach()
                } catch Error as e {
                    this.reporter.onTestResult(testName, "failed", "afterEach", e)
                    continue
                }

                this.reporter.onTestResult(testName, "passed", "", "")
            }

            try {
                suiteInstance.afterAll()
            } catch Error as e {
                this.reporter.onTestResult("afterAll", "failed", "", e)
                continue
            }

            this.reporter.onSuiteEnd(suiteName)
        }
        this.reporter.onRunComplete()
    }
}

class AutoHotUnitCLIReporter {
    currentSuiteName := ""
    failures := []
    ; @See https://misc.flogisoft.com/bash/tip_colors_and_formatting
    red := "[31m"
    green := "[32m"
    reset := "[0m"

    /**
     * 
     * @param str 
     * @param {'green'|'red'} color 
     */
    printLine(str, color := unset) {
        if IsSet(color) {
            colCode := this.%color%
            str := colCode str this.reset
        }
        FileAppend(str, "*", "UTF-8")
        FileAppend("`r`n", "*")
    }

    onRunStart() {
        this.printLine("Starting test run`r`n")
    }

    onSuiteStart(suiteName) {
        this.printLine(suiteName ":")
        this.currentSuiteName := suiteName
    }

    onTestStart(testName) {
    }

    onTestResult(testName, status, where, error) {
        if (status != "passed" && status != "failed") {
            throw Error("Invalid status: " . status)
        }

        prefix := this.green . "."
        if (status == "failed") {
            prefix := this.red . "x"
        }

        this.printLine("  " prefix " " testName " " status this.reset)
        if (status == "failed") {
            this.printLine(this.red "      " error.Message this.reset)
            this.failures.push(this.currentSuiteName "." testName " " where " failed:`r`n  " error.Message)
        }
    }

    onSuiteEnd(suiteName) {
    }

    onRunComplete() {
        this.printLine("")
        postfix := "All tests passed."
        if (this.failures.Length > 0) {
            postfix := this.failures.Length . " test(s) failed."
        }
        this.printLine("Test run complete. " postfix)

        if (this.failures.Length > 0) {
            this.printLine("")
        }

        for i, failure in this.failures {
            this.printLine(this.red failure this.reset)
        }

        Exit(this.failures.Length)
    }
}

class AutoHotUnitAsserter {

    __New(acitveSuite) {
        this.activeSuite := acitveSuite
    }

    activeSuite := 0x0

    static deepEqual(actual, expected) {
        if (actual is Array && expected is Array) {
            if (actual.Length != expected.Length) {
                return false
            }

            for i, actualItem in actual {
                if (!this.deepEqual(actualItem, expected[i])) {
                    return false
                }
            }

            return true
        }

        return actual == expected
    }

    static getPrintableValue(value) {
        if (value is Array) {
            str := "["
            for i, item in value {
                if (i > 1) {
                    str .= ", "
                }
                str .= this.getPrintableValue(item)
            }
            str .= "]"
            return str
        }

        return value
    }

    equal(actual, expected) {
        if (!AutoHotUnitAsserter.deepEqual(actual, expected)) {
            throw Error("Assertion failed: " . AutoHotUnitAsserter.getPrintableValue(actual) . " != " . AutoHotUnitAsserter.getPrintableValue(expected))
        }
    }

    notEqual(actual, expected) {
        if (actual == expected) {
            throw Error("Assertion failed: " . actual . " == " . expected)
        }
    }

    isTrue(actual) {
        if (actual != true) {
            throw Error("Assertion failed: " . actual . " is not true")
        }
    }

    isFalse(actual) {
        if (actual == true) {
            throw Error("Assertion failed: " . actual . " is not false")
        }
    }

    isEmpty(actual) {
        if (actual != "") {
            throw Error("Assertion failed: " . actual . " is not empty")
        }
    }

    notEmpty(actual) {
        if (actual == "") {
            throw Error("Assertion failed: " . actual . " is empty")
        }
    }

    fail(message) {
        throw Error("Assertion failed: " . message)
    }

    isAbove(actual, expected) {
        if (actual <= expected) {
            throw Error("Assertion failed: " . actual . " is not above " . expected)
        }
    }

    isAtLeast(actual, expected) {
        if (actual < expected) {
            throw Error("Assertion failed: " . actual . " is not at least " . expected)
        }
    }

    isBelow(actual, expected) {
        if (actual >= expected) {
            throw Error("Assertion failed: " . actual . " is not below " . expected)
        }
    }

    isAtMost(actual, expected) {
        if (actual > expected) {
            throw Error("Assertion failed: " . actual . " is not at most " . expected)
        }
    }

    /**
     * Compares the given strcutures, asserting equality between them.
     * @param {AutoHotUnitSuite} this The test suite which is calling the function. This allows the function to act as a method, when assigned to one of the test suite's properties.
     * @param {Any} actual The actual value.
     * @param {Any} expected The expected value.
     * @param {Bool} verbose Weather to print detailed log messages.
     */
    assertEqualStructure(actual, expected) {
        writeDebug := (this.activeSuite.Verbose) ? OutputDebug : (text) => {}
        ; ^ the caller can set the 'Verbose' property to enable logging

        try {
            ; > start the recursive comparison...
            compareRecursively([], actual, expected)
        } catch ComparisonError as e {
            ; ! the structures are not equal -> fail the assertion.
            this.assert.fail(e.Message "`n --> " e.What)
        }
        ; ^^^^^^ The function body ends here. What follows are just local functions.

        /**
         * Performs a recursive comparison of the given values, keeping track of the steps (path) taken into the structure.
         * @param {Array} steps The list of steps to navigate to the curret position in the structure. Steps are either "[<index>]" for array entries or ".<key>" for map entries.
         * @param actValue The actual value.
         * @param expValue The expected value.
         */
        compareRecursively(steps, actValue, expValue) {
            actType := Type(actValue)
            expType := Type(expValue)
            writeDebug("comparing " getTrace() "`n")
            if (actType != expType) {
                compErr("expected type is " expType (
                    IsNumber(expValue) ? " (" expValue ")" : ""
                ) ", but actual type is " actType (
                    IsNumber(actValue) ? " (" actValue ")" :
                    (actValue is String) ? ": " shortStrDesc(actValue) : ""
                ))
            }
            ; ! the type matches -> proceed, depending on which type it is..
            switch actType {
                case "Map":
                    ; > make sure every expected key is there..
                    for expKey, expItem in expValue {
                        if ( not actValue.Has(expKey)) {
                            compErr("expected key '" expKey "', but didn't find it")
                        }
                        ; > compare the value recursively..
                        actItem := actValue.Get(expKey)
                        compareRecursively(next(expKey), actItem, expItem)
                    }
                    ; > make sure no additional keys are there..
                    for actKey, actItem in actValue {
                        if ( not expValue.Has(actKey)) {
                            compErr("found unexpected key '" actKey "'")
                        }
                    }
                case "Array":
                    ; > make sure every expected value is there..
                    for index, expItem in expValue {
                        actItem := actValue[index]
                        writeDebug("comparing array item #" index "`n")
                        compareRecursively(next(index), actItem, expItem)
                    }
                    ; > make sure no additional values are present..
                    if (actValue.Length > expValue.Length) {
                        compErr("found unexpected additional array entries, starting at index " expValue.Length + 1)
                    }
                case "String":
                    ; > compare the strings..
                    if (actValue !== expValue) {
                        compErr("expected " expType "-value `"" densify(expValue) "`", but got `"" densify(actValue) "`"")
                    }

                case "Integer", "Float", "ComValue":
                    ; ^ (type ComValue may be expected to represent true/false/null)
                    ; > compare the scalar values..
                    writeDebug("comparing values of scalar type " actType "`n")
                    if (actValue != expValue) {
                        compErr("expected " expType "-value " String(expValue) ", but got " String(actValue))
                    }
                default:
                    ; ! this should not happen!
                    compErr("comparison of type '" actType "' is not implemented!")
            }
            ; ^^^^^^ The function body ends here. What follows are just local functions.

            /**
             * Throws a special error object so signal the failure of the comparison.
             * @param msg The message to throw.
             * @throws {ComparisonError} The created error object. The error's `What` property contains a description of where in the structure the comparison failed. 
             */
            compErr(msg) {
                throw ComparisonError(msg, getTrace(), { actValue: actValue, expValue: expValue })
            }

            /**
             * Returns a copy of the current step list, with the given next step added. 
             * @param nextStep The next step to add to the (cloned) list. Should be either the key (string) of a map entry or the index (integer) of an array entry. The function will then convert the value to either ".<key>" or "[<index>]" respectively.
             * @returns {Array} The extended copy of the current step list.
             */
            next(nextStep) {
                newStepList := steps.Clone()
                switch actType {
                    ; ^ we examine the type of the actual value at the current position in the structure
                    case "Array":
                        ; ! we are stepping into an array!
                        newStepList.Push('[' nextStep ']')
                    case "Map":
                        ; ! we are stepping into a map!
                        newStepList.Push('.' nextStep)
                    default:
                        ; ! this should not happen!
                        throw "unexpected type " actType
                }
                return newStepList
            }

            /**
             * Derives a description of the current position in the structure. I.e. a 'path' into the strucute.
             * @returns {String} A structure path pointing to the current position in the structure.
             */
            getTrace() {
                return "at level " steps.Length ": " (
                    (steps.Length = 0) ? "(the value itself)" : ("<VALUE>" Join("", steps*))
                ) " (type " actType ")"
            }
        }

        /**
         * Creates a dense version of the given string, by replacing newlines with "`n".
         * @param str The string to densify.
         * @returns {String} The densified string.
         */
        densify(str) {
            return StrReplace(str, "`n", "``n")
        }

        shortStrDesc(str) {
            len := StrLen(str)
            str := densify(str)
            if (len <= 50) {
                return "»" str "« (length " len ")"
            }
            return "the string value is »" SubStr(str, 1, 50) "…« (length " len ")"
        }
    }
    /**
     * This error class is used internally to signal an inequality, which should lead to a normal assertion fail.
     */
    class ComparisonError extends Error {
        ; (empty implmentation)
    }
}