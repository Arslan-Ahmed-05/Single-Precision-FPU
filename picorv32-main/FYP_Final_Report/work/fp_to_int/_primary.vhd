library verilog;
use verilog.vl_types.all;
entity fp_to_int is
    port(
        a               : in     vl_logic_vector(31 downto 0);
        unsigned_flag   : in     vl_logic;
        result          : out    vl_logic_vector(31 downto 0)
    );
end fp_to_int;
