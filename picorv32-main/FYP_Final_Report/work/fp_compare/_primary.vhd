library verilog;
use verilog.vl_types.all;
entity fp_compare is
    port(
        a               : in     vl_logic_vector(31 downto 0);
        b               : in     vl_logic_vector(31 downto 0);
        op              : in     vl_logic_vector(1 downto 0);
        result_bit      : out    vl_logic;
        result_lt       : out    vl_logic;
        result_le       : out    vl_logic
    );
end fp_compare;
