#SingleInstance Force

#Requires AutoHotkey v2.0

#Include ..\AutoHotUnit.ahk

ahu.RegisterSuite(AssertEqualStructureSuite)

class AssertEqualStructureSuite extends AutoHotUnitSuite {
    isDisabled(testMethodName) {
        return false
    }

    compareLineEndings() {
        OutputDebug("Dieser Test schlägt fehl, weil der eine string ein '``r' enthält und der andere nicht.")
        this.assert.assertEqualStructure("line1`r`nline2", "line1`nline2")
    }

}

