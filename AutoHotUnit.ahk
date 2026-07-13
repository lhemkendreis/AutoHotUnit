#SingleInstance Force
#Warn All, StdOut
FileEncoding("UTF-8")
#Include <Join>


global ahu := AutoHotUnitManager(AutoHotUnitCLIReporter())

class AutoHotUnitSuite {
    /**
     * @type {AutoHotUnitAsserter}
     */
    assert := AutoHotUnitAsserter()

    /**
     * Executed once before any tests execute.
     */
    beforeAll() {
    }

    /**
     * Executed once before each test is executed.
     */
    beforeEach() {
    }

    /**
     * Executed once after each test is executed.
     */
    afterEach() {
    }

    /**
     * Executed once after all tests have executed.
     */
    afterAll() {
    }

    /**
     * Execute once for each test, to determine weather or not it should be skipped. 
     * @param testName The name of the test. The default implementation returns false for everything. This may be overridden by child classes.
     * @returns {Integer} True, if the test should be skipped.
     */
    isDisabled(testName) {
        return false
    }

    /**
     * Executes once for each potential test method found on the test suite. Should return a true value, if the given method name should be considered a test. The default implementation returns true if the given method name starts with "test". This may be overridden by child classes.
     * @param methName The name of the test method.
     * @returns {Bool} True, if the method should be considered a test.
     */
    isTest(methName) {
        return SubStr(methName, 1, 4) = "test"
    }

    /**
     * Registers the given function as a test under the given name.
     * @param name The name of the test.
     * @param func The body of the test.
     */
    registerTest(name, func) {
        ahu.registerTest(this, name, func)
    }
}

class AutoHotUnitManager {
    /** The list of registered test suite classes. */
    testSuiteDict := Map()
    /** The test methods  */
    testFuncDict := Map()

    /** Wether or not to give verbose output. */
    Verbose := false

    /**
     * Creates a new AHU instance with the given reporter.
     * @param {AutoHotUnitCLIReporter} reporter The reporter instance, which writes handles ouptut messages.
     */
    __New(reporter) {
        this.reporter := reporter
    }

    /**
     * Registers a test function under the given test 
     * @param suite The test suite for which to register the test.
     * @param name The name of the test.
     * @param func The body of the test.
     * @protected This method is called internally by {@link AutoHotUnitSuite#registerTest}.
     */
    registerTest(suite, name, func) {
        suiteName := suite.__Class
        if not this.testSuiteDict.Has(suiteName) {
            throw ValueError("not a registered test suite", -2, suite)
        }
        if ( not this.testFuncDict.Has(suiteName)) {
            this.testFuncDict.Set(suiteName, Map())
        }
        testFuncDict := this.testFuncDict.Get(suiteName)
        if testFuncDict.Has(name) {
            throw ValueError("test suite " suiteName " already has a test function registered under the name '" name "'")
        }
        testFuncDict.Set(name, func)
    }

    /**
     * Registers the given subclasses as test suites.
     * @param {AutoHotUnitSuite} SuiteSubclasses One or more subclasses to register.
     */
    RegisterSuite(SuiteSubclasses*)
    {
        for subclass in SuiteSubclasses {
            if (Type(subclass) != "Class") {
                throw TypeError("expected class but got " Type(subclass), -2, subclass)
            }
            if ( not subclass.HasBase(AutoHotUnitSuite)) {
                throw TypeError("expected AutoHotUnitSuite but got " subclass.Prototype.__Class)
            }
            this.testSuiteDict.Set(subclass.Prototype.__Class, subclass)
        }
    }

    /** @type {AutoHotUnitCLIReporter} */
    reporter := ''

    /** Weather or not to abort early when an unexpected error is encountered (i.e. not just a failed assertion). This implies `PrintStackTrace`. */
    AbortOnError := false

    /** Weather or not to print the stack trace of unexpected errors. This is overridden by `AbortOnError`. */
    PrintStackTrace := false

    /**
     * Runs all registered test suites in order.
     */
    RunSuites() {
        static protectedProps := Map()
        if not protectedProps.Count {
            for pName in ["beforeAll", "beforeEach", "afterEach", "afterAll", "isDisabled", "isTest"] {
                protectedProps.Set(pName, true)
            }
        }

        try { ; <- try to catch abort signals
            this.reporter.onRunStart()
            for suiteName, suiteClass in this.testSuiteDict {
                suiteInstance := suiteClass()
                this.reporter.onSuiteStart(suiteName)

                testFuncDict := Map()
                for propertyName in suiteInstance.base.OwnProps() {
                    ; If the property name is one of the suite base class methods, skip it
                    if protectedProps.Has(propertyName) {
                        continue
                    }

                    if not suiteInstance.isTest(propertyName) {
                        continue
                    }

                    propVal := GetMethod(suiteInstance, propertyName)
                    if (propVal is Func) {
                        testFuncDict.Set(propertyName, propVal.Bind(suiteInstance))
                    }
                }

                if (this.testFuncDict.Has(suiteName)) {
                    for testName, testFunc in this.testFuncDict.Get(suiteName) {
                        if testFuncDict.Has(testName) {
                            throw Error("the dynamically registered test '" testName "' clashed with the identically named instance member test method " suiteName "." testName)
                        }
                        testFuncDict.Set(testName, testFunc)
                    }
                }

                try {
                    suiteInstance.beforeAll()
                } catch Error as e {
                    this.reporter.onTestResult("beforeAll", "failed", "", e)
                    continue
                }

                if not testFuncDict.Count {
                    this.reporter.printLine("(no tests have been registered yet!)", "red")
                } else {
                    for testName, testFunc in testFuncDict {
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
                            this.reporter.onTestStart(testName)
                            testFunc()
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
        } catch AutoHotUnitAbortSignal as e {
            ; ! the tests where aborted, the error is already printed to the console -> exit.
            this.reporter.printLine("(tests where interrupted early)", "red")
        }
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
        ; TODO use my AnsiColorPrinter instead
        if IsSet(color) {
            colCode := this.%color%
            str := colCode str this.reset
        }
        try {
            FileAppend(str "`n", "*", "UTF-8 `n")
        } catch Error as err {
            throw Error("The standard output handle (*) is not valid."
                . "`nYou may need to pipe the output to another command (e.g. echo),"
                . " to prevent this error.", -1, err.Message)
        }
    }

    onRunStart() {
        this.printLine("Starting test run`r`n")
    }

    onSuiteStart(suiteName) {
        this.printLine("starting test suite " suiteName "")
        this.currentSuiteName := suiteName
    }

    onTestStart(testName) {
        this.printLine("Starting test '" testName "'")
    }

    /**
     * 
     * @param {String} testName The name of the test method.
     * @param {'passed'|'failed'} status The status of the test result. Either 'passed' or 'failed'.
     * @param {String} where Where the error was thrown. 
     * @param {Error} error The error object.
     */
    onTestResult(testName, status, where, error) {
        if (status != "passed" && status != "failed") {
            throw Error("Invalid status: " . status)
        }

        prColor := (status == "failed") ? "red" : "green"
        prefix := (status == "failed") ? "✕" : "✓"

        this.printLine("  " prefix " " testName " " status, prColor)

        indentMsg(s) {
            static indentation := "   >| "
            return StrReplace(indentation s, "`n", "`n" indentation)
        }

        if (status == "failed") {
            isAssertionError := error is AutoHotUnitAssertError
            ; > print the error's class name if it was an unexpected one
            errTypeInfo := (isAssertionError) ? ("") : ("[" Type(error) "] ")
            errMsg := error.Message . (error.Extra = '' ? "" : " (Specifically: '" error.Extra "')")
            indentedErrMsg := indentMsg(errTypeInfo errMsg)
            ; > print the message right now (live)..
            this.printLine(indentedErrMsg, prColor)
            ; > store the message for the final summary at the end..
            this.failures.push(this.currentSuiteName "." testName " " where " failed:`n" indentedErrMsg)

            if ( not isAssertionError) {
                ; ! we encountered an unexpected error!
                if (ahu.PrintStackTrace or ahu.AbortOnError) {
                    ; > print the stack trace
                    this.printLine("Stack Trace:`n" error.Stack "`n")
                }

                if (ahu.AbortOnError) {
                    ; > abort the test run here, since a hard error was encountered.
                    throw AutoHotUnitAbortSignal()
                }
            }
        }
    }

    onSuiteEnd(suiteName) {
        this.printLine("ending test suite '" suiteName "'")
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
            this.printLine(failure, "red")
        }

        Exit(this.failures.Length)
    }
}

class AutoHotUnitAsserter {
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
            throw AutoHotUnitAssertError("Assertion failed: " . AutoHotUnitAsserter.getPrintableValue(actual) . " != " . AutoHotUnitAsserter.getPrintableValue(expected))
        }
    }

    notEqual(actual, expected) {
        if (actual == expected) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " == " . expected)
        }
    }

    isTrue(actual) {
        if (actual != true) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not true")
        }
    }

    isTruish(actual) {
        if ( not actual) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not truish")
        }
    }

    isFalse(actual) {
        if (actual != false) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not false")
        }
    }

    isFalsish(actual) {
        if (actual) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not falsish")
        }
    }

    isEmpty(actual) {
        if (actual != "") {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not empty")
        }
    }

    notEmpty(actual) {
        if (actual == "") {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is empty")
        }
    }

    fail(message) {
        throw AutoHotUnitAssertError("Assertion failed: " . message)
    }

    isAbove(actual, expected) {
        if (actual <= expected) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not above " . expected)
        }
    }

    isAtLeast(actual, expected) {
        if (actual < expected) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not at least " . expected)
        }
    }

    isBelow(actual, expected) {
        if (actual >= expected) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not below " . expected)
        }
    }

    isAtMost(actual, expected) {
        if (actual > expected) {
            throw AutoHotUnitAssertError("Assertion failed: " . actual . " is not at most " . expected)
        }
    }

    /**
     * Compares the given strcutures, asserting equality between them.
     * @param {AutoHotUnitSuite} this The test suite which is calling the function. This allows the function to act as a method, when assigned to one of the test suite's properties.
     * @param {Any} actual The actual value.
     * @param {Any} expected The expected value.
     */
    assertEqualStructure(actual, expected) {
        writeVerbose := (ahu.Verbose) ? OutputDebug : (text) => {}

        try {
            ; > start the recursive comparison...
            compareRecursively([], actual, expected)
        } catch AutoHotUnitAsserter.ComparisonError as e {
            ; ! the structures are not equal -> fail the assertion.
            throw AutoHotUnitAssertError(e.Message "`n --> " e.What)
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
            writeVerbose("comparing " getTrace() "`n")
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
                        writeVerbose("comparing array item #" index "`n")
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
                    writeVerbose("comparing values of scalar type " actType "`n")
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
                throw AutoHotUnitAsserter.ComparisonError(msg, getTrace(), { actValue: actValue, expValue: expValue })
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
            str := StrReplace(str, "`n", "``n")
            str := StrReplace(str, "`r", "``r")
            return str
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

class AutoHotUnitAssertError extends Error {
}

class AutoHotUnitAbortSignal extends Error {
}