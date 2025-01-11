-- Do I do pipelined math here?
-- That would end up with a lot of chip space (and mental effort) used for some small slope calculations, or do I accept a cost of ~96 clock cycles per triangle *here* (which the area of a half triangle can overtake)


-- I do pipelined math here, feeding into the 2 triangle pipelines


-- All of this will be tested by writing a *single* triangle over UART, then multiple

-- I could also write a testbench that reports positions and colors and then something in rust that will write said things, allowing me to debug the dang thing

-- That would be useful before connecting this to UART


entity TrianglePlotter is
    Port(
        clock: in std_logic;
        reset: in std_logic;

        x1: in signed(15 downto 0);
        y1: in signed(7 downto 0);
        z1: in signed(15 downto 0);

        x2: in signed(15 downto 0);
        y2: in signed(7 downto 0);
        z2: in signed(15 downto 0);

        x3: in signed(15 downto 0);
        y3: in signed(7 downto 0);
        z3: in signed(15 downto 0);

        color: in std_logic_vector(4 downto 0);

        hasValue: in std_logic;

        readyMode: out std_logic;
        pipelineEmpty: out std_logic;

        pixelInfoA: out PixelEntry;
        plotEnA: out std_logic;

        pixelInfoB: out PixelEntry;
        plotEnB: out std_logic;
    );
end TrianglePlotter;