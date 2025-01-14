--==================================================================================
--
--  UartRx
--  Scott Tippens
--
--      Implements a UART receiver with configurable baud rate.  All standard 
--      baud rates are supported but the component is not limited to these rates since
--      input sampling is done based upon the system clock frequency.  It is up to
--      the designer to ensure the number of samples per bit time is sufficiently
--      high (recommend > 16).  Samples per bit time is calculated as:
--
--          CLOCK_FREQ / BAUD_RATE
--
--      Standard baud rates for reference are:
--      
--          9600, 19200, 38400, 57600, 115200, 230400,
--          460800, 921600, 1000000, 1500000
--
--      When a byte has been succesfully received by this component, it will trigger
--      a single pulse on 'dataReady' for one full system clock cycle.  This will be
--      sent immediately when the stop bit is sampled.
--
--      The design of this component assumes the received serial signal will provide 
--      no parity bit and utilize 1 stop bit.
--
--==================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UartRx is
    generic(
        BAUD_RATE: positive  := 115200;
        CLOCK_FREQ: positive := 100_000_000
        );
    port(
        clock:     in   std_logic;
        reset:     in   std_logic;
        rxData:    in   std_logic;
        dataReady: out  std_logic;
        dataOut:   out  std_logic_vector(7 downto 0)
        );
end UartRx;


architecture UartRx_ARCH of UartRx is

    constant ACTIVE: std_logic := '1';

    type states_t is (IDLE, START, DATA, STOP);
    signal state: states_t;

    signal holdEn:   std_logic;
    signal sampleEn: std_logic;

begin

    --=============================================================================
    --  SAMPLER
    --  Create sample signal for waveform sampling using the system clock rate
    --  and the specified baud rate.  The 'holdEn' signal is used to hold the
    --  sampler idle until a start pulse is detected.  It then generates the
    --  first sample at half the full bit count to capture the start pulse.  All other
    --  samples will be taken at the full bit count ensuring samples are taken
    --  in the center of the received pulse.
    --
    --  NOTE: The use of (FULL_COUNT/2)-2 for the half count is necessary to 
    --  account for the extra cycle required to transition to the START state once
    --  'holdEn' is deactivated.
    --=============================================================================
    SAMPLER: process(reset, clock)
        constant FULL_COUNT: integer := CLOCK_FREQ/BAUD_RATE;
        variable sampleCount: integer range 0 to FULL_COUNT-1;
    begin
        if (reset=ACTIVE) then
            sampleCount := (FULL_COUNT/2)-2;
            sampleEn <= not ACTIVE;
        elsif (rising_edge(clock)) then
            sampleEn <= not ACTIVE;  --default value
            if (holdEn=ACTIVE) then
                sampleCount := (FULL_COUNT/2)-2;
            else
                if (sampleCount=0) then
                    sampleCount := FULL_COUNT-1;
                    sampleEn    <= ACTIVE;
                else
                    sampleCount := sampleCount - 1;
                end if;
            end if;
        end if;
    end process;


    --=============================================================================
    --  RX_CONTROL
    --  Manage reception of UART byte based upon state of UART signal.  Initial
    --  state is IDLE while waiting for start pulse.  Note that 'dataOut' is not
    --  valid except when the 'dataReady' signal is active.
    --=============================================================================
    RX_CONTROL: process(reset, clock)
        variable bitCount: integer range 0 to 7;
    begin
        if (reset=ACTIVE) then
            bitCount  := 0;
            holdEn    <= ACTIVE;
            dataReady <= not ACTIVE;
            dataOut   <= (others=>'0');
        elsif (rising_edge(clock)) then
            holdEn    <= not ACTIVE;  --default value
            dataReady <= not ACTIVE;  --default value
            case state is
                -----------------------------------------------------------IDLE----
                --  Disable SAMPLER until start pulse edge detected
                -------------------------------------------------------------------
                when IDLE =>
                    holdEn <= ACTIVE;
                    if (rxData='0') then
                        holdEn <= not ACTIVE;
                        state  <= START;
                    end if;
                    
                ----------------------------------------------------------START----
                --  Wait for 'sampleEn' and read wave to verify start.  Initialize
                --  'bitCount' in preparation for receiving bits.
                -------------------------------------------------------------------
                when START =>
                    bitCount  := 0;
                    if (sampleEn=ACTIVE) then
                        if (rxData='0') then
                            state <= DATA;
                        else
                            state <= IDLE;  --false start
                        end if;
                    end if;

                -----------------------------------------------------------DATA----
                --  Sample bits using 'sampleEn' as trigger least significant bit
                --  first.  Increment 'bitCount' with each sample until the 7th
                --  and final bit received.
                --------------------------------------------------------------------
                when DATA =>
                    if (sampleEn=ACTIVE) then
                        dataOut(bitCount) <= rxData;
                        if (bitCount=7) then
                            state <= STOP;
                        else
                            bitCount := bitCount + 1;
                        end if;
                    end if;
                    
                -----------------------------------------------------------STOP----
                --  Activate 'dataReady' for one cycle when stop bit is sampled.
                -------------------------------------------------------------------
                when STOP =>
                    if (sampleEn=ACTIVE) then
                        dataReady <= ACTIVE;
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process RX_CONTROL;

end UartRx_ARCH;