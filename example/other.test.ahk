#SingleInstance Force

#Requires AutoHotkey v2.0

ahu.RegisterSuite(OtherSuite)

class OtherSuite extends AutoHotUnitSuite {
    isDisabled(testMethodName) {
        return false
    }

    exampleSuccTest() {
        OutputDebug("Dieser Test läuft erfolgreich :-)")
        this.assert.equal("Apple", "Apple")
    }

    exampleFailTest() {
        OutputDebug("Dieser Test schlägt fehl :-(")
        this.assert.equal("Apple", "Orange")
    }
    
    exampleErrorTest() {
        OutputDebug("Dieser Test wirft eine ausnahme. >:O")
        throw Error("this is the error message")
    }
}

