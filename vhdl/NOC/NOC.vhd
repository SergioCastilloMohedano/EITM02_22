library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity NOC is
    generic (
        -- HW Parameters, at shyntesis time.
        X          : natural range 0 to 255 := 32;
        Y          : natural range 0 to 255 := 3;
        hw_log2_r  : integer_array          := (0, 1, 2);
        hw_log2_EF : integer_array          := (5, 4, 3)
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- config. parameters
        C_cap   : in std_logic_vector (7 downto 0);
        HW_p    : in std_logic_vector (7 downto 0);
        EF_log2 : in std_logic_vector (7 downto 0);
        r_log2  : in std_logic_vector (7 downto 0);

        -- from sys ctrl
        h_p         : in std_logic_vector (7 downto 0);
        rc          : in std_logic_vector (7 downto 0);
        r_p         : in std_logic_vector (7 downto 0);
        WB_NL_busy  : in std_logic;
        IFM_NL_busy : in std_logic;
        -- from SRAMs
        ifm_sram : in std_logic_vector (7 downto 0);
        w_sram   : in std_logic_vector (7 downto 0)
    );
end NOC;

architecture structural of NOC is

    -- SIGNAL DEFINITIONS
    -- MC_Y to MC_X
    signal ifm_enable_y_to_x : std_logic_array(0 to (Y - 1));
    signal ifm_y_to_x        : std_logic_vector_array(0 to (Y - 1));
    signal w_enable_y_to_x   : std_logic_array(0 to (Y - 1));
    signal w_y_to_x          : std_logic_vector_array(0 to (Y - 1));

    -- MC_X to PE
    signal ifm_x_to_PE        : std_logic_vector_2D_array(0 to (X - 1))(0 to (Y - 1));
    signal ifm_status_x_to_PE : std_logic_2D_array(0 to (X - 1))(0 to (Y - 1));
    signal w_x_to_PE          : std_logic_vector_2D_array(0 to (X - 1))(0 to (Y - 1));
    signal w_status_x_to_PE   : std_logic_2D_array(0 to (X - 1))(0 to (Y - 1));

    -- MC_rr to MC_X
    signal rr_tmp : std_logic_vector_array(0 to (X - 1));

    -- Delay Signals
    signal h_p_reg         : std_logic_vector (7 downto 0);
    signal r_p_reg         : std_logic_vector (7 downto 0);
    signal rc_reg          : std_logic_vector (7 downto 0);
    signal IFM_NL_busy_reg : std_logic;
    signal WB_NL_busy_reg  : std_logic;

    -- COMPONENT DECLARATIONS
    component PE is
        port (
            clk           : in std_logic;
            reset         : in std_logic;
            ifm_PE        : out std_logic_vector (7 downto 0);
            ifm_status_PE : out std_logic;
            w_PE          : out std_logic_vector (7 downto 0);
            w_status_PE   : out std_logic
            -- ...
        );
    end component;

    -- component MC_FC is
    --     port (
    --         -- ...
    --     );
    -- end component;

    component MC_Y is
        generic (
            Y_ID : natural range 0 to 255 := 1;
            Y    : natural range 0 to 255 := 3
        );
        port (
            HW_p         : in std_logic_vector (7 downto 0);
            h_p          : in std_logic_vector (7 downto 0);
            r_p          : in std_logic_vector (7 downto 0);
            WB_NL_busy   : in std_logic;
            IFM_NL_busy  : in std_logic;
            ifm_y_in     : in std_logic_vector (7 downto 0);
            ifm_y_out    : out std_logic_vector(7 downto 0);
            ifm_y_status : out std_logic;
            w_y_in       : in std_logic_vector (7 downto 0);
            w_y_out      : out std_logic_vector (7 downto 0);
            w_y_status   : out std_logic
        );
    end component;

    component MC_X is
        generic (
            Y_ID      : natural range 0 to 255 := 3;
            X_ID      : natural range 0 to 255 := 16;
            Y         : natural range 0 to 255 := 3;
            hw_log2_r : integer_array          := (0, 1, 2)
        );
        port (
            EF_log2      : in std_logic_vector (7 downto 0);
            C_cap        : in std_logic_vector (7 downto 0);
            r_log2       : in std_logic_vector (7 downto 0);
            h_p          : in std_logic_vector (7 downto 0);
            rc           : in std_logic_vector (7 downto 0);
            rr           : in std_logic_vector (7 downto 0);
            ifm_x_enable : in std_logic;
            ifm_x_in     : in std_logic_vector (7 downto 0);
            ifm_x_out    : out std_logic_vector (7 downto 0);
            ifm_x_status : out std_logic;
            w_x_enable   : in std_logic;
            w_x_in       : in std_logic_vector (7 downto 0);
            w_x_out      : out std_logic_vector (7 downto 0);
            w_x_status   : out std_logic
        );
    end component;

    component MC_rr is
        generic (
            X_ID       : natural range 0 to 255 := 1;
            hw_log2_EF : integer_array          := (5, 4, 3)
        );
        port (
            EF_log2 : in std_logic_vector (7 downto 0);
            rr      : out std_logic_vector (7 downto 0)
        );
    end component;

begin

    -- -- PE ARRAY
    -- PE_ARRAY_X_loop : for i in 0 to (X - 1) generate
    --     PE_ARRAY_Y_loop : for j in 0 to (Y - 1) generate
    --         PE_inst : PE
    --         port map(
    --             clk   => clk,
    --             reset => reset
    --             -- ..
    --         );
    --     end generate PE_ARRAY_Y_loop;
    -- end generate PE_ARRAY_X_loop;

    -- -- MC FC ROW
    -- MC_FC_ROW_loop : for i in 0 to (X - 1) generate
    --     MC_FC_inst : MC_FC
    --     port map(
    --         -- ..
    --     );
    -- end generate MC_FC_ROW_loop;

    -- MC ARRAY
    MC_X_COLUMNS_loop : for i in 0 to (X - 1) generate
        MC_X_ROWS_loop : for j in 0 to (Y - 1) generate
            MC_X_inst : MC_X
            generic map(
                Y_ID      => j + 1,
                X_ID      => i + 1,
                Y         => Y,
                hw_log2_r => hw_log2_r
            )
            port map(
                EF_log2      => EF_log2,
                C_cap        => C_cap,
                r_log2       => r_log2,
                h_p          => h_p_reg,
                rc           => rc_reg,
                rr           => rr_tmp(i),
                ifm_x_enable => ifm_enable_y_to_x(j),
                ifm_x_in     => ifm_y_to_x(j),
                ifm_x_out    => ifm_x_to_PE(i)(j),
                ifm_x_status => ifm_status_x_to_PE(i)(j),
                w_x_enable   => w_enable_y_to_x(j),
                w_x_in       => w_y_to_x(j),
                w_x_out      => w_x_to_PE(i)(j),
                w_x_status   => w_status_x_to_PE(i)(j)
            );
        end generate MC_X_ROWS_loop;
    end generate MC_X_COLUMNS_loop;

    -- MC Y COLUMN
    MC_Y_COLUMN_loop : for i in 0 to (Y - 1) generate
        MC_Y_inst : MC_Y
        generic map(
            Y_ID => i + 1,
            Y    => Y
        )
        port map(
            HW_p         => HW_p,
            h_p          => h_p_reg,
            r_p          => r_p_reg,
            WB_NL_busy   => WB_NL_busy_reg,
            IFM_NL_busy  => IFM_NL_busy_reg,
            ifm_y_in     => ifm_sram,
            ifm_y_out    => ifm_y_to_x(i),
            ifm_y_status => ifm_enable_y_to_x(i),
            w_y_in       => w_sram,
            w_y_out      => w_y_to_x(i),
            w_y_status   => w_enable_y_to_x(i)
        );
    end generate MC_Y_COLUMN_loop;

    -- MC rr ROW
    MC_rr_ROW_loop : for i in 0 to (X - 1) generate
        MC_rr_inst : MC_rr
        generic map(
            X_ID       => i + 1,
            hw_log2_EF => hw_log2_EF
        )
        port map(
            EF_log2 => EF_log2,
            rr      => rr_tmp(i)
        );
    end generate MC_rr_ROW_loop;

    -- process to register sys ctrl. parameters, as they need 1 clk delay
    -- as to account with the 1clk delay generated from the memories.
    REG_PROC : process (clk)
    begin
        if rising_edge(clk) then
            h_p_reg         <= h_p;
            r_p_reg         <= r_p;
            rc_reg          <= rc;
            IFM_NL_busy_reg <= IFM_NL_busy;
            WB_NL_busy_reg  <= WB_NL_busy;
        end if;
    end process;

end architecture;