library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_geometry.all;

package basys3d_communication is
    constant REQUEST_MAX_TRIANGLE_COUNT: std_logic_vector(7 downto 0) := X"01";
    constant TRANSMIT_OBJECT: std_logic_vector(7 downto 0) := X"02";
    constant NACK: std_logic_vector(7 downto 0) := X"FF";

    component UartRx is
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
    end component;
    
    component UartTx is
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
    end component;

    component Transceiver is
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
    end component;
end basys3d_communication;


package body basys3d_communication is
end basys3d_communication;