library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_geometry.all;
use work.basys3d_communication.all;

entity TransceiverTest is
end TransceiverTest;

architecture TB of TransceiverTest is
    -- Uart receiver signals
    signal receivedData: std_logic_vector(7 downto 0);
    signal dataReady: std_logic;

    -- Uart transmitter signals
    signal transmittedData: std_logic_vector(7 downto 0);
    signal transmitDataEn: std_logic;
    signal transmitReadyMode: std_logic;

    -- Transceiver signals
    signal rxData: std_logic;
    signal txData: std_logic;
    signal address: integer range 0 to 65534;
    signal data: GeoTriangle;
    signal writeEn: std_logic;

    -- Begin test case insertion
    constant TEST_CASE_LENGTH: integer := 165;
    type test_case_array_t is array (0 to TEST_CASE_LENGTH-1) of std_logic_vector(7 downto 0);
    constant test_case: test_case_array_t := (X"02", X"06", X"00", X"00", X"00", X"A0", X"16", X"00", X"00", X"60", X"E9", X"60", X"E9", X"00", X"00", X"00", X"00", X"60", X"E9", X"60", X"E9", X"56", X"FF", X"55", X"00", X"56", X"FF", X"1F", X"1F", X"1F", X"00", X"00", X"A0", X"16", X"00", X"00", X"00", X"00", X"60", X"E9", X"60", X"E9", X"A0", X"16", X"60", X"E9", X"00", X"00", X"AA", X"00", X"55", X"00", X"56", X"FF", X"1F", X"1F", X"1F", X"00", X"00", X"A0", X"16", X"00", X"00", X"00", X"00", X"60", X"E9", X"A0", X"16", X"60", X"E9", X"60", X"E9", X"00", X"00", X"56", X"FF", X"55", X"00", X"AA", X"00", X"1F", X"1F", X"1F", X"00", X"00", X"A0", X"16", X"00", X"00", X"A0", X"16", X"60", X"E9", X"00", X"00", X"00", X"00", X"60", X"E9", X"A0", X"16", X"AA", X"00", X"55", X"00", X"AA", X"00", X"1F", X"1F", X"1F", X"00", X"00", X"60", X"E9", X"60", X"E9", X"60", X"E9", X"60", X"E9", X"00", X"00", X"A0", X"16", X"60", X"E9", X"00", X"00", X"00", X"00", X"00", X"FF", X"00", X"00", X"1F", X"1F", X"1F", X"00", X"00", X"60", X"E9", X"A0", X"16", X"A0", X"16", X"60", X"E9", X"00", X"00", X"60", X"E9", X"60", X"E9", X"00", X"00", X"00", X"00", X"00", X"FF", X"00", X"00", X"1F", X"1F", X"1F");
    -- End test case insertion

    signal clock: std_logic;
    signal reset: std_logic;
begin

    CLOCK_RESET: process
    begin
        clock <= '0';
        reset <= '1';
        wait for 10 ns;
        reset <= '0';
        loop
            clock <= '0';
            wait for 5 ns;
            clock <= '1';
            wait for 5 ns;
        end loop;
    end process;

    TEST_CASE_DRIVER: process
    begin
        -- Let's first hammer out a request for the triangle count
        wait until rising_edge(clock);
        transmittedData <= REQUEST_MAX_TRIANGLE_COUNT;
        transmitDataEn <= '1';
        wait until rising_edge(clock);
        transmitDataEn <= '0';
        
        -- Wait for the response to be received
        wait until rising_edge(dataReady);
        wait until rising_edge(clock);
        wait until rising_edge(dataReady);
        wait until rising_edge(clock);
        wait until rising_edge(dataReady);
        wait until rising_edge(clock);

        transmittedData <= test_case(0);
        transmitDataEn <= '1';
        wait until rising_edge(clock);
        transmitDataEn <= '0';
        wait until rising_edge(clock);
        wait until transmitReadyMode = '1';
        wait until rising_edge(clock);
        transmittedData <= test_case(1);
        transmitDataEn <= '1';
        wait until rising_edge(clock);
        transmitDataEn <= '0';
        wait until rising_edge(clock);
        wait until transmitReadyMode = '1';
        wait until rising_edge(clock);
        transmittedData <= test_case(2);
        transmitDataEn <= '1';
        wait until rising_edge(clock);
        transmitDataEn <= '0';
        wait until rising_edge(clock);
        wait until transmitReadyMode = '1';
        wait until rising_edge(clock);
        wait until rising_edge(dataReady);
        wait until rising_edge(clock);
        if receivedData = X"FF" then
            report "Transceiver gave a NAK!";
            wait;
        end if;
        for i in 3 to TEST_CASE_LENGTH-1 loop
            transmittedData <= test_case(i);
            transmitDataEn <= '1';
            wait until rising_edge(clock);
            transmitDataEn <= '0';
            wait until rising_edge(clock);
            wait until transmitReadyMode = '1';
            wait until rising_edge(clock);
        end loop;
        wait;
    end process;

    Rx: UartRx
    port map (
      clock     => clock,
      reset     => reset,
      rxData    => txData,
      dataReady => dataReady,
      dataOut   => receivedData
    );

    Tx: UartTx
    port map (
      clock      => clock,
      reset      => reset,
      txEn       => transmitDataEn,
      dataIn     => transmittedData,
      txComplete => transmitReadyMode,
      dataOut    => rxData
    );

    TXRX: Transceiver
    generic map (
      MAX_TRIANGLE_COUNT => 65535
    )
    port map (
      clock           => clock,
      reset           => reset,
      rx              => rxData,
      tx              => txData,
      geoWriteAddress => address,
      geoWriteData    => data,
      geoWriteEn      => writeEn
    );

    RxReporter: process
    begin
        wait until rising_edge(clock);
        if dataReady then
            report "Received UART: " & to_hex_string(receivedData);
        end if;
    end process;

    GeoReporter: process
    begin
        wait until rising_edge(clock);
        if writeEn then
            ReportTrig(data);
        end if;
    end process;
end TB;