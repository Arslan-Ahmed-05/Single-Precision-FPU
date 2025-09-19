library verilog;
use verilog.vl_types.all;
entity fpu is
    port(
        clk             : in     vl_logic;
        a               : in     vl_logic_vector(31 downto 0);
        b               : in     vl_logic_vector(31 downto 0);
        mem_data_in     : in     vl_logic_vector(31 downto 0);
        opcode          : in     vl_logic_vector(3 downto 0);
        load            : in     vl_logic;
        store           : in     vl_logic;
        address         : in     vl_logic_vector(31 downto 0);
        rd              : in     vl_logic_vector(4 downto 0);
        write_enable    : in     vl_logic;
        result          : out    vl_logic_vector(31 downto 0);
        mem_data_out    : out    vl_logic_vector(31 downto 0)
    );
end fpu;
