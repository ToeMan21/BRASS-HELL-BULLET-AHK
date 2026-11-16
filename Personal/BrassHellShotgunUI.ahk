#Requires AutoHotkey v2.0
#SingleInstance Force
#Include OCR.ahk

SendMode("Event")
CoordMode("Mouse", "Screen")

; --- DEFAULT CONFIGURATION VALUES ---
QuickHold := 60          ; Fast tap duration (ms)
PressHold := 2000        ; 2000 ms shell press duration
ScanDelay := 100         ; How fast OCR scans the prompt text (ms)
SettleDelay := 200       ; Wait time before pressing bullet so machine aligns (ms)

; --- OCR REGION ---
BoxX := 800
BoxY := 500
BoxW := 260
BoxH := 70
Step1Set := false
Toggle := false
LastPrompt := ""
GuideOverlay := ""

; --- CREATE THE SETTINGS UI ---
MyGui := Gui("+AlwaysOnTop", "Brass Hell - OCR Prompt Reader")
MyGui.SetFont("s10", "Segoe UI")

MyGui.Add("Text", "w175", "Quick E Hold (ms):")
EditQuick := MyGui.Add("Edit", "x+10 w80 Number", QuickHold)

MyGui.Add("Text", "xm w175", "Shell Press Hold (ms):")
EditPress := MyGui.Add("Edit", "x+10 w80 Number", PressHold)

MyGui.Add("Text", "xm w175", "Press Align Delay (ms):")
EditSettle := MyGui.Add("Edit", "x+10 w80 Number", SettleDelay)

MyGui.Add("Text", "xm w175", "OCR Scan Speed (ms):")
EditScan := MyGui.Add("Edit", "x+10 w80 Number", ScanDelay)

MyGui.Add("Text", "xm y+12 w290 cBlue", "--- Prompt Text Area Setup ---")
BtnSetBox := MyGui.Add("Button", "xm y+5 w190", "Set Box (F7)")
ChkShowBox := MyGui.Add("CheckBox", "x+10 yp+4", "Show Box")
RegionInfo := MyGui.Add("Text", "xm y+8 w290 cGray", "Box: X" BoxX " Y" BoxY " (" BoxW "x" BoxH ")")
LiveReadText := MyGui.Add("Text", "xm y+5 w290 cPurple", "Last Read: [None]")

BtnApply := MyGui.Add("Button", "xm y+12 w140 Default", "Apply Settings")
BtnToggle := MyGui.Add("Button", "x+10 w140", "Start (F6)")
StatusText := MyGui.Add("Text", "xm y+10 w290 cGray", "Status: Stopped | Press F6 to Start")

; Bind UI Events
BtnSetBox.OnEvent("Click", (*) => SetBoxCorner())
ChkShowBox.OnEvent("Click", (*) => UpdateGuideBox())
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
        ; 1st press (or odd press): Update Top-Left corner immediately (keeps scanning!)
        BoxX := mx
        BoxY := my
        Step1Set := true
        RegionInfo.SetFont("cD97706")
        RegionInfo.Text := "Top-Left set (" BoxX "," BoxY "). Hover Bottom-Right & press F7!"
        UpdateGuideBox(true)
    } else {
        ; 2nd press (or even press): Set Bottom-Right width/height
        BoxW := Max(20, mx - BoxX)
        BoxH := Max(20, my - BoxY)
        Step1Set := false
        RegionInfo.SetFont("cGreen")
        RegionInfo.Text := "Box Set: X" BoxX " Y" BoxY " (" BoxW "x" BoxH ")"
        UpdateGuideBox(true)
    }
}

UpdateGuideBox(flash := false) {
    global BoxX, BoxY, BoxW, BoxH, GuideOverlay, ChkShowBox

    if (IsObject(GuideOverlay)) {
        GuideOverlay.Destroy()
        GuideOverlay := ""
    }

    if (ChkShowBox.Value || flash) {
        GuideOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        GuideOverlay.BackColor := "Red"
        GuideOverlay.Show("x" BoxX " y" BoxY " w" BoxW " h" BoxH " NoActivate")
        WinSetTransparent(55, GuideOverlay)

        if (!ChkShowBox.Value && flash) {
            SetTimer(() => UpdateGuideBox(false), -800)
        }
    }
}

ApplySettings(*) {
    global QuickHold, PressHold, ScanDelay, SettleDelay
    QuickHold := Integer(EditQuick.Value || 60)
    PressHold := Integer(EditPress.Value || 2000)
    SettleDelay := Integer(EditSettle.Value || 200)
    ScanDelay := Integer(EditScan.Value || 100)
    StatusText.Text := "Status: Settings Applied!"
}

ToggleMacro() {
    global Toggle, LastPrompt
    ApplySettings()
    Toggle := !Toggle
    LastPrompt := ""

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
    global BoxX, BoxY, BoxW, BoxH, QuickHold, PressHold, SettleDelay, Toggle, LastPrompt
    if (!Toggle) {
        return
    }

    if (!WinActive("ahk_exe RobloxPlayerBeta.exe") && !WinActive("Roblox")) {
        return
    }

    try {
        Result := OCR.FromRect(BoxX, BoxY, BoxW, BoxH, {scale: 3})
        PromptText := RegExReplace(Trim(Result.Text), "\s+", " ")

        if (PromptText != LastPrompt) {
            LastPrompt := PromptText
            LiveReadText.SetFont("cPurple")
            LiveReadText.Text := "Last Read: " (PromptText != "" ? PromptText : "[Empty]")
        }

        if (PromptText = "") {
            return
        }

        ; 2000 ms hold when prompt mentions Press or Crimp
        if (InStr(PromptText, "Press") || InStr(PromptText, "Crimp")) {
            if (SettleDelay > 0) {
                Sleep(SettleDelay)
            }
            Send("{e down}")
            Sleep(PressHold)
            Send("{e up}")
            Sleep(150)
        }
        ; Any other readable prompt triggers a quick E tap
        else if (StrLen(PromptText) >= 2) {
            Send("{e down}")
            Sleep(QuickHold)
            Send("{e up}")
            Sleep(120)
        }
    } catch as err {
        LiveReadText.SetFont("cRed")
        LiveReadText.Text := "OCR Error: " err.Message
    }
}
