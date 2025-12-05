# =============================================================================
# test_correct_basis.tcl
# ENP-P™ / ROOM 64×256-bit — Correct-basis first-read test
#  - Auto-detects JTAG master
#  - Arms one cell with a random 256-bit value + basis
#  - READ #1 with correct basis → expect full 256-bit match
#  - READ #2 after collapse      → expect all-zero inert state
# =============================================================================

# --------------------------------------------------------------------------
# 1. Auto-detect master path + handle
# --------------------------------------------------------------------------
set master_paths [get_service_paths master]
if {[llength $master_paths] == 0} {
    puts "ERROR: No 'master' services found. Is the board connected?"
    return
}

set MASTER_PATH ""
foreach p $master_paths {
    if {[string match "*DE-SoC*master_0.master" $p]} {
        set MASTER_PATH $p
        break
    }
}
if {$MASTER_PATH eq ""} {
    # Fallback: just take the first one
    set MASTER_PATH [lindex $master_paths 0]
}

puts "Using MASTER_PATH = $MASTER_PATH"
set MASTER [claim_service master $MASTER_PATH ""]
puts "MASTER handle = $MASTER"

proc W32 {addr value} {
    master_write_32 $::MASTER $addr [list $value]
}
proc R32 {addr} {
    set d [master_read_32 $::MASTER $addr 1]
    return [lindex $d 0]
}

# Sanity ping
puts [format "Sanity: R32(0x0) = 0x%08X" [R32 0x0]]

# --------------------------------------------------------------------------
# 2. Register map (matches 64×256-bit cell_avl_slave.sv)
# --------------------------------------------------------------------------
set BASE    0x00000000

set DATA0   0x00
set DATA1   0x04
set DATA2   0x08
set DATA3   0x0C
set DATA4   0x10
set DATA5   0x14
set DATA6   0x18
set DATA7   0x1C

set ADDRREG 0x20

set INIT0   0x24
set INIT1   0x28
set INIT2   0x2C
set INIT3   0x30
set INIT4   0x34
set INIT5   0x38
set INIT6   0x3C
set INIT7   0x40

set CTRL    0x44
set TRIG    0x48
set STATUS  0x4C
set IDREG   0x50

# --------------------------------------------------------------------------
# 3. Helpers
# --------------------------------------------------------------------------
proc select_cell {idx} {
    W32 [expr {$::BASE + $::ADDRREG}] $idx
}

proc set_basis_ctrl {basis} {
    W32 [expr {$::BASE + $::CTRL}] [expr {$basis & 0xFF}]
}

proc write_init_256 {words} {
    # words = {w0..w7}, LSW→MSW
    W32 [expr {$::BASE + $::INIT0}] [lindex $words 0]
    W32 [expr {$::BASE + $::INIT1}] [lindex $words 1]
    W32 [expr {$::BASE + $::INIT2}] [lindex $words 2]
    W32 [expr {$::BASE + $::INIT3}] [lindex $words 3]
    W32 [expr {$::BASE + $::INIT4}] [lindex $words 4]
    W32 [expr {$::BASE + $::INIT5}] [lindex $words 5]
    W32 [expr {$::BASE + $::INIT6}] [lindex $words 6]
    W32 [expr {$::BASE + $::INIT7}] [lindex $words 7]
}

proc read_full_256 {} {
    return [list \
        [R32 [expr {$::BASE + $::DATA0}]] \
        [R32 [expr {$::BASE + $::DATA1}]] \
        [R32 [expr {$::BASE + $::DATA2}]] \
        [R32 [expr {$::BASE + $::DATA3}]] \
        [R32 [expr {$::BASE + $::DATA4}]] \
        [R32 [expr {$::BASE + $::DATA5}]] \
        [R32 [expr {$::BASE + $::DATA6}]] \
        [R32 [expr {$::BASE + $::DATA7}]] ]
}

proc pp256 {words} {
    set s ""
    foreach w [lreverse $words] {
        append s [format "%08X" $w]
    }
    return "0x$s"
}

proc all_zero {lst} {
    foreach x $lst {
        if {$x != 0} { return 0 }
    }
    return 1
}

proc random32 {} {
    return [expr {int(rand()*0x100000000)}]
}

# --------------------------------------------------------------------------
# 4. Generate random 256-bit value
# --------------------------------------------------------------------------
expr {srand([clock seconds])}

set random_words {}
for {set i 0} {$i < 8} {incr i} {
    lappend random_words [random32]
}

# --------------------------------------------------------------------------
# 5. Run test
# --------------------------------------------------------------------------
puts ""
puts "======================================================="
puts " ENP-P™ / ROOM: Correct-Basis First Read Test"
puts "======================================================="

set id [R32 [expr {$BASE + $IDREG}]]
puts [format "IDREG = 0x%08X" $id]

set idx   63
set basis [expr {int(rand()*256)}]

puts ""
puts "Cell index  : $idx"
puts [format "Basis (8-bit): 0x%02X" $basis]
puts "INIT value (256-bit):"
puts "  [pp256 $random_words]"

select_cell $idx
set_basis_ctrl $basis
write_init_256 $random_words

# READ #1 (before TRIG — design should already resolve and collapse logically)
puts ""
puts "Triggering READ #1 (correct basis)..."
set read1 [read_full_256]
puts "READ #1 (correct basis):"
puts "  R1 = [pp256 $read1]"

# collapse event (TRIG wire is still there for the ROOM wrapper)
puts ""
puts "Triggering collapse..."
W32 [expr {$BASE + $::TRIG}] 1

# READ #2
set read2 [read_full_256]
puts ""
puts "READ #2 (after collapse)"
puts "  R2 = [pp256 $read2]"

# --------------------------------------------------------------------------
# 6. Result summary (word-wise compare)
# --------------------------------------------------------------------------
puts ""
puts "=== RESULT ==================================================="

set match1 1
for {set i 0} {$i < 8} {incr i} {
    set exp [lindex $random_words $i]
    set got [lindex $read1        $i]

    set exp32 [expr {$exp & 0xFFFFFFFF}]
    set got32 [expr {$got & 0xFFFFFFFF}]

    if {$exp32 != $got32} {
        puts [format "MISMATCH word %d: expected 0x%08X got 0x%08X" \
              $i $exp32 $got32]
        set match1 0
    }
}

if {$match1} {
    puts "PASS: First read matched expected value."
} else {
    puts "FAIL: First read did NOT match expected value."
}

if {[all_zero $read2]} {
    puts "PASS: Second read returned dead-circuit inert state."
} else {
    puts "FAIL: Second read was NOT fully inert."
}

puts "=============================================================="
puts ""
