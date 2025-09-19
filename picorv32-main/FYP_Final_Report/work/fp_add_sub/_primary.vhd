library verilog;
use verilog.vl_types.all;
entity fp_add_sub is
    port(
        a               : in     vl_logic_vector(31 downto 0);
        b               : in     vl_logic_vector(31 downto 0);
        add_sub         : in     vl_logic;
        result          : out    vl_logic_vector(31 downto 0)
    );
end fp_add_sub;
