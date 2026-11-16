#Requires AutoHotkey v2.0
#SingleInstance Force
#Include OCR.ahk

SendMode("Event")
CoordMode("Mouse", "Screen")

; --- DEFAULT CONFIGURATION VALUES ---
QuickHold := 60          ; Fast tap duration (ms)
PressHold := 2000        ; Shell press duration (ms)
ScanDelay := 70          ; OCR scan interval (ms)
SettleDelay := 150       ; Reduced default alignment wait (ms)

; --- OCR REGION ---
BoxX := 800
BoxY := 500
BoxW := 260
BoxH := 70
Step1Set := false
Toggle := false
LastPrompt := ""         ; Track last read text to prevent GUI lag
ActionLock := 0          ; Prevents duplicate spamming during animation

; --- CREATE THE SETTINGS UI ---
MyGui := Gui("+AlwaysOnTop", "Brass Hell - OCR Prompt Reader")
MyGui.SetFont("s10", "Segoe UI")

MyGui.Add("Text", "w175", "Quick E Hold (ms):")
EditQuick := MyGui.Add("Edit", "x+10 w80 Number", QuickHold)

MyGui.Add("Text", "xm w175", "Shell Press Hold (ms):")
EditPress := MyGui.Add("Edit", "x+10 w80 Number", PressHold)

MyGui.Add("Text", "xm w175", "OCR Scan Speed (ms):")
EditScan := MyGui.Add("Edit", "x+10 w80 Number", ScanDelay)

MyGui.Add("Text", "xm w175", "Machine Settle Delay (ms):")
EditSettle := MyGui.Add("Edit", "x+10 w80 Number", SettleDelay)

MyGui.Add("Text", "xm y+12 w290 cBlue", "--- Prompt Text Area Setup ---")
BtnSetBox := MyGui.Add("Button", "xm y+5 w290", "Set Text Box Corners (Press F7 Twice)")
RegionInfo := MyGui.Add("Text", "xm y+5 w290 cGray", "Box: X" BoxX " Y" BoxY " (" BoxW "x" BoxH ")")
LiveReadText := MyGui.Add("Text", "xm y+5 w290 cPurple", "Last Read: [None]")

BtnApply := MyGui.Add("Button", "xm y+12 w140 Default", "Apply Settings")
BtnToggle := MyGui.Add("Button", "x+10 w140", "Start (F6)")
StatusText := MyGui.Add("Text", "xm y+10 w290 cGray", "Status: Stopped | Press F6 to Start")

; Bind UI Events
BtnSetBox.OnEvent("Click", (*) => SetBoxCorner())
BtnApply.OnEvent("Click", ApplySettings)
BtnToggle.OnEvent("Click", (*) => ToggleMacro())
MyGui.OnEvent("Close", (*) => ExitApp())

MyGui.Show("AutoSize")

; --- HOTKEYS ---
F7::SetBoxCorner()
F6::ToggleMacro()

; --- FUNCTIONS ---
SetBoxCorner() {
    global BoxX, BoxY, BoxW, BoxH, Step1Set
    MouseGetPos(&mx, &my)

    if (!Step1Set) {
        BoxX := mx
        BoxY := my
        Step1Set := true
        RegionInfo.SetFont("cD97706")
        RegionInfo.Text := "Top-Left set (" BoxX "," BoxY "). Hover Bottom-Right & press F7!"
    } else {
        BoxW := Max(20, mx - BoxX)
        BoxH := Max(20, my - BoxY)
        Step1Set := false
        RegionInfo.SetFont("cGreen")
        RegionInfo.Text := "Box Set: X" BoxX " Y" BoxY " (" BoxW "x" BoxH ")"
        FlashCaptureBox(BoxX, BoxY, BoxW, BoxH)
    }
}

FlashCaptureBox(x, y, w, h) {
    Overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    Overlay.BackColor := "Red"
    Overlay.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(90, Overlay)
    SetTimer(() => Overlay.Destroy(), -800)
}

ApplySettings(*) {
    global QuickHold, PressHold, ScanDelay, SettleDelay
    QuickHold := Integer(EditQuick.Value || 60)
    PressHold := Integer(EditPress.Value || 2000)
    ScanDelay := Integer(EditScan.Value || 70)
    SettleDelay := Integer(EditSettle.Value || 150)
    StatusText.Text := "Status: Settings Applied!"
}

ToggleMacro() {
    global Toggle, LastPrompt, ActionLock
    ApplySettings()
    Toggle := !Toggle
    LastPrompt := ""
    ActionLock := 0

    if (Toggle) {
        BtnToggle.Text := "Stop (F6)"
        StatusText.SetFont("cGreen")
        StatusText.Text := "Status: RUNNING OCR (Click into Roblox)"
        SetTimer(ReadPromptAndAct, ScanDelay)
    } else {
        SetTimer(ReadPromptAndAct, 0)
        Send("{e up}")
        BtnToggle.Text := "Start (F6)"
        StatusText.SetFont("cRed")
        StatusText.Text := "Status: STOPPED"
    }
}

ReadPromptAndAct() {
    global BoxX, BoxY, BoxW, BoxH, QuickHold, PressHold, Toggle, LastPrompt, ActionLock, SettleDelay
    if (!Toggle) {
        return
    }

    if (A_TickCount < ActionLock) {
        return
    }

    if (!WinActive("ahk_exe RobloxPlayerBeta.exe") && !WinActive("Roblox")) {
        return
    }

    try {
        Result := OCR.FromRect(BoxX, BoxY, BoxW, BoxH, {scale: 3})
        PromptText := RegExReplace(Trim(Result.Text), "\s+", " ")

        if (PromptText = "") {
            LastPrompt := ""
            return
        }

        if (PromptText != LastPrompt) {
            LastPrompt := PromptText
            LiveReadText.SetFont("cPurple")
            LiveReadText.Text := "Last Read: " PromptText
        }

        ; Handle Press or Crimp prompts
        if (InStr(PromptText, "Press") || InStr(PromptText, "Crimp")) {
            StatusText.Text := "Status: Aligning..."
            if (SettleDelay > 0) {
                Sleep(SettleDelay)
            }

            StatusText.Text := "Status: Pressing..."
            Send("{e down}")
            Sleep(PressHold)
            Send("{e up}")
            
            ; Lean lockout that clears right as the action finishes
            ActionLock := A_TickCount + 100
            LastPrompt := ""
        }
        ; Handle Pack / general prompts with snappy response
        else if (StrLen(PromptText) >= 2) {
            StatusText.Text := "Status: Action (E)..."
            Send("{e down}")
            Sleep(QuickHold)
            Send("{e up}")
            
            ActionLock := A_TickCount + 80
            LastPrompt := ""
        }
    } catch as err {
        ; Silently catch OCR glitches
    }
}
