library verilog;
use verilog.vl_types.all;
entity int_to_fp is
    port(
        a               : in     vl_logic_vector(31 downto 0);
        unsigned_flag   : in     vl_logic;
        result          : out    vl_logic_vector(31 downto 0)
    );
end int_to_fp;
