library verilog;
use verilog.vl_types.all;
entity fp_minmax is
    port(
        a               : in     vl_logic_vector(31 downto 0);
        b               : in     vl_logic_vector(31 downto 0);
        op              : in     vl_logic;
        result          : out    vl_logic_vector(31 downto 0)
    );
end fp_minmax;
