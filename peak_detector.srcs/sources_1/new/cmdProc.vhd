----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2020 11:12:40
-- Design Name: 
-- Module Name: cmdProcessor - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
-- synthesis translate_off
use UNISIM.VPKG.ALL;
-- synthesis translate_on

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cmdProc is
    port (
          clk : in std_logic;
          reset : in std_logic;
          rxnow : in std_logic;     --valid
          rxData : in std_logic_vector (7 downto 0);    --data_rx
          txData : out std_logic_vector (7 downto 0);   --data_tx
          rxdone : out std_logic;   --done
          ovErr : in std_logic; --oe
          framErr : in std_logic;   --fe
          txnow : out std_logic;    --txNow
          txdone : in std_logic;    --txDone
          start : out std_logic;    --start
          numWords_bcd : out BCD_ARRAY_TYPE(2 downto 0);    --numWords
          dataReady : in std_logic; --dataReady
          byte : in std_logic_vector(7 downto 0);   --byte
          maxIndex : in BCD_ARRAY_TYPE(2 downto 0); --maxIndex
          dataResults : in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1); --dataResults
          seqDone : in std_logic    --seqDone
        );
end cmdProc;

architecture Behavioral of cmdProc is
signal oe, fe, valid, start_reg, rxdone_reg: std_logic;   --内部寄存器信号单比特
signal data_rx, data_tx : std_logic_vector(7 downto 0); --内部寄存器信号多比特
signal numWords_bcd_reg : BCD_ARRAY_TYPE(2 downto 0);
signal memory : CHAR_ARRAY_TYPE(998 downto 0);  --memory for maximum 999 bytes
signal counter, counter_full: std_logic_vector(9 downto 0); -- maximum 999

type state_type IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, dataConsumer_communication_A, tx_A_init, tx_A);   --定义状�?�机中的变量
signal curState, nextState: state_type; --状�?�变�???????

begin
--------------主状态机过程--------------------------

combi_nextState: PROCESS(curState, valid, data_rx, seqDone, dataReady)
begin
    case curState is
        when INIT =>    --状�?�机初始状�??
            if valid = '1' then
                nextState <= RX_INIT;
            else
                nextState <= INIT;
            end if;

        when RX_INIT => --状�?�机接收状�??
            if fe = '1' and valid = '1' then
                nextState <= RX_INIT;
            elsif data_rx = "01000001" or data_rx = "01100001" then --A or a
                nextState <= RX_A;
            elsif data_rx = "01010000" or data_rx = "01110000" then --P or p
                nextState <= RX_P;
            elsif data_rx = "01001100" or data_rx = "01101100" then --L or l
                nextState <= RX_L;
            else
                nextState <= RX_INIT;
            end if;             

        when RX_A =>
            if fe = '1' and valid = '1' then
                nextState <= RX_INIT;
            elsif data_rx >= "00110000" and data_rx <= "00111001" and valid = '1' then --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_1;                  
            else
                nextState <= RX_A;
            end if;
        when RX_A_1 =>
            if fe = '1' and valid = '1' then
                nextState <= RX_INIT;
            elsif data_rx >= "00110000" and data_rx <= "00111001" and valid = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_2;                  
            else
                nextState <= RX_A_1;
            end if;
        when RX_A_2 =>
            if fe = '1' and valid = '1' then
                nextState <= RX_INIT;
            elsif data_rx >= "00110000" and data_rx <= "00111001" and valid = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= dataConsumer_communication_A;                  
            else
                nextState <= RX_A_2;
            end if;
        when dataConsumer_communication_A =>
            if seqDone = '1' then
                nextState <= tx_A_init;
            elsif dataReady = '1' then
                nextState <= dataConsumer_communication_A;
            else
                nextState <= dataConsumer_communication_A;
            end if;
        when tx_A_init =>
            if txdone = '0' then
                nextState <= tx_A;
            else
                nextState <= tx_A_init;
            end if;
        when tx_A =>
            if counter = counter_full then
                nextState <= INIT;
            elsif txdone = '1' then
                nextState <= tx_A;
            else
                nextState <= tx_A;
            end if;
        when others =>
            nextState <= INIT;
    end case;
end process; 
---------------状�?�变量赋值控制过�????----------------------------------
seq_state: process (clk, reset)
begin
  if reset = '1' then
    curState <= INIT;
  elsif clk'event and clk='1' then
    curState <= nextState;
  end if;
end process; -- seq
------------信号寄存控制过程--------------------------
registers: process(clk)
begin
    if clk'event and clk='1' then
        data_rx <= rxData;
        oe <= ovErr;
        fe <= framErr;
        valid <= rxnow;
    else
        data_rx <= data_rx;
        oe <= oe;
        fe <= fe;
        valid <= valid;
    end if;
end process;
----------输出信号控制过程--------------------------
combi_out: process(clk, curState, nextState, dataReady, seqDone, txdone)
begin
    if clk'event and clk='1' then
        if reset = '1' then
            rxdone_reg <= '0';
            start_reg <= '0';
            numWords_bcd_reg(0) <= "0000";
            numWords_bcd_reg(1) <= "0000";
            numWords_bcd_reg(2) <= "0000";
            counter <= "0000000000";
            txnow <= '0';
        else
            if nextState = RX_INIT and curState = INIT then
                rxdone_reg <= '1';
            elsif nextState = RX_A and curState = RX_INIT then
                rxdone_reg <= '1';
            elsif nextState = RX_A_1 and curState = RX_A then
                numWords_bcd_reg(2) <= data_rx(3 downto 0);
                rxdone_reg <= '1';
            elsif nextState = RX_A_2 and curState = RX_A_1 then
                numWords_bcd_reg(1) <= data_rx(3 downto 0);
                start_reg <= '0';
                rxdone_reg <= '1';
            elsif nextState = dataConsumer_communication_A and curState = RX_A_2 then
                numWords_bcd_reg(0) <= data_rx(3 downto 0);
                start_reg <= '1';
            elsif nextState = tx_A_init and curState <= dataConsumer_communication_A then
                start_reg <= '0';
            elsif curState = dataConsumer_communication_A and dataReady = '1' then
                memory(to_integer(unsigned(counter))) <= byte;
                counter <= std_logic_vector(unsigned(counter) + "0000000001");
            elsif curState = tx_A_init and nextState = tx_A_init then
                counter_full <= counter;
            elsif curState = tx_A_init then
                counter <= "0000000000";
                txData <= memory(0);
                txnow <= '1';
            elsif curState = tx_A and txdone = '1' then
                txData <= memory(to_integer(unsigned(counter)));
                txnow <= '1';
                counter <= std_logic_vector(unsigned(counter) + "0000000001");
            else
                rxdone_reg <= rxdone_reg;
                start_reg <= start_reg;
                numWords_bcd_reg <= numWords_bcd_reg;
                counter <= counter;
                txnow <= '0';
            end if;
        end if;
    end if;
end process; -- combi_output
numWords_bcd <= numWords_bcd_reg;
rxdone <= rxdone_reg;
start <= start_reg;
end Behavioral;
