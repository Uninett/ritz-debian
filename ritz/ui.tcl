#
# $Id$
#

#
# User interface routines
#

proc initUi { } {
    global View
    global uiLabelFilter

    set def_View(id) 0
    set def_View(opstate) 1
    set def_View(admstate) 1
    set def_View(priority) 0
    set def_View(age) 1
    set def_View(downtime) 1
    set def_View(updated) 0
    set def_View(router) 1
    set def_View(port) 1
    set def_View(descr) 1

    foreach ix {id opstate admstate priority age \
		    downtime updated router port descr } {
	if { ! [info exists View($ix)] } {
	    set View($ix) $def_View($ix)
	}
    }

    set uiLabelFilter(selected)		"Selected"
    set uiLabelFilter(type)		"Case type"
    set uiLabelFilter(portstate)	"Port state"
    set uiLabelFilter(reachability)	"Reachability"
    set uiLabelFilter(state)		"Admin state"
    set uiLabelFilter(downtime)		"Downtime (seconds)"
    set uiLabelFilter(router)		"Router name"
    set uiLabelFilter(port)		"Port name"
    set uiLabelFilter(descr)		"Port description" 

    uiResourceInit
    uiInitToplevel
}

proc uiResourceInit { } {

    tix resetoptions TixGray TK 21

    option add *text.alarmColor			"red"		startupFile
    option add *text.alertColor			"yellow"	startupFile
    option add *text.warningColor		"orange"	startupFile
    option add *text.normalColor		"pale green"	startupFile
    option add *text.closedColor		"sea green"	startupFile
    option add *text.unknownColor		"gray80"	startupFile
    option add *text.reachabilityAlarmColor	"yellow"	startupFile
    option add *text.portstateUnknownColor	"gray50"	startupFile
    option add *text.ignoredColor		"deep sky blue"	startupFile

#   option add *Text.Font {Courier -12}				startupFile
#   option add *Entry.Font {Courier -12} 			startupFile
}

proc uiInitToplevel { } {
    global FileItem
    global View

    wm title . "RITZ - Remote interface to zino"
    wm iconname . "RITZ - Remote interface to zino"
    wm geometry . 95x24

    frame .mbar -relief raised -bd 2

    menubutton .mbar.file -text File -underline 0 -menu .mbar.file.menu

    menu .mbar.file.menu -tearoff 0
    .mbar.file.menu add command -label "Open"  -command uiOpenServer
    set FileItem(open) [.mbar.file.menu index end]
    .mbar.file.menu add command -label "Close" -command uiCloseServer
    set FileItem(close) [.mbar.file.menu index end]
    
    global _Server
    if [array exists _Server] {
	.mbar.file.menu add cascade \
		-label "Use settings" \
		-menu .mbar.file.menu.settings

	menu .mbar.file.menu.settings -tearoff 0
	foreach ix [array names _Server] {
	    .mbar.file.menu.settings add command \
		    -label $ix \
		    -command "uiUseSettings $ix"
	}
    }

    .mbar.file.menu add command -label "Set server..." -command uiSetServer
    set FileItem(setserver) [.mbar.file.menu index end]
    .mbar.file.menu add command -label "Quit"  -command uiQuit
    set FileItem(quit) [.mbar.file.menu index end]

    menubutton .mbar.edit -text "Edit" \
	    -underline 0 -menu .mbar.edit.menu

    menu .mbar.edit.menu -tearoff 0
    .mbar.edit.menu add command \
	    -label "Clear selection" \
	    -command uiClearSelection
    .mbar.edit.menu add cascade \
	    -label "Selected" \
	    -menu .mbar.edit.menu.selected
    .mbar.edit.menu add cascade \
	    -label "Filtered" \
	    -menu .mbar.edit.menu.filtered

    menu .mbar.edit.menu.selected -tearoff 0
    .mbar.edit.menu.selected add command \
	    -label "History/status" \
	    -command uiEditSelected
    .mbar.edit.menu.selected add command \
	    -label "Poll now" \
	    -command uiPollSelected
    .mbar.edit.menu.selected add command \
	    -label "Clear flap" \
	    -command uiClearFlapSelected

    menu .mbar.edit.menu.filtered -tearoff 0
    .mbar.edit.menu.filtered add command \
	    -label "History/status" \
	    -command uiEditFiltered
    .mbar.edit.menu.filtered add command \
	    -label "Poll now" \
	    -command uiPollFiltered
    .mbar.edit.menu.filtered add command \
	    -label "Clear flap" \
	    -command uiClearFlapFiltered

    menubutton .mbar.view -text View -underline 0 -menu .mbar.view.menu

    menu .mbar.view.menu -tearoff 0

    .mbar.view.menu add command \
	    -label "Case filter..." \
	    -command uiSetFilter
    .mbar.view.menu add cascade \
	    -label "Sort by" \
	    -menu .mbar.view.menu.sort
    .mbar.view.menu add cascade \
	    -label "Column" \
	    -menu .mbar.view.menu.col
    .mbar.view.menu add command \
	    -label "Case by ID..." \
	    -command uiViewCaseById

    menu .mbar.view.menu.sort -tearoff 0
    foreach entry "default age age-rev updated upd-rev down down-rev" {
	.mbar.view.menu.sort add radiobutton \
		-label $entry \
		-variable Sortby \
		-command {
	    set sortedCases [sortCases $filteredCases]
	    uiDisplaySummary $sortedCases
	}
    }

    menu .mbar.view.menu.col
    foreach entry \
    "id opstate admstate priority age downtime updated router port descr" {
	.mbar.view.menu.col add checkbutton \
		-label [ucFirst $entry] \
		-variable View($entry) \
		-command { uiDisplaySummary $sortedCases }
    }

    . configure -menu .mbar
#    tk_menuBar .mbar .mbar.file .mbar.edit .mbar.view

    text .text -relief flat -bd 2 \
	    -yscrollcommand ".yscroll set" \
	    -xscrollcommand ".xscroll set" \
	    -wrap none \
	    -setgrid 1

    scrollbar .yscroll -command ".text yview"
    scrollbar .xscroll -command uiScrollTexts -orient horizontal

    text .heading -relief ridge \
	    -xscrollcommand ".xscroll set" \
	    -height 1 \
	    -wrap none

    menu .m -type normal -tearoff false
    .m add command -label "View attrs" -command \
	    {uiViewCaseAt [winfo rootx .m] [winfo rooty .m]}
    .m add command -label "View history" -command \
	    {uiViewHistAt [winfo rootx .m] [winfo rooty .m]}
    .m add command -label "View log" -command \
	    {uiViewLogAt [winfo rootx .m] [winfo rooty .m]}
    .m add command -label "Poll now" -command \
	    {uiPollAt [winfo rootx .m] [winfo rooty .m]}
    .m add command -label "Clear flap" -command \
	    {uiClearFlapAt [winfo rootx .m] [winfo rooty .m]}

    menubutton .mbar.help -text Help -underline 0 -menu .mbar.help.menu

    menu .mbar.help.menu -tearoff false

    .mbar.help.menu add command \
	    -label "About..." \
	    -command uiAbout

    pack .mbar.file .mbar.edit .mbar.view -side left
    pack .mbar.help -side right
    pack .mbar -side top -fill x
    pack .yscroll -side right -fill y
    pack .heading -fill x
    pack .xscroll -side bottom -fill x
    pack .text -fill both -expand 1
}

proc uiAbout { } {
    global Version

    set w .about
    uiSimpleToplevelSetup $w "About ritz"
    text $w.text -relief raised \
	    -bd 2 \
	    -wrap none \
	    -setgrid 1 \
	    -font {-adobe-new century schoolbook-bold-r-*-*-16-*} \
	    -height 3 -width 27 \
	    -background {#d9d9d9}

    set w $w.text
    $w insert end \
	    [format "RITZ - version %s\n" $Version] \
	    t1
    $w tag configure t1 -justify center
    $w insert end "(c) UNINETT and NORDUnet\n" t2
    $w tag configure t2 -justify center
    $w insert end "1998 - 2012\n" t3
    $w tag configure t3 -justify center

    $w configure -state disabled

    pack $w -expand 1 -fill both
}

proc uiScrollTexts { args } {
    eval .text xview $args
    eval .heading xview $args
}

proc uiUseSettings { ix } {
    foreach v {Server Port User Secret} {
	set u [format "_%s" $v]
	global $v $u
	set [set v] [set [set u]($ix)]
    }
}

proc uiOpenServer { } {
    global Server Port

    openServer $Server $Port

    # tweak normal/disable for menu entries
    global FileItem
    .mbar.file.menu entryconfigure $FileItem(close) -state normal
    .mbar.file.menu entryconfigure $FileItem(open) -state disabled

    # Authenticate user if we know the details
    global User Secret
    if { [info exists User] && [info exists Secret] } {
	authUser $User $Secret
	if [ catch { newNotifyOpen handleNotify } ] {
	    notifyOpen handleNotify; # do it the old style
	}
    }

    # Pull in cases from newly opened server
    global allCases filteredCases sortedCases
    set allCases [pullCases]
    set filteredCases [filterCases $allCases]
    set sortedCases [sortCases $filteredCases]

    # Tweak title
    wm title . [format "RITZ (%s) - Remote interface to zino" $Server]
    wm iconname . [format "RITZ (%s) - Remote interface to zino" $Server]

    uiDisplaySummary $sortedCases
}

proc uiCloseServer { } {

    closeServer
    
    # tweak normal/disable for menu entries
    global FileItem
    .mbar.file.menu entryconfigure $FileItem(close) -state disabled
    .mbar.file.menu entryconfigure $FileItem(open) -state normal

    # "forget" all attributes
    AttrForgetAll

    foreach v "allCases filteredCases sortedCases" {
	global $v
	set $v {}
    }
    catch {
	global knownCase
	unset knownCase
    }

    uiDisplaySummary $sortedCases
}

proc uiSetServer { } {

    set w .setServer
    uiSimpleToplevelSetup $w [format "Set server login info"]

    foreach v {Server Port User Secret} {
	set u [format "ui%s" $v]
	global $v $u
	if [info exists [set v]] {
	    set [set u] [set [set v]]
	} else {
	    set [set u] ""
	}
    }

    set f $w.server
    frame $f
    entry $f.entry -textvariable uiServer
    label $f.label -text "Server name: "
    pack $f.entry -side right
    pack $f.label -side left

    set f $w.port
    frame $f
    entry $f.entry -textvariable uiPort
    label $f.label -text "Server port: "
    pack $f.label -side left
    pack $f.entry -side right

    set f $w.user
    frame $f
    entry $f.entry -textvariable uiUser
    label $f.label -text "User: "
    pack $f.label -side left
    pack $f.entry -side right

    set f $w.secret
    frame $f
    entry $f.entry -textvariable uiSecret
    label $f.label -text "Secret: "
    pack $f.label -side left
    pack $f.entry -side right

    set f $w.but
    frame $f
    button $f.apply \
	    -text "Apply" \
	    -command "uiApplySetServer; destroy $w"
    button $f.cancel \
	    -text "Cancel" \
	    -command "destroy $w"

    pack $f.apply $f.cancel -padx 5m -side left

    pack $w.server $w.port $w.user $w.secret $w.but \
	    -fill x \
	    -side top \
	    -padx 2m -pady 2m
}

proc uiApplySetServer {} {

    foreach v { User Server Port Secret } {
	global $v
	set u [format "ui%s" $v]
	global $u

	set [set v] [set [set u]]
    }
}

proc uiQuit { } {

    catch { closeServer }
    destroy .
    exit 0
}

proc uiGetIdAt { x y } {
    
    set rx [winfo rootx .text]
    set ry [winfo rooty .text]
    foreach t [.text tag names @[expr $x - $rx],[expr $y - $ry]] {
	if { [regexp {^tag[0-9]+} $t] } {
	    regsub "tag" $t "" id
	    return $id
	}
    }
}

proc uiViewCaseAt { x y } {

    uiViewCase [uiGetIdAt $x $y]
}

proc uiViewHistAt { x y } {

    uiViewHist [uiGetIdAt $x $y]
}

proc uiViewLogAt { x y } {

    uiViewLog [uiGetIdAt $x $y]
}

proc uiPollAt { x y } {

    uiPoll [uiGetIdAt $x $y]
}

proc uiClearFlapAt { x y } {

    uiClearFlap [uiGetIdAt $x $y]
}

proc uiPoll { id } {

    set type [Attr $id "type"]
    set router [Attr $id "router"]

    if { $type == "portstate" } {
	set intf [Attr $id "ifindex"]
	pollIntf $router $intf
    } else {
	pollRouter $router
    }
}

proc uiClearFlap { id } {

    if { ! [AttrExists $id "flapstate"] } {
	return
    }
    set r [Attr $id "router"]
    set i [Attr $id "ifindex"]
    clearFlap $r $i
}

proc uiClearFlapMultiple { ids } {

    foreach id $ids {
	uiClearFlap $id
    }
}

proc uiClearFlapFiltered { } {
    global filteredCases

    if [filterIsEmpty] {
	error "No filter set!"
    }
    uiClearFlapMultiple $filteredCases
}

proc uiClearFlapSelected { } {
    global Selected

    if { ! [array exists Selected] } {
	return
    }
    uiClearFlapMultiple [array names Selected]
}

proc uiViewCaseById { } {
    global ViewCaseId

    set w .viewById
    uiSimpleToplevelSetup $w "View case by ID"
    set f $w.id
    frame $f
    set ViewCaseId ""
    entry $f.entry -textvariable ViewCaseId
    label $f.label -text "Case ID: "
    pack $f.entry -side right
    pack $f.label -side left

    set f $w.but
    frame $f
    button $f.apply \
	    -text "Apply" \
	    -command {uiViewCase $ViewCaseId; set ViewCaseId ""}
    pack $f.apply -padx 5m -side left

    pack $w.id $w.but -fill x -side top -padx 2m -pady 2m
}

proc uiColorCase { id } {
    global sevCol

    set t [Attr $id "type"]
    set s [caseSeverity $id]
    if { [info exists sevCol($t,$s)] } {
	return $sevCol($t,$s)
    }
    set rn [format "%s%sColor" $t [ucFirst $s]]
    set c [option get .text $rn [ucFirst $rn]]
    if { $c == "" } {
	set rn [format "%sColor" $s]
	set c [option get .text $rn [ucFirst $rn]]
    }

    set sevCol($t,$s) $c
    return $c
}

proc uiDisplaySummary { caseIds } {

    .text configure -state normal
    .text delete 1.0 end
    foreach i $caseIds {
	if [catch {set c [uiColorCase $i]} err] {
	    puts stderr [format "ritz: ignoring id %s: %s" $i $err]
	    break
	}
	.text insert end [summaryStr $i] tag$i
	.text insert end "\n"
	.text tag configure tag$i -background $c
	.text tag configure tag$i -relief flat -borderwidth 0
	.text tag bind tag$i <Enter> {
	    global inTag
	    foreach t [%W tag names @%x,%y] {
		.text tag configure $t -borderwidth 2 -relief raised
		set inTag $t
	    }
	}
	.text tag bind tag$i <Leave> {
	    global inTag
	    .text tag configure $inTag -borderwidth 0 -relief flat
	}
	.text tag bind tag$i <Button-1> {
	    foreach t [%W tag names @%x,%y] {
		if [regexp {^tag[0-9]+} $t] {
		    regsub "tag" $t "" id
		    uiViewCase $id
		}
	    }
	}
	.text tag bind tag$i <Button-2> {
	    foreach t [%W tag names @%x,%y] {
		if [regexp {^tag[0-9]+} $t] {
		    regsub "tag" $t "" id
		    uiToggleSel $id
		}
	    }
	}
	.text tag bind tag$i <Button-3> {
	    tk_popup .m %X %Y
	}
    }
    .text configure -state disabled

    .heading configure -state normal
    .heading delete 1.0 end
    .heading insert end [summaryHeading]
    .heading configure -state disabled
}

proc uiDoSummaryUpdate { } {
    global sortedCases

    uiDisplaySummary $sortedCases
}

proc uiScheduleSummaryUpdate { secs } {

    after cancel uiDoSummaryUpdate
    after [expr $secs * 1000] uiDoSummaryUpdate
}

proc uiClearSelection { } {
    global Selected

    if [array exists Selected] {
	foreach id [array names Selected] {
	    .text tag configure tag$id -foreground black
	}
	unset Selected
    }
}

proc uiToggleSel { id } {
    global Selected

    if { [info exists Selected($id)] } {
	unset Selected($id)
	.text tag configure tag$id -foreground black
    } else {
	set Selected($id) 1
	.text tag configure tag$id -foreground blue
    }
}

proc uiViewCaseSetup { w id } {

    toplevel $w
    set s [format "Case %s" $id]
    wm title $w $s
    wm iconname $w $s

    menu $w.menu -tearoff 0

    set m $w.menu.file
    $w.menu add cascade -label "File" -underline 0 -menu $m

    menu $m -tearoff 0
    $m add command -label "Close" \
	    -command "destroy $w" \
	    -accelerator "Alt-w"

    bind $w <Alt-w> "destroy $w; break"
    bind $w <Meta-w> "destroy $w; break"

    set m $w.menu.manage
    menu $m -tearoff 0
    $w.menu add cascade -label "Manage" -underline 0 -menu $m

    $m add command -label "justnetstat -i" \
	    -command [format "uiSnmpNetstat_i %s" $id]
    $m add command -label "justnetstat -idn" \
	    -command [format "uiSnmpNetstat_idn %s" $id]
    $m add command -label "traceroute" \
	    -command [format "uiTraceroute %s" $id]
    $m add command -label "telnet" \
	    -command [format "uiTelnet %s" $id]

    $w configure -menu $w.menu
}

proc uiViewCase { id } {

    set w .case$id

    if { [winfo exists $w] } {
	destroy $w.attrs
	destroy $w.buttons
	raise $w
    } else {
	uiViewCaseSetup $w $id
    }

    set b $w.buttons
    frame $b
    pack $b -side bottom -fill x -pady 2m
    button $b.viewLog -text "View Log" -command "uiViewLog $id"
    button $b.viewHist -text "View History" -command "uiViewHist $id"
    pack $b.viewLog $b.viewHist -side left -expand 1

    set a $w.attrs
    frame $a

    if { [AttrExists $id "descr"] } {
	set s [Attr $id "descr"]
	set width [max [string length $s] 30]
    } else {
	set width 30
    }

    foreach attr [lsort [AttrNames $id]] {
	set lf $a.frame_$attr
	frame $lf

	set l $lf.label
	label $l \
		-width 11 \
		-anchor e \
		-text [format "%s:" $attr]
	set e $lf.entry
	entry $e -width $width
	$e insert end [uiAttrVal $id $attr]
	$e configure -state disabled
	$e configure -disabledforeground {#666666}
	$e configure -disabledbackground {#ffffff}
	pack $l $e -fill x -side left
	pack $lf -side top
    }
    pack $a -side top
}

proc uiAttrVal { id attr } {

    set val [Attr $id $attr]
    if { $attr == "opened" || $attr == "updated" || $attr == "lasttrans" } {
        set val [clock format $val]
    }
    return $val
}

proc uiSimpleToplevelSetup { w title } {

    catch {destroy $w}

    toplevel $w
    wm title $w $title
    wm iconname $w $title

    menu $w.menu -tearoff 0

    set m $w.menu.file
    $w.menu add cascade -label "File" -underline 0 -menu $m
    menu $m -tearoff 0
    $m add command -label "Close" \
	    -command "destroy $w" \
	    -accelerator "Alt-w"
    
    bind $w <Alt-w> "destroy $w; break"
    bind $w <Meta-w> "destroy $w; break"
    
    $w configure -menu $w.menu
}

proc uiSimpleScrolledText { w {height 10} {width 80} {xscroll yes}} {

    # Now set up scrollbars and text window

    text $w.text -relief flat -bd 2 \
	    -yscrollcommand "$w.yscroll set" \
	    -width $width \
	    -height $height \
	    -wrap none \
	    -setgrid 1

    scrollbar $w.yscroll -command "$w.text yview"
    pack $w.yscroll -side right -fill y

    if { $xscroll == "yes" } {
	scrollbar $w.xscroll -command "$w.text xview" -orient horizontal
	pack $w.xscroll -side bottom -fill x
	$w.text configure -xscrollcommand "$w.xscroll set"
    }

    pack $w.text -fill both -expand yes
    
    return $w.text
}

proc uiViewLog { id } {

    set w .log$id
    if {! [winfo exists $w] } {
	uiSimpleToplevelSetup $w [format "Log %s" $id]
	uiSimpleScrolledText $w
	wm geometry $w 80x10

	set m $w.menu.view
	$w.menu add cascade -label "View" -underline 0 -menu $m
	menu $m -tearoff 0
	$m add command -label "History" -command "uiViewHist $id"
	$m add command -label "Case attrs" -command "uiViewCase $id"
    }

    # Fill in text
    set t [getLog $id]
    $w.text configure -state normal
    $w.text delete 1.0 end
    $w.text insert end $t
    $w.text configure -state disabled
    $w.text see end

    raise $w;			# Bring to the attention of the user
}

proc uiCondEnable { w id newval } {

    set oldval [Attr $id "state"]
    if { $newval != $oldval } {
	$w configure -state normal
    }
}

proc uiModHistSetup { w id applyCmd } {

    set l $w.label
    label $l -anchor w -text "New history entry:"
    text $w.text -relief sunken -bd 2 \
	    -height 5 \
	    -wrap none \
	    -setgrid 1
    
    bind $w.text <Any-Key> "$w.bot.apply configure -state normal"
    bind $w.text <Key-Delete> [bind Text <Key-BackSpace>]

    set b $w.bot
    frame $b
    button $b.apply \
	    -text "Apply" \
	    -command [format "%s %s %s" $applyCmd $w $id ]\
	    -state disabled

    tixOptionMenu $w.state \
	    -label "Set admin state to: " \
	    -command "uiCondEnable $w.bot.apply $id"

    foreach state [possibleStates] {
	$w.state add command $state -label $state
    }
    catch { $w.state configure -value [Attr $id "state"] }

    $b.apply configure -state disabled

    pack $b.apply -side left -padx 5m -pady 2m
    pack $b -side bottom -fill x

    pack $w.state -side top -anchor w -pady 2m
    pack $l -side top -fill x
    pack $w.text -side top -fill both -expand yes
}

proc uiViewHistSetup { w id } {
    global Authenticated

    uiSimpleToplevelSetup $w [format "History %s" $id]

    set m $w.menu.view
    $w.menu add cascade -label "View" -underline 0 -menu $m
    menu $m -tearoff 0
    $m add command -label "Log" -command "uiViewLog $id"
    $m add command -label "Case attrs" -command "uiViewCase $id"

    if { $Authenticated } {
	tixPanedWindow $w.p -orientation vertical
	set w1 [$w.p add log -expand 2]
	set w2 [$w.p add newlog -expand 1]
    
	set text [uiSimpleScrolledText $w1]

	uiModHistSetup $w2 $id uiSendHistAndState

	pack $w.p -expand yes -fill both
    } else {
	set text [uiSimpleScrolledText $w]
    }
#    wm geometry $w 80x24 # Something screwy here...

    return $text
}

proc nonEmptyHist { str } {

    return [regexp "\[^ \t\n\]" $str]
}

# For now just replace whitespace at the end of the string
# with a single newline.

proc fixupHist { str } {

    regsub "\[ \n\t\]+$" $str "\n" newstr
    return $newstr
}

# Send history entry (if non-empty)
# and new state (if changed).
# Complain if neither cause an update.

proc uiSendHistAndState { w id } {

    set newhist [$w.text get 1.0 end]
    set newstate [$w.state cget -value]
    set oldstate [Attr $id "state"]

    set update 0
    if { [nonEmptyHist $newhist] } {
	set newhist [fixupHist $newhist]
#	puts [format "New history entry: %s\n--" $newhist]
	addHist $id [fixupHist $newhist]
	set update 1
    }
    if { $newstate != $oldstate } {
	setState $id $newstate
	set update 1
    }
    if { ! $update } {
	error "No change to state or history made"
    }
    $w.text configure -state normal
    $w.text delete 1.0 end;	# Remove text from entry
}

proc uiViewHist { id } {
    global HistoryTxtWin

    set w .hist$id

    # Write in already-created window if it exists
    if { [info exists HistoryTxtWin($id)] } {
	if { [winfo exists $HistoryTxtWin($id)] } {
	    set text $HistoryTxtWin($id)
	} else {
	    set text [uiViewHistSetup $w $id]
	}
    } else {
	set text [uiViewHistSetup $w $id]
    }
    set HistoryTxtWin($id) $text; # remember for later use

    # Fill in text
    set t [getHist $id]
    $text configure -state normal
    $text delete 1.0 end
    $text insert end $t
    $text configure -state disabled
    $text see end

    raise $w;			# Bring to the attention of the user
}

proc uiSendMultiHistAndState { w ids } {

    set newhist [$w.text get 1.0 end]
    set newstate [$w.state cget -value]
    
    if { [nonEmptyHist $newhist] } {
	foreach id $ids {
	    addHist $id [fixupHist $newhist]
	    update idletasks
	}
    }
    foreach id $ids {
	set oldstate [Attr $id "state"]
	if { $newstate != $oldstate } {
	    setState $id $newstate
	    update idletasks
	}
    }
    $w.text configure -state normal
    $w.text delete 1.0 end;	# Remove now submitted text
}

proc uiSendFilteredHistAndState { w id } {
    global filteredCases

    uiSendMultiHistAndState $w $filteredCases
}

proc uiEditFiltered { } {
    global sortedCases

    if [filterIsEmpty] {
	error "No filter set!"
    }
    set w .edit-filtered
    uiSimpleToplevelSetup $w [format "Edit filtered cases"]
    wm geometry $w 80x5
    frame $w.f
    set id [lindex $sortedCases 0]; # Need to pick one
    uiModHistSetup $w.f $id uiSendFilteredHistAndState
    pack $w.f -side top
}

proc uiSendSelectedHistAndState { w id } {
    global Selected

    uiSendMultiHistAndState $w [array names Selected]
}

proc uiEditSelected { } {
    global Selected

    if { ! [array exists Selected] } {
	return
    }
    set w .edit-selected
    uiSimpleToplevelSetup $w [format "Edit selected cases"]
    wm geometry $w 80x5
    frame $w.f
    set id [lindex [array names Selected] 0]; # Need to pick one
    uiModHistSetup $w.f $id uiSendSelectedHistAndState
    pack $w.f -side top
}

proc uiPollMultiple { ids } {

    foreach id $ids {
	uiPoll $id
    }
}

proc uiPollFiltered { } {
    global filteredCases

    if [filterIsEmpty] {
	error "No filter set!"
    }
    uiPollMultiple $filteredCases
}

proc uiPollSelected { } {
    global Selected

    if { ! [array exists Selected] } {
	return
    }
    uiPollMultiple [array names Selected]
}

proc possiblePortStates { } {

    return "down adminDown flapping up"
}

proc possibleMatchTypes { } {

    return "exact glob regexp"
}

proc possibleStates { } {

    return "open working waiting confirm-wait ignored closed"
}

proc uiMkMatchtypeMenu { w item { matchtypes default }} {

    tixOptionMenu $w \
	    -label "Matchtype:" \
	    -variable FilterHow($item) \
	    -options {
	menubutton.width 8
    }
    if { $matchtypes == "default" } {
	set mts [possibleMatchTypes]
    } else {
	set mts $matchtypes
    }
    foreach mt $mts {
	$w add command $mt -label $mt
    }
}

proc uiMkSimpleEntry { w item { matchtypes default }} {

    entry $w.entry -textvariable FilterVal($item)

    uiMkMatchtypeMenu $w.how $item $matchtypes
    pack $w.how -side right
    pack $w.entry -side right
}

proc uiMkSimpleMenu { w item values } {

    tixOptionMenu $w.menu \
	    -variable FilterVal($item) \
	    -options {
	menubutton.width 10
	label.width 0
    }
    foreach state $values {
	$w.menu add command $state -label $state
    }
    pack $w.menu -side left -padx 2m
}

proc uiSetFilter { } {
    global uiLabelFilter

    set w .setFilter
    set title "Set case filter"

    uiSimpleToplevelSetup $w $title

    foreach item {selected type portstate reachability \
	    state downtime router port descr} {
	tixLabelFrame $w.$item -label $uiLabelFilter($item)

	set f [$w.$item subwidget frame]

	label $f.l -anchor w -text "Filter on:"
	pack $f.l -side left

	checkbutton $f.check -variable FilterOn($item)
	pack $f.check -side left

	switch -exact $item {
	    type {
		uiMkSimpleMenu $f $item {alarm bfd bgp portstate reachability}
	    }
	    portstate {
		uiMkSimpleMenu $f $item [possiblePortStates]
	    }
	    reachability {
		uiMkSimpleMenu $f $item {no-response reachable}
	    }
	    state {
		uiMkSimpleMenu $f $item [possibleStates]
	    }
	    downtime {
		uiMkSimpleEntry $f $item [list "value>="]
	    }
	    router {
		uiMkSimpleEntry $f $item
	    }
	    port {
		uiMkSimpleEntry $f $item
	    }
	    descr {
		uiMkSimpleEntry $f $item
	    }
	}

	pack $w.$item -side top -fill x
    }
    set b $w.bot
    frame $b
    button $b.apply \
	    -text "Apply" \
	    -command uiApplyFilter
    button $b.reset \
	    -text "Reset" \
	    -command uiResetFilter
    pack $b.apply $b.reset -side left -pady 2m -padx 5m
    pack $b -side bottom
}

proc uiApplyFilter { } {
    global allCases filteredCases sortedCases

    set filteredCases [filterCases $allCases]
    set sortedCases [sortCases $filteredCases]
    uiDisplaySummary $sortedCases
}

proc uiResetFilter { } {
    global FilterOn FilterHow FilterVal

    foreach ix [array names FilterOn] {
	set FilterOn($ix) 0
    }
    foreach ix [array names FilterHow] {
	set FilterVal($ix) ""
	catch { set FilterHow($ix) "exact" }
    }
    uiClearSelection
}

proc uiAppendTextLine { w l } {

    $w configure -state normal
    $w insert end [format "%s\n" $l]
    $w configure -state disabled
    update
}

proc uiFileToTextLine { f w } {

    set cc [gets $f line]
    if { $cc == -1 } {
	close $f
	return
    }
    catch { uiAppendTextLine $w $line }
}

proc uiTraceroute { id } {

    set w .trace$id
    set addr [Attr $id "polladdr"]
    set name [Attr $id "router"]
    set title [format "trace %s / %s" $name $addr]

    uiSimpleToplevelSetup $w $title
    set text [uiSimpleScrolledText $w 10 80]
    $text configure -state disabled

    update idletasks
    
    set cmd [format "traceroute %s 2>&1" $addr]
    set tr [open [format "| sh -c \"%s\"" $cmd]]
    fconfigure $tr -buffering line
    fileevent $tr readable "uiFileToTextLine $tr $text"
}

proc uiSnmpNetstat_idn { id } {

    set w .snmpn_idn_$id
    set addr [Attr $id "polladdr"]
    set name [Attr $id "router"]
    if { [catch {set comm [getCommunity $name]}] } {
	set comm "public"
    }

    set title [format "snmpnetstat -idn %s (%s)" $addr $name]
    uiSimpleToplevelSetup $w $title

    set text [uiSimpleScrolledText $w 20 80]
    $text configure -state disabled

    update idletasks

    set agentArgs [list \
	    -address $addr \
	    -community $comm]

    netstat $agentArgs {noTranslation ciscoDescr} \
	    [list uiAppendTextLine $text]
}

proc uiSnmpNetstat_i { id } {

    set w .snmpn_i_$id
    set addr [Attr $id "polladdr"]
    set name [Attr $id "router"]
    if { [catch {set comm [getCommunity $name]}] } {
	set comm "public"
    }

    set title [format "snmpnetstat -i %s (%s)" $addr $name]
    uiSimpleToplevelSetup $w $title

    set text [uiSimpleScrolledText $w 20 80]
    $text configure -state disabled

    update idletasks

    set agentArgs [list \
	    -address $addr \
	    -community $comm]

    netstat $agentArgs {} \
	    [list uiAppendTextLine $text]
}

proc uiTelnet { id } {

    set addr [Attr $id "polladdr"]
    set name [Attr $id "router"]

    set cmd [format "xterm -name telnet-%s -e telnet %s" $name $addr]
    eval exec $cmd &
}
