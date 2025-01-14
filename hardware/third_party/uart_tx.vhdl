--==================================================================================
--
--  UartTx
--  Scott Tippens
--
--      Implements a UART transmitter with configurable baud rate.  All standard
--      baud rates are supported but the component is not limited to these rates since
--      output waveform creation is done based upon the system clock frequency.
--      Potential bit-time errors will be +/- the clock period time.
--
--      Standard baud rates for reference are:
--
--          9600, 19200, 38400, 57600, 115200, 230400,
--          460800, 921600, 1000000, 1500000
--
--      Byte transmission is initiated by an active signal on the 'txEn' control
--      line.  When a byte is being transmitted on this component, the 'txComplete'
--      signal will become inactive. A new byte can be transmitted when the
--      txComplete signal becomes active again.
--
--      You have one bit time from the activation of the txComplete signal to
--      initiate the next tranfer with no idle time between bytes.  If 'txEn' is
--      activated during the stop bit, the stop bit will continue to completion
--      before transmitting the new byte.
--
--      Input data will be latched into the transmit buffer and 'txComplete'
--      will become inactive one clock cycle after the 'txEn' signal has been
--      activated.  Note that 'txComplete' must be active before 'txEn' is seen.
--      You cannot initiate a new transmission until the previous one has finished.
--
--==================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UartTx is
    generic(
        BAUD_RATE: positive  := 115200;
        CLOCK_FREQ: positive := 100_000_000
        );
    port(
        clock:       in   std_logic;
        reset:       in   std_logic;
        txEn:        in   std_logic;
        dataIn:      in   std_logic_vector(7 downto 0);
        txComplete:  out  std_logic;
        dataOut:     out  std_logic
        );
end UartTx;


architecture UartTx_ARCH of UartTx is

    constant ACTIVE:     std_logic := '1';
    constant TX_IDLE:    std_logic := '1';
    constant START_BIT:  std_logic := '0';
    constant STOP_BIT:   std_logic := '1';
    constant FULL_COUNT: integer   := CLOCK_FREQ/BAUD_RATE;

    type states_t is (IDLE, START, DATA, STOP, QUEUED);
    signal state: states_t;

    signal bitTimeCount: integer range 0 to FULL_COUNT-1;
    signal dataBuffer:   std_logic_vector(7 downto 0);

begin

    --==============================================================================
    --  TX_CONTROL
    --  Manage the generation of the UART waveform using the 'bitTimeCount' signal as
    --  the time base for the transmittion.  When not transmitting, the 'dataOut'
    --  signal will idle HIGH.
    --==============================================================================
    TX_CONTROL: process(reset, clock)
        variable bitCount:     integer range 0 to 7;
    begin
        if (reset=ACTIVE) then
            bitCount     := 0;
            bitTimeCount <= 0;
            txComplete   <= ACTIVE;
            dataOut      <= TX_IDLE;
            dataBuffer   <= (others=>'0');
        elsif (rising_edge(clock)) then
            case state is
                -----------------------------------------------------------IDLE----
                --  Hold output idle until 'txEn' control signal detected.
                --  Latch input data when 'txEn' is active.
                -------------------------------------------------------------------
                when IDLE =>
                    txComplete <= ACTIVE;
                    dataOut <= TX_IDLE;
                    if (txEn=ACTIVE) then
                        txComplete   <= not ACTIVE;
                        bitTimeCount <= FULL_COUNT-1;
                        dataBuffer   <= dataIn;
                        dataOut      <= START_BIT;
                        state <= START;
                    end if;

                ----------------------------------------------------------START----
                --  Write start bit to output for full bit time duration.
                -------------------------------------------------------------------
                when START =>
                    txComplete <= not ACTIVE;
                    dataOut  <= START_BIT;
                    if (bitTimeCount=0) then
                        bitCount     := 0;
                        dataOut      <= dataBuffer(bitCount);
                        bitTimeCount <= FULL_COUNT-1;
                        state <= DATA;
                    else
                        bitTimeCount <= bitTimeCount - 1;
                    end if;

                -----------------------------------------------------------DATA----
                --  Transmit data bits LSB first.  Increment 'bitCount' with each
                --  'bitTimeCount' cycle until the 7th and final bit has been transmitted.
                --------------------------------------------------------------------
                when DATA =>
                    txComplete <= not ACTIVE;
                    dataOut    <= dataBuffer(bitCount);
                    if (bitTimeCount=0) then
                        bitTimeCount <= FULL_COUNT-1;
                        if (bitCount=7) then
                            txComplete <= ACTIVE;
                            dataOut    <= STOP_BIT;
                            state      <= STOP;
                        else
                            bitCount := bitCount + 1;
                            dataOut  <= dataBuffer(bitCount);
                        end if;
                    else
                        bitTimeCount <= bitTimeCount - 1;
                    end if;

                -----------------------------------------------------------STOP----
                --  Activate 'txComplete' as soon as stop bit begins.  If a transmit
                --  is enabled with the 'txEn' signal, queue byte and wait for stop
                --  bit to finish.  bit. If no transmit is initiated then go to IDLE
                --  state.
                -------------------------------------------------------------------
                when STOP =>
                    dataOut <= STOP_BIT;

                    ----handle-transmit-request-during-stop-bit-----------
                    if (txEn=ACTIVE) then
                        txComplete  <= not ACTIVE;
                        dataBuffer  <= dataIn;
                        if (bitTimeCount=0) then
                            bitTimeCount <= FULL_COUNT-1;
                            dataOut      <= START_BIT;
                            state <= START;
                        else
                            bitTimeCount <= bitTimeCount - 1;
                            state <= QUEUED;
                        end if;
                            
                    ----transition-to-idle-at-end-of-stop-bit-------------
                    elsif (bitTimeCount=0) then
                        state <= IDLE;

                    ----update-bit-time-counter---------------------------
                    else
                        bitTimeCount <= bitTimeCount - 1;
                    end if;


                ---------------------------------------------------------QUEUED----
                --  Wait until stop bit finishes before transitioning to the
                --  start of the next byte.
                -------------------------------------------------------------------
                when QUEUED =>
                    dataOut <= STOP_BIT;

                    ----wait-until-stop-bit-finished-before-new-start-----
                    if (bitTimeCount=0) then
                        bitTimeCount <= FULL_COUNT-1;
                        dataOut      <= START_BIT;
                        state        <= START;
                    else
                        bitTimeCount <= bitTimeCount - 1;
                    end if;

            end case;
        end if;
    end process TX_CONTROL;

end UartTx_ARCH;