-------------------------------------------------------------------------------------------------------
-- Project        : Memory Efficient Hardware Accelerator for CNN Inference & Training
-- Program        : Master's Thesis in Embedded Electronics Engineering (EEE)
-------------------------------------------------------------------------------------------------------
-- File           : SRAM_WB_BACK_END.vhd
-- Author         : Sergio Castillo Mohedano
-- University     : Lund University
-- Department     : Electrical and Information Technology (EIT)
-- Created        : 2022-07-04
-- Standard       : VHDL-2008
-------------------------------------------------------------------------------------------------------
-- Description    : Weights & Biases SRAM BACK-End Interface
-------------------------------------------------------------------------------------------------------
-- Input Signals  :
--         * clk: clock
--         * reset: synchronous, active high.
--         * ...
-- Output Signals :
--         * ...
-------------------------------------------------------------------------------------------------------
-- Revisions      : NA (Git Control)
-------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM_WB_BACK_END is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- Front-End Interface Ports
        wb_FE : out std_logic_vector (7 downto 0);
        RE_FE : in std_logic;   -- Read Enable, active high

        -- SRAM Wrapper Ports (READ)
        clkb : out std_logic;
        rstb : out std_logic;
        addrb : out std_logic_vector (16 downto 0);
        doutb : in std_logic_vector (15 downto 0);
        enb : out std_logic
        -- SRAM Wrapper Ports (WRITE)
--        clka : out std_logic;
--        rsta : out std_logic;
--        addra : out std_logic_vector (14 downto 0);
--        dina : in std_logic_vector (31 downto 0);
--        ena : out std_logic;
--        wea : std_logic_vector (0 downto 0)
    );
end SRAM_WB_BACK_END;

architecture behavioral of SRAM_WB_BACK_END is

    -- Enumeration type for the states and state_type signals
    type state_type is (s_init, s_idle, s_0, s_3);
    signal state_next, state_reg: state_type;

    ------------ CONTROL PATH SIGNALS ------------
    -------- INPUTS --------
    ---- Internal Status Signals from the Data Path
    -- ..

    ---- External Command Signals to the FSMD
    signal RE_tmp : std_logic;

    -------- OUTPUTS --------
    ---- Internal Control Signals used to control Data Path Operation
    -- ..

    ---- External Status Signals to indicate status of the FSMD
    -- ..

    ------------ DATA PATH SIGNALS ------------
    ---- Data Registers Signals
    signal addr_cnt_reg : unsigned (16 downto 0);
    signal addr_cnt_next : unsigned (16 downto 0);

    ---- External Control Signals used to control Data Path Operation (they do NOT modify next state outcome)
    -- ..

    ---- Functional Units Intermediate Signals
    -- ..

    ---- Data Outputs
    signal wb_FE_tmp : std_logic_vector (7 downto 0);
    signal enb_tmp : std_logic;

    -- SRAM_WB_BACK_END Intermediate Signals
    signal clkb_tmp : std_logic;
    signal rstb_tmp : std_logic;
    signal doutb_tmp : std_logic_vector (15 downto 0);

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
    asmd_ctrl : process(state_reg, RE_tmp )
    begin
        case state_reg is
            when s_init =>
                state_next <= s_idle;
            when s_idle =>
                if (RE_tmp = '1') then
                    state_next <= s_0;
                else
                    state_next <= s_idle;
                end if;
            when s_0 =>
                state_next <= s_3;
            when s_3 =>
                if (RE_tmp = '1') then
                    state_next <= s_0;
                else
                    state_next <= s_idle;
                end if;
            when others =>
                state_next <= s_init;
        end case;
    end process;

    -- control path : output logic

    -- data path : data registers
    data_reg : process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                addr_cnt_reg <= (others => '0');
            else
                addr_cnt_reg <= addr_cnt_next;
            end if;
        end if;
    end process;

    -- data path : mux routing
    data_mux : process(state_reg, RE_tmp , doutb_tmp , addr_cnt_reg)
    begin
        case state_reg is
            when s_init =>
                wb_FE_tmp <= (others => '0');
                enb_tmp <= '0';
                addr_cnt_next <= addr_cnt_reg;
            when s_idle =>
                wb_FE_tmp <= (others => '0');
                addr_cnt_next <= addr_cnt_reg;
                enb_tmp <= '0';
            when s_0 =>
                wb_FE_tmp <= doutb_tmp (7 downto 0); -- 8 MSBs (I'm taking now 8lsb for testing)
                addr_cnt_next <= addr_cnt_reg + 1;
                if (RE_tmp = '1') then
                    enb_tmp <= '1';
                else
                    enb_tmp <= '0';
                end if;
            when s_3 =>
                wb_FE_tmp <= doutb_tmp (7 downto 0); -- 8 MSBs (I'm taking now 8lsb for testing)
                addr_cnt_next <= addr_cnt_reg + 1;
                enb_tmp <= '1';
            when others =>
                wb_FE_tmp <= (others => '0');
                addr_cnt_next <= addr_cnt_reg;
                enb_tmp <= '0';
        end case;
    end process;

    -- PORT Assignations
    clkb_tmp <= clk;
    clkb <= clkb_tmp ;
    rstb_tmp <= reset;
    rstb <= rstb_tmp ;
    RE_tmp <= RE_FE;
    addrb <= std_logic_vector(addr_cnt_reg);
    enb <= enb_tmp ;
    doutb_tmp <= doutb;
    wb_FE <= wb_FE_tmp ;

end architecture;