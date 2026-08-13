# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# Pin mapping (must match tt_um_colbywonn_poly_synth):
#   ui_in[0] = MOSI
#   ui_in[1] = SCLK
#   ui_in[2] = CS_N
#   uo_out[0] = audio bitstream

MOSI_BIT = 0
SCLK_BIT = 1
CSN_BIT = 2

# SCLK phase width in system clocks. The receiver syncs SCLK through two
# flops plus an edge-detect flop, so each phase must last several clocks.
PHASE = 6

# Tuning word for middle C at 12 MHz: round(261.63 * 2**32 / 12e6)
MIDDLE_C = 93641

# Config: [3:2] = wave select, [1:0] = PWM. 0b1100 selects triangle.
CFG_TRIANGLE = 0b1100


def pack(mosi, sclk, cs_n):
    """Compose the three SPI lines into the ui_in byte."""
    return (cs_n << CSN_BIT) | (sclk << SCLK_BIT) | (mosi << MOSI_BIT)


async def spi_frame(dut, addr, data):
    """Send one 35-bit frame: 3-bit address then 32-bit data, MSB first.

    Mirrors the hardware protocol: CS low, then per bit present MOSI and
    pulse SCLK, then CS high to commit.
    """
    frame = (addr << 32) | data

    # assert chip select
    dut.ui_in.value = pack(0, 0, 0)
    await ClockCycles(dut.clk, PHASE)

    for i in range(34, -1, -1):
        bit = (frame >> i) & 1
        # present the bit while SCLK is low
        dut.ui_in.value = pack(bit, 0, 0)
        await ClockCycles(dut.clk, PHASE)
        # rising edge: receiver samples here
        dut.ui_in.value = pack(bit, 1, 0)
        await ClockCycles(dut.clk, PHASE)
        # falling edge
        dut.ui_in.value = pack(bit, 0, 0)
        await ClockCycles(dut.clk, PHASE)

    # release chip select; commit happens on this rising edge
    await ClockCycles(dut.clk, PHASE)
    dut.ui_in.value = pack(0, 0, 1)
    await ClockCycles(dut.clk, PHASE)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset. CS idles high, so hold ui_in with CS_N set.
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = pack(0, 0, 1)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # With no tuning word loaded, the phase accumulators are frozen and the
    # output should sit at a constant level.
    dut._log.info("Check silence after reset")
    first = dut.uo_out.value.integer & 1
    stuck = True
    for _ in range(200):
        await ClockCycles(dut.clk, 1)
        if (dut.uo_out.value.integer & 1) != first:
            stuck = False
            break
    assert stuck, "output toggled before any note was loaded"

    # Configure voice 0 for a triangle wave (address 3 = cfg0).
    dut._log.info("Load config")
    await spi_frame(dut, 3, CFG_TRIANGLE)

    # Load middle C into voice 0's tuning word (address 0 = inc0).
    dut._log.info("Load middle C")
    await spi_frame(dut, 0, MIDDLE_C)

    # The modulator should now be producing a bitstream: uo_out[0] must
    # take both values over a reasonable window.
    dut._log.info("Check output toggles")
    saw_hi = False
    saw_lo = False
    for _ in range(2000):
        await ClockCycles(dut.clk, 1)
        if dut.uo_out.value.integer & 1:
            saw_hi = True
        else:
            saw_lo = True
        if saw_hi and saw_lo:
            break
    assert saw_hi and saw_lo, "audio output never toggled after loading a note"

    # Silence the voice again and confirm the output settles.
    dut._log.info("Silence the voice")
    await spi_frame(dut, 0, 0)
    await ClockCycles(dut.clk, 100)

    settled = dut.uo_out.value.integer & 1
    quiet = True
    for _ in range(200):
        await ClockCycles(dut.clk, 1)
        if (dut.uo_out.value.integer & 1) != settled:
            quiet = False
            break
    assert quiet, "output still toggling after the voice was silenced"

    dut._log.info("PASS")
