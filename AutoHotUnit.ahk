#SingleInstance Force
#Warn All, StdOut
FileEncoding("UTF-8")
#Include <Join>

/**
 * The global AutoHotUnitManager instance. Use this to register and start test suites.
 */
global ahu := AutoHotUnitManager(AutoHotUnitCLIReporter())

/**
 * The base class for all AHU suites. Child classes must be registered with a AHU manager instance {@link ahu}.
 */
class AutoHotUnitSuite {
    /**
     * A collection of assert functions to be used during testing.
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
     * @param {String} testName The name of the test. The default implementation returns false for everything. This may be overridden by child classes.
     * @param {Func} testFunc The test function as registered.
     * @returns {Integer} True, if the test should be skipped.
     */
    isDisabled(testName, testFunc) {
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

/**
 * A central access point for registering and running AHU suites. A global instance of this class is provided as {@link ahu}.
 */
class AutoHotUnitManager {
    /** The list of registered test suite classes. */
    registeredTestSuites := Map()

    /** The test methods which are registered directly. */
    registeredTestFuncs := Map()

    /** Wether or not to give verbose output. */
    Verbose := false

    /** @type {AutoHotUnitCLIReporter} */
    reporter := ''

    /** Weather or not to abort early when an unexpected error is encountered (i.e. not just a failed assertion). This implies `PrintStackTrace`. */
    AbortOnError := false

    /** Weather or not to print the stack trace of unexpected errors. This is overridden by `AbortOnError`. */
    PrintStackTrace := false

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
        if not this.registeredTestSuites.Has(suiteName) {
            throw ValueError("not a registered test suite", -2, suite)
        }
        if ( not this.registeredTestFuncs.Has(suiteName)) {
            this.registeredTestFuncs.Set(suiteName, Map())
        }
        testFuncDict := this.registeredTestFuncs.Get(suiteName)
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
            this.registeredTestSuites.Set(subclass.Prototype.__Class, subclass)
        }
    }

    isProtectedProp(propName) {
        static protectedProps := Map()
        if not protectedProps.Count {
            for pName in ["beforeAll", "beforeEach", "afterEach", "afterAll", "isDisabled", "isTest", "__Class"] {
                protectedProps.Set(pName, true)
            }
        }
        return protectedProps.Has(propName)
    }

    /**
     * Runs all registered test suites in any order.
     */
    RunSuites() {
        try { ; <- try to catch abort signals
            this.reporter.onRunStart()
            for suiteName, suiteClass in this.registeredTestSuites {
                /** An instance of the test suite to be executed. */
                suiteInstance := suiteClass()

                this.reporter.onSuiteStart(suiteName)

                /** All the tests to execute. These are gathered from the test suite's method members as well as any explicitly registered test functions. */
                gatheredTests := Map()

                ; > loop over the test suite's properties to collect the test methods..
                for propertyName in suiteInstance.base.OwnProps() {
                    ; If the property name is one of the suite base class methods, skip it
                    if this.isProtectedProp(propertyName) {
                        continue
                    }

                    if not suiteInstance.isTest(propertyName) {
                        continue
                    }

                    propVal := GetMethod(suiteInstance, propertyName)
                    if (propVal is Func) {
                        gatheredTests.Set(propertyName, propVal.Bind(suiteInstance))
                    }
                }

                /** Add any test functions, that were explicitly registered for this test suite. */
                if (this.registeredTestFuncs.Has(suiteName)) {
                    for testName, testFunc in this.registeredTestFuncs.Get(suiteName) {
                        if gatheredTests.Has(testName) {
                            throw Error("the dynamically registered test '" testName "' clashed with the identically named instance member test method " suiteName "." testName)
                        }
                        gatheredTests.Set(testName, testFunc)
                    }
                }
                ; ! all tests are gathered -> start testing.

                try {
                    suiteInstance.beforeAll()
                } catch Error as e {
                    this.reporter.onTestResult("beforeAll", "failed", { error: e })
                    continue
                }

                if not gatheredTests.Count {
                    this.reporter.printLine("(no tests have been registered yet!)", "red")
                } else {
                    ; skipRemainingTests() {
                    ;     this.reporter.printLine("skipping remaining tests")
                    ; }
                    for testName, testFunc in gatheredTests {
                        if suiteInstance.isDisabled(testName, testFunc) {
                            this.reporter.onTestResult(testName, 'skipped')
                            continue
                        }

                        try {
                            suiteInstance.beforeEach()
                        } catch Error as e {
                            this.reporter.onTestResult(testName, "failed", { where: "beforeEach", error: e })
                            continue
                        }

                        try {
                            this.reporter.onTestStart(testName)
                            testFunc()
                        } catch Error as e {
                            this.reporter.onTestResult(testName, "failed", { where: "test", error: e })
                            continue
                        }

                        try {
                            suiteInstance.afterEach()
                        } catch Error as e {
                            this.reporter.onTestResult(testName, "failed", { where: "afterEach", error: e })
                            continue
                        }

                        this.reporter.onTestResult(testName, "passed")
                    }
                }

                try {
                    suiteInstance.afterAll()
                } catch Error as e {
                    this.reporter.onTestResult("afterAll", "failed", { error: e })
                    continue
                }

                this.reporter.onSuiteEnd(suiteName)
            } ; loop over suites
            this.reporter.onRunEnd()
        } catch AutoHotUnitAbortSignal as e {
            ; ! the tests where aborted, the error is already printed to the console -> exit.
            this.reporter.printLine("(tests where interrupted early)", "red")
        }
    }
}

/**
 * A reporter class that handles messaging (logging) for test suite execution.
 */
class AutoHotUnitCLIReporter {

    class Results {
        __New(name) {
            this.name := name
        }
        name := ""
        skipList := []
        failList := []
        succList := []
    }

    /**
     * Suite results for all test suites.
     * @type {AutoHotUnitCLIReporter.Results[]}
     */
    allSuiteResults := ''

    /**
     * An object holding  information about the active test suite.
     * @type {AutoHotUnitCLIReporter.Results}
     */
    activeSuiteResults := ''

    /**
     * Prints the given text to the console, optionally applying ansi color codes.
     * @See https://misc.flogisoft.com/bash/tip_colors_and_formatting
     * @param str The text to print.
     * @param {'green'|'red'|'yellow'} color The color to use.
     */
    printLine(str, color := '') {
        static ansiCodes := { red: "[31m", green: "[32m", reset: "[0m" }
        if color {
            colCode := ansiCodes.%color%
            str := colCode StrReplace(str, "`n", "`n" colCode) ansiCodes.reset
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
        this.printLine("Starting test run")
        this.allSuiteResults := []
    }

    onSuiteStart(suiteName) {
        this.printLine("Starting test suite " suiteName "")
        if (this.activeSuiteResults) {
            this.allSuiteResults.Push(this.activeSuiteResults)
        }
        this.activeSuiteResults := AutoHotUnitCLIReporter.Results(suiteName)
    }

    onTestStart(testName) {
        this.printLine("Starting test '" testName "'")
    }

    /**
     * 
     * @param {String} testName The name of the test method.
     * @param {'passed'|'failed'|'skipped'} status The status of the test result.
     * @param {Object} [info] Additional information (especially for errors).
     * @param {String} [info.where] Where the error was thrown. 
     * @param {Error} [info.error] The error object.
     */
    onTestResult(testName, status, info := {}) {
        static infoBase := { error: '', where: '' }
        info.Base := infoBase

        static prColors := Map('passed', 'green', 'failed', 'red', 'skipped', '')
        static statusSymbols := Map('passed', '✓', 'failed', '✕', 'skipped', '↷')

        statusSymbol := statusSymbols.Get(status)
        prColor := prColors.Get(status)

        static spaceStr := "`s`s"
        static indentMsg(s) {
            static indentation := spaceStr " >| "
            return StrReplace(indentation s, "`n", "`n" indentation)
        }

        switch status {
            default:
                throw ValueError("invalid status: " . status, -1, status)
            case 'passed':
                shortMsg := statusSymbol " " testName " passed"
                this.printLine(spaceStr shortMsg, prColor)
                fullMsg := this.activeSuiteResults.name "." shortMsg
                this.activeSuiteResults.succList.Push(fullMsg)
            case 'skipped':
                shortMsg := statusSymbol " " testName " was skipped"
                this.printLine(spaceStr shortMsg, prColor)
                fullMsg := this.activeSuiteResults.name "." shortMsg
                this.activeSuiteResults.skipList.Push(fullMsg)
            case 'failed':
                err := info.error
                isAssertionError := err is AutoHotUnitAssertError
                ; > print the error's class name if it was an unexpected one
                errTypeInfo := (isAssertionError) ? ("") : ("[" Type(err) "] ")
                errMsg := err.Message . (err.Extra = '' ? "" : " (Specifically: '" err.Extra "')")
                indentedErrMsg := indentMsg(errTypeInfo errMsg)
                ; > print the message right now (live)..
                this.printLine(indentedErrMsg, prColor)
                ; > store the message for the final summary at the end..
                fullMsg := this.activeSuiteResults.name "." testName " " info.where " failed:`n" indentedErrMsg
                this.activeSuiteResults.failList.Push(fullMsg)

                if ( not isAssertionError) {
                    ; ! we encountered an unexpected error!
                    if (ahu.PrintStackTrace or ahu.AbortOnError) {
                        ; > print the stack trace
                        this.printLine("Stack Trace:`n" err.Stack "`n")
                    }

                    if (ahu.AbortOnError) {
                        ; > abort the test run here, since a hard error was encountered.
                        throw AutoHotUnitAbortSignal()
                    }
                }
        } ; switch on status
    }

    onSuiteEnd(suiteName) {
        this.printLine("Ending test suite '" suiteName "'")
    }

    onRunEnd() {
        if this.activeSuiteResults {
            this.allSuiteResults.Push(this.activeSuiteResults)
            this.activeSuiteResults := ''
        }
        asr := this.allSuiteResults
        this.allSuiteResults := ''

        sumSkipCount := 0
        sumFailCount := 0
        sumSuccCount := 0
        for suiteResults in asr {
            skipCount := suiteResults.skipList.Length
            failCount := suiteResults.failList.Length
            succCount := suiteResults.succList.Length
            totalCount := skipCount + failCount + succCount

            this.printLine("suite summary " suiteResults.name
                ": " failCount "/" totalCount " failed"
                ", " skipCount "/" totalCount " skipped"
                ", " succCount "/" totalCount " succeeded"
            )

            sumSkipCount += skipCount
            sumFailCount += failCount
            sumSuccCount += succCount

            for failMsg in suiteResults.failList {
                this.printLine(failMsg, "red")
            }
        }
        sumTotalCount := sumSkipCount + sumFailCount + sumSuccCount

        this.printLine("full summary (all suites)"
            ": " sumFailCount "/" sumTotalCount " failed"
            ", " sumSkipCount "/" sumTotalCount " skipped"
            ", " sumSuccCount "/" sumTotalCount " succeeded"
        )
    }
}

/**
 * A collection of assert functions to be used by test suites. The test suite base class has an instance at field {@link AutoHotUnitSuite#assert}.
 */
class AutoHotUnitAsserter {

    /**
     * 
     * @param actual 
     * @param expected 
     * @returns {Integer} 
     */
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
            str := StrReplace(str, "`t", "``t")
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

/**
 * An error class representing assertion errors. Instances of this class are thrown by assertion functions ({@link AutoHotUnitAsserter}).
 */
class AutoHotUnitAssertError extends Error {
}

/**
 * An instance of this class may be thrown during test execution, to abort it early. The {@link AutoHotUnitManager} will catch the exception and print a warning before exiting (without re-throwing). See also {@link AutoHotUnitManager#AbortOnError}.
 */
class AutoHotUnitAbortSignal extends Error {
}