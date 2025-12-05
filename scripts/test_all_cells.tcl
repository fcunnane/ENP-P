# =============================================================================
# test_all_cells.tcl
# ENP-P™ / ROOM 64×256-bit — Multi-cell randomized sweep
#  - Auto-detects JTAG master
#  - Repeats NTRIALS random tests:
#      * choose random cell + random 256-bit value + random basis
#      * READ #1 (correct basis)  → should match
#      * READ #2 (after collapse) → should be all-zero
#  - Prints aggregate PASS/FAIL counts
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

puts [format "Sanity: R32(0x0) = 0x%08X" [R32 0x0]]

# --------------------------------------------------------------------------
# 2. Register map
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
# 4. Seed RNG
# --------------------------------------------------------------------------
expr {srand([clock seconds])}

# --------------------------------------------------------------------------
# 5. Test parameters
# --------------------------------------------------------------------------
set NTRIALS 64

set pass_read1 0
set fail_read1 0
set pass_read2 0
set fail_read2 0

puts ""
puts "======================================================="
puts " ENP-P™ / ROOM: Multi-Cell Randomized Sweep"
puts "  NTRIALS = $NTRIALS"
puts "======================================================="

set id [R32 [expr {$BASE + $IDREG}]]
puts [format "IDREG = 0x%08X" $id]
puts ""

for {set t 0} {$t < $NTRIALS} {incr t} {

    # Random 256-bit value
    set v {}
    for {set i 0} {$i < 8} {incr i} {
        lappend v [random32]
    }

    set idx   [expr {int(rand()*64)}]
    set basis [expr {int(rand()*256)}]

    puts "---------------------------------------------------"
    puts [format "Trial %3d: cell=%2d basis=0x%02X" $t $idx $basis]
    puts "  INIT = [pp256 $v]"

    select_cell $idx
    set_basis_ctrl $basis
    write_init_256 $v

    # READ #1
    set read1 [read_full_256]
    puts "  READ #1 = [pp256 $read1]"

    # collapse
    W32 [expr {$BASE + $::TRIG}] 1

    # READ #2
    set read2 [read_full_256]
    puts "  READ #2 = [pp256 $read2]"

    # Check READ #1 match
    set match1 1
    for {set i 0} {$i < 8} {incr i} {
        set exp [lindex $v     $i]
        set got [lindex $read1 $i]

        set exp32 [expr {$exp & 0xFFFFFFFF}]
        set got32 [expr {$got & 0xFFFFFFFF}]

        if {$exp32 != $got32} {
            puts [format "    MISMATCH word %d: exp=0x%08X got=0x%08X" \
                  $i $exp32 $got32]
            set match1 0
        }
    }

    if {$match1} {
        puts "    PASS: READ #1 matched expected value."
        incr pass_read1
    } else {
        puts "    FAIL: READ #1 mismatch."
        incr fail_read1
    }

    # Check READ #2 all-zero
    if {[all_zero $read2]} {
        puts "    PASS: READ #2 inert (all-zero)."
        incr pass_read2
    } else {
        puts "    FAIL: READ #2 NOT inert."
        incr fail_read2
    }
}

# --------------------------------------------------------------------------
# 6. Aggregate summary
# --------------------------------------------------------------------------
puts ""
puts "======================================================="
puts " AGGREGATE SUMMARY"
puts "======================================================="
puts [format "READ #1: PASS=%d  FAIL=%d" $pass_read1 $fail_read1]
puts [format "READ #2: PASS=%d  FAIL=%d" $pass_read2 $fail_read2]
puts "======================================================="
puts "Done."
puts ""
