library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SYS_CTR_PASS_FLAG is
    port (
        clk : in std_logic;
        reset : in std_logic;
        NL_start : in std_logic;
        NL_finished : in std_logic;
        r : in std_logic_vector (7 downto 0);
        M_div_pt : in std_logic_vector (7 downto 0);
        WB_NL_finished : in std_logic;
        ACT_NL_finished : in std_logic;
        pass_flag : out std_logic
         );
end SYS_CTR_PASS_FLAG;

architecture behavioral of SYS_CTR_PASS_FLAG is

    -- Enumeration type for the states and state_type signals
    type state_type is (s_init, s_idle, s_cnt_1, s_cnt_2, s_flag);
    signal state_next, state_reg: state_type;

    -- ************** FSMD SIGNALS **************
    ------------ CONTROL PATH SIGNALS ------------
    -------- INPUTS --------
    ---- Internal Status Signals from the Data Path
    signal WB_NL_cnt_reg, WB_NL_cnt_next : natural range 0 to 127;
    signal ACT_NL_cnt_reg, ACT_NL_cnt_next : natural range 0 to 127;
    signal ACT_pass_cnt_reg, ACT_pass_cnt_next : natural range 0 to 127;
    signal ACT_flag_reg, ACT_flag_next : std_logic;
 
    ---- External Command Signals to the FSMD
    signal NL_start_int : std_logic;
    signal NL_finished_int : std_logic;

    -------- OUTPUTS --------
    ---- Internal Control Signals used to control Data Path Operation
    -- ..

    ---- External Status Signals to indicate status of the FSMD
    signal pass_cnt_ready_int : std_logic;

    ------------ DATA PATH SIGNALS ------------
    ---- Data Registers Signals
    -- ..

    ---- External Control Signals used to control Data Path Operation
    signal WB_NL_finished_int : std_logic;
    signal ACT_NL_finished_int : std_logic;
    signal M_div_pt_int : natural range 0 to 127;
    signal r_int : natural range 0 to 127;

    ---- Functional Units Intermediate Signals
    -- ..
    -- ******************************************

    ---------------- Data Outputs ----------------
    signal pass_flag_int : std_logic;

begin

    -- control path : state register
    asmd_reg : process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= s_init;
            else
                state_reg <= state_next;
            end if;
        end if;
    end process;

    -- control path : next state logic
    asmd_ctrl : process(state_reg, NL_start_int, WB_NL_cnt_reg, ACT_NL_cnt_reg, ACT_pass_cnt_reg, NL_finished_int, r_int, M_div_pt_int, ACT_flag_reg)
    begin
        case state_reg is
            when s_init =>
                state_next <= s_idle;
            when s_idle =>
                if NL_start_int = '1' then
                    state_next <= s_cnt_1;
                else
                    state_next <= s_idle;
                end if;
            when s_cnt_1 =>
                if ((WB_NL_cnt_reg < r_int) OR (ACT_NL_cnt_reg < r_int)) then
                    state_next <= s_cnt_1;
                else
                    state_next <= s_flag;
                end if;
            when s_cnt_2 =>
                if (M_div_pt_int < 2) then
                    state_next <= s_cnt_1;
                else
                    if (WB_NL_cnt_reg < r_int) then
                        state_next <= s_cnt_2;
                    else
                        state_next <= s_flag;
                    end if;
                end if;
            when s_flag =>
                if (NL_finished_int = '1') then
                    state_next <= s_idle;
                else
                    if (ACT_flag_reg = '0') then
                        state_next <= s_cnt_2;
                    else
                        state_next <= s_cnt_1;
                    end if;
                end if;
            when others =>
                state_next <= s_init;
        end case;
    end process;

    -- control path : output logic
    pass_cnt_ready_int <= '1' when state_reg = s_idle else '0';
    pass_flag_int <= '1' when state_reg = s_flag else '0';

    -- data path : data registers
    data_reg : process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                WB_NL_cnt_reg <= 0;
                ACT_NL_cnt_reg <= 0;
                ACT_pass_cnt_reg <= 0;
                ACT_flag_reg <= '0';
            else
                WB_NL_cnt_reg <= WB_NL_cnt_next;
                ACT_NL_cnt_reg <= ACT_NL_cnt_next;
                ACT_pass_cnt_reg <= ACT_pass_cnt_next;
                ACT_flag_reg <= ACT_flag_next;
            end if;
        end if;
    end process;

    -- data path : functional units (perform necessary arithmetic operations)
    -- ..

    -- data path : status (inputs to control path to modify next state logic)
    -- ..

    -- data path : mux routing
    data_mux : process(state_reg, WB_NL_finished_int, ACT_NL_finished_int, WB_NL_cnt_reg, ACT_NL_cnt_reg, ACT_pass_cnt_reg, r_int, M_div_pt_int, ACT_flag_reg)

    variable WB_NL_cnt_var : natural range 0 to 127;
    variable ACT_NL_cnt_var : natural range 0 to 127;

    begin
        case state_reg is
            when s_init =>
                WB_NL_cnt_next <= WB_NL_cnt_reg;
                ACT_NL_cnt_next <= ACT_NL_cnt_reg;
                ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                ACT_flag_next <= ACT_flag_reg;
            when s_idle =>
                WB_NL_cnt_next <= WB_NL_cnt_reg;
                ACT_NL_cnt_next <= ACT_NL_cnt_reg;
                ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                ACT_flag_next <= ACT_flag_reg;
            when s_cnt_1 =>
                if (WB_NL_finished_int = '1') then
                    WB_NL_cnt_var := WB_NL_cnt_reg + 1;
                else
                    WB_NL_cnt_var := WB_NL_cnt_reg;
                end if;

                if (ACT_NL_finished_int = '1') then
                    ACT_NL_cnt_var := ACT_NL_cnt_reg + 1;
                else
                    ACT_NL_cnt_var := ACT_NL_cnt_reg;
                end if;

                if ((WB_NL_cnt_reg < r_int) OR (ACT_NL_cnt_reg < r_int)) then
                    WB_NL_cnt_next <= WB_NL_cnt_var;
                    ACT_NL_cnt_next <= ACT_NL_cnt_var;
                else
                    WB_NL_cnt_next <= 0;
                    ACT_NL_cnt_next <= 0;
                end if;

                ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                ACT_flag_next <= '0';


            when s_cnt_2 =>
                if (WB_NL_finished_int = '1') then
                    WB_NL_cnt_var := WB_NL_cnt_reg + 1;
                else
                    WB_NL_cnt_var := WB_NL_cnt_reg;
                end if;

                if (M_div_pt_int < 2) then
                    ACT_flag_next <= '1';
                    ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                    WB_NL_cnt_next <= WB_NL_cnt_reg;
                else
                    if (WB_NL_cnt_reg < r_int) then
                        WB_NL_cnt_next <= WB_NL_cnt_var;
                        ACT_flag_next <= '0';
                        ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                    else
                        WB_NL_cnt_next <= 0;
                        if (ACT_pass_cnt_reg < M_div_pt_int - 1 - 1) then
                            ACT_flag_next <= '0';
                            ACT_pass_cnt_next <= ACT_pass_cnt_reg + 1;
                        else
                            ACT_flag_next <= '1';
                            ACT_pass_cnt_next <= 0;
                        end if;
                    end if;
                end if;

                ACT_NL_cnt_next <= ACT_NL_cnt_reg;

            when s_flag =>
                WB_NL_cnt_next <= WB_NL_cnt_reg;
                ACT_NL_cnt_next <= ACT_NL_cnt_reg;
                ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                ACT_flag_next <= ACT_flag_reg;

            when others =>
                WB_NL_cnt_next <= WB_NL_cnt_reg;
                ACT_NL_cnt_next <= ACT_NL_cnt_reg;
                ACT_pass_cnt_next <= ACT_pass_cnt_reg;
                ACT_flag_next <= ACT_flag_reg;

        end case;
    end process;

    -- PORT Assignations
    NL_start_int <= NL_start;
    NL_finished_int <= NL_finished;
    r_int <= to_integer(unsigned(r));
    M_div_pt_int <= to_integer(unsigned(M_div_pt));
    WB_NL_finished_int <= WB_NL_finished;
    ACT_NL_finished_int <= ACT_NL_finished;
    pass_flag <= pass_flag_int;

end architecture;