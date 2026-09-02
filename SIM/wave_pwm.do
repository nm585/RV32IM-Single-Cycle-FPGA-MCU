# Waveform layout for tb_PWM. Safe to reload at any time, including after the
# simulation has already run.
#
#   do wave_pwm.do
#
# Deliberately no "onerror {resume}" here. The old wave.do swallows failed
# add-wave commands and then still runs the window commands at the end, which
# is what crashes the GUI when the loaded design does not match. This script
# checks the design first and stops with a clear message instead.

if {[catch {examine /tb_PWM/pwmout_o}]} {
    error "wave_pwm.do: tb_PWM is not loaded. Run run_pwm_test.do first."
}

# Start from an empty window so reloading does not stack duplicate copies.
if {[catch {delete wave *}]} {
    # No wave window open yet; nothing to clear.
}

# The output itself, at the top where it is easiest to read.
add wave -divider "PWM output"
add wave -radix binary   /tb_PWM/pwmout_o

# What the software programmed. These stay constant for the whole run, which
# is the point of the fixed-duty test.
add wave -divider "control registers"
add wave -radix hex      /tb_PWM/DUT/btctl1_q
add wave -radix unsigned /tb_PWM/DUT/btcmpr0_q
add wave -radix unsigned /tb_PWM/DUT/btcmpr1_q
add wave -radix binary   /tb_PWM/DUT/btoutmd_w
add wave -radix binary   /tb_PWM/DUT/btouten_w

# The transparent compare latches are what the counter is actually compared
# against, so they are the values that shape the pulse.
add wave -divider "compare latches"
add wave -radix unsigned /tb_PWM/DUT/btcl0_latch_q
add wave -radix unsigned /tb_PWM/DUT/btcl1_latch_q

# BTCNT is the ramp; EQU1 raises PWMout and EQU0 lowers it.
add wave -divider "counter and compares"
add wave -radix unsigned /tb_PWM/DUT/btcnt_q
add wave -radix binary   /tb_PWM/DUT/equ1_w
add wave -radix binary   /tb_PWM/DUT/equ0_w

add wave -divider "clock and reset"
add wave -radix binary   /tb_PWM/smclk_i
add wave -radix binary   /tb_PWM/rst_i

# Widen the name column so the hierarchical paths stay readable.
if {[catch {
    configure wave -namecolwidth 260
    configure wave -valuecolwidth 90
    configure wave -justifyvalue left
    configure wave -timelineunits ns
    update
}]} {
    # Batch mode has no wave window to configure.
}

# Fit whatever has been simulated so far. No hardcoded time range: zooming to a
# fixed window that the run never reached is what made the old script unstable.
if {[catch {wave zoom full}]} {
    # Nothing simulated yet, or running without a GUI.
}
