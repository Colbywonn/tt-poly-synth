# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# Pin mapping (must match tt_um_colbywonn_poly_synth):
#   ui_in[0]  = MOSI
#   ui_in[1]  = SCLK
#   ui_in[2]  = CS_N
#   uo_out[0] = audio bitstream (sigma-delta, density encodes level)

MOSI_BIT = 0
SCLK_BIT = 1
CSN_BIT = 2

# SCLK phase width in system clocks. The receiver synchronises SCLK through
# two flops plus an edge-detect flop, so each phase must span several clocks.
PHASE = 6

# Tuning word for middle C at 12 MHz: round(261.63 * 2**32 / 12e6)
MIDDLE_C = 93641

# Config field: [3:2] = wave select, [1:0] = PWM width.
CFG_SAW = 0b0100  # wave=01 sawtooth


def pack(mosi, sclk, cs_n):
    """Compose the three SPI lines into the ui_in byte."""
    return (cs_n << CSN_BIT) | (sclk << SCLK_BIT) | (mosi << MOSI_BIT)


def audio_bit(dut):
    return dut.uo_out.value.to_unsigned() & 1


async def spi_frame(dut, addr, data):
    """Send one 35-bit frame: 3-bit address then 32-bit data, MSB first.

    CS low, then per bit present MOSI and pulse SCLK, then CS high to commit.
    """
    frame = (addr << 32) | data

    dut.ui_in.value = pack(0, 0, 0)          # assert chip select
    await ClockCycles(dut.clk, PHASE)

    for i in range(34, -1, -1):
        bit = (frame >> i) & 1
        dut.ui_in.value = pack(bit, 0, 0)    # present bit, SCLK low
        await ClockCycles(dut.clk, PHASE)
        dut.ui_in.value = pack(bit, 1, 0)    # rising edge: receiver samples
        await ClockCycles(dut.clk, PHASE)
        dut.ui_in.value = pack(bit, 0, 0)    # falling edge
        await ClockCycles(dut.clk, PHASE)

    await ClockCycles(dut.clk, PHASE)
    dut.ui_in.value = pack(0, 0, 1)          # release CS: frame commits here
    await ClockCycles(dut.clk, PHASE)


async def density(dut, window):
    """Count how many of the next `window` cycles the audio bit is high.

    The sigma-delta encodes level as the density of 1s, so this is the
    meaningful measurement -- the pin keeps toggling even when the synth
    is idle, because a constant level is a constant density, not a
    constant pin.
    """
    ones = 0
    for _ in range(window):
        await ClockCycles(dut.clk, 1)
        ones += audio_bit(dut)
    return ones


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset. CS idles high.
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = pack(0, 0, 1)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)

    WIN = 256

    # --- idle: all tuning words are zero, so the phase accumulators are
    # frozen. The output still toggles, but the density must not drift.
    dut._log.info("Check idle density is stable")
    idle_a = await density(dut, WIN)
    idle_b = await density(dut, WIN)
    assert idle_a == idle_b, (
        f"idle density drifted: {idle_a} then {idle_b} ones per {WIN} cycles "
        "(phase accumulators should be frozen with no tuning word loaded)"
    )

    # --- configure voice 0 for a sawtooth (address 3 = cfg0)
    dut._log.info("Load config")
    await spi_frame(dut, 3, CFG_SAW)

    # --- load middle C into voice 0's tuning word (address 0 = inc0)
    dut._log.info("Load middle C")
    await spi_frame(dut, 0, MIDDLE_C)

    # --- with a note running the output must actually toggle
    dut._log.info("Check output toggles")
    saw_hi = False
    saw_lo = False
    for _ in range(4000):
        await ClockCycles(dut.clk, 1)
        if audio_bit(dut):
            saw_hi = True
        else:
            saw_lo = True
        if saw_hi and saw_lo:
            break
    assert saw_hi and saw_lo, "audio output never toggled after loading a note"

    # --- the density must also move, since the waveform sweeps levels
    dut._log.info("Check density varies while playing")
    samples = [await density(dut, WIN) for _ in range(8)]
    assert len(set(samples)) > 1, (
        f"density never changed while a note was playing: {samples}"
    )

    # --- silence the voice: a zero tuning word freezes the phase again,
    # so the density should settle back to a constant.
    dut._log.info("Silence the voice")
    await spi_frame(dut, 0, 0)
    await ClockCycles(dut.clk, 200)

    quiet_a = await density(dut, WIN)
    quiet_b = await density(dut, WIN)
    assert quiet_a == quiet_b, (
        f"density still drifting after silencing: {quiet_a} then {quiet_b} "
        f"ones per {WIN} cycles"
    )

    dut._log.info("PASS")
