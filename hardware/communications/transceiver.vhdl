library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_geometry.all;
use work.basys3d_communication.all;

entity Transceiver is
    generic (
        MAX_TRIANGLE_COUNT: integer range 0 to 65535
    );
    port(
        clock: in std_logic;
        reset: in std_logic;

        rx: in std_logic;
        tx: out std_logic;

        geoWriteAddress: out integer range 0 to MAX_TRIANGLE_COUNT-1;
        geoWriteData: out GeoTriangle;
        geoWriteEn: out std_logic;
        triangleCount: out integer range 0 to MAX_TRIANGLE_COUNT
    );
end Transceiver;

architecture Procedural of Transceiver is

    -- uart signals
    signal dataOut: std_logic_vector(7 downto 0);
    signal dataReady: std_logic;
    signal dataIn: std_logic_vector(7 downto 0);
    signal txEn: std_logic;
    signal txComplete: std_logic;

    -- Mirrored outputs
    signal trigCountInternal : integer range 0 to MAX_TRIANGLE_COUNT := 0;
begin

    -- Mirror the output
    triangleCount <= trigCountInternal;

    -- Control the UART adapters

    CONTROL_UART: process(clock, reset)
    
        type uart_state_t is (
            Waiting,
            SendingHeader,
            SendingTrigLow,
            SendingTrigHigh,
            ReadingTrigLow,
            ReadingTrigHigh,
            Refusing,
            Acknowledging,
            ReadingTriangle
        );

        variable uart_state: uart_state_t := Waiting;

        type geo_array_t is array(0 to 26) of std_logic_vector(7 downto 0);

        variable geo_array: geo_array_t;
        variable geo_array_index: integer range 0 to 26;

        variable read_trig_low: std_logic_vector(7 downto 0);
        variable read_trig_high: std_logic_vector(7 downto 0);

        variable geo_addr: integer range 0 to MAX_TRIANGLE_COUNT-1;
        variable read_trig_count: integer range 0 to 65535;
        
        function combineLe(a: in std_logic_vector(7 downto 0); b: std_logic_vector(7 downto 0)) return std_logic_vector is
            variable combined: std_logic_vector(15 downto 0);
        begin
            combined(7 downto 0) := a;
            combined(15 downto 8) := b;
            return combined;
        end function;


        -- Stall in between sends for a certain amount of cycles
        variable stallCycles: integer range 0 to 3 := 3;
    begin
        if reset then
            uart_state := Waiting;
        elsif rising_edge(clock) then
            txEn <= '0';
            geoWriteEn <= '0';
            read_trig_count := 0;
            case uart_state is
                when Waiting =>
                    if dataReady then
                        if dataOut = REQUEST_MAX_TRIANGLE_COUNT then
                            dataIn <= REQUEST_MAX_TRIANGLE_COUNT; -- Respond with header
                            txEn <= '1';
                            stallCycles := 3;
                            uart_state := SendingHeader;
                        elsif dataOut = TRANSMIT_OBJECT then
                            uart_state := ReadingTrigLow;
                        end if;
                    end if;
                when SendingHeader =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif txComplete then
                        dataIn <= std_logic_vector(to_unsigned(MAX_TRIANGLE_COUNT mod 256, 8));
                        txEn <= '1';
                        stallCycles := 3;
                        uart_state := SendingTrigLow;
                    end if;
                when SendingTrigLow =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif txComplete then
                        dataIn <= std_logic_vector(to_unsigned(MAX_TRIANGLE_COUNT / 256, 8));
                        txEn <= '1';
                        stallCycles := 3;
                        uart_state := SendingTrigHigh;
                    end if;
                when SendingTrigHigh =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif txComplete then
                        uart_state := Waiting;
                    end if;
                when ReadingTrigLow =>
                    if dataReady then
                        read_trig_low := dataOut;
                        uart_state := ReadingTrigHigh;
                    end if;
                when ReadingTrigHigh =>
                    if dataReady then
                        read_trig_high := dataOut;
                        read_trig_count := to_integer(unsigned(combineLe(read_trig_low,read_trig_high)));
                        if read_trig_count > MAX_TRIANGLE_COUNT or read_trig_count = 0 then
                            dataIn <= NACK;
                            txEn <= '1';
                            stallCycles := 3;
                            uart_state := Refusing;
                        else
                            trigCountInternal <= read_trig_count;
                            dataIn <= TRANSMIT_OBJECT;
                            txEn <= '1';
                            stallCycles := 3;
                            uart_state := Acknowledging;
                        end if;
                    end if;
                when Refusing =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif txComplete then
                        uart_state := Waiting;
                    end if;
                when Acknowledging =>
                    if txComplete then
                        geo_array_index := 0;
                        geo_addr := 0;
                        uart_state := ReadingTriangle;
                    end if;
                when ReadingTriangle =>
                    if dataReady then
                        geo_array(geo_array_index) := dataOut;
                        if geo_array_index = 26 then
                            geoWriteAddress <= geo_addr;
                            geoWriteData <= (
                                A => (signed(combineLe(geo_array(0),geo_array(1))),signed(combineLe(geo_array(2),geo_array(3))),signed(combineLe(geo_array(4),geo_array(5)))),
                                B => (signed(combineLe(geo_array(6),geo_array(7))),signed(combineLe(geo_array(8),geo_array(9))),signed(combineLe(geo_array(10),geo_array(11)))),
                                C => (signed(combineLe(geo_array(12),geo_array(13))),signed(combineLe(geo_array(14),geo_array(15))),signed(combineLe(geo_array(16),geo_array(17)))),
                                N => (signed(combineLe(geo_array(18),geo_array(19))(9 downto 0)),signed(combineLe(geo_array(20),geo_array(21))(9 downto 0)),signed(combineLe(geo_array(22),geo_array(23))(9 downto 0))),
                                COL => (unsigned(geo_array(24)(4 downto 0)),unsigned(geo_array(25)(4 downto 0)),unsigned(geo_array(26)(4 downto 0)))
                            );
                            geoWriteEn <= '1';
                            if geo_addr = trigCountInternal-1 then
                                uart_state := Waiting;
                            else
                                geo_array_index := 0;
                                geo_addr := geo_addr + 1;
                            end if;
                        else
                            geo_array_index := geo_array_index + 1;
                        end if;
                    end if;
            end case;
        end if;
    end process;

    -- Uart adapters
    RECEIVER: UartRx
    port map (
      clock     => clock,
      reset     => reset,
      rxData    => rx,
      dataReady => dataReady,
      dataOut   => dataOut
    );

    TRANSMITTER: UartTx
    port map (
      clock      => clock,
      reset      => reset,
      txEn       => txEn,
      dataIn     => dataIn,
      txComplete => txComplete,
      dataOut    => tx
    );
end Procedural;