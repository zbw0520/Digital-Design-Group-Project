---------------------------------------------------------------------------------
-- Company: UoB
-- Engineer: B.Zhang
-- 
-- Create Date: 2020/03/07 09:08:50
-- Design Name: dataConsumer
-- Module Name: dataConsume - Behavioral
-- Project Name: peak_detector
-- Target Devices: xc7a35tcpg236-1
-- Tool Versions: vivado 2017.4
-- Description: dataConsumer module enable the whole system to communicate with datagen
-- 
-- Dependencies: 
-- 
-- Revision: 1.0
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
use ieee.std_logic_unsigned.all;
-- synthesis translate_off
use UNISIM.VPKG.ALL;
-- synthesis translate_on

entity dataConsume is
    port (
        clk:            in std_logic;
        reset:          in std_logic; -- synchronous reset
        start:          in std_logic; -- goes high to signal data transfer
        numWords_bcd:   in BCD_ARRAY_TYPE(2 downto 0);
        ctrlIn:         in std_logic;   --data valid input signal
        ctrlOut:        out std_logic;  --data request output signal
        data:           in std_logic_vector(7 downto 0);
        dataReady:      out std_logic;
        byte:           out std_logic_vector(7 downto 0);
        seqDone:        out std_logic;
        maxIndex:       out BCD_ARRAY_TYPE(2 downto 0);
        dataResults:    out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
    );
end dataConsume;

architecture Behavioral of dataConsume is
signal ctrlIn_reg_n, ctrlIn_reg, ctrlOut_reg, ctrlOut_reg_n, seqDone_int, seqDone_int_n, ctrlIn_reg_edge, ctrlIn_reg_edge_n: std_logic;
signal counter, counter_n: BCD_ARRAY_TYPE(2 downto 0);
signal byte_reg, byte_reg_n: std_logic_vector(7 downto 0);
signal dataResults_reg, dataResults_reg_n: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
signal f_dataReady, f_dataReady_n, ff_dataReady_n: std_logic;
signal ssign_reg, ssign_reg_n: std_logic;
signal datahalfside_reg, datahalfside_reg_n: CHAR_ARRAY_TYPE(0 to 2);
signal maxIndex_reg_n, maxIndex_reg: BCD_ARRAY_TYPE(2 downto 0);

type state_type IS (INIT, start_data_gen, complete_data_gen, complete_all_data_gen);   --define the state type
signal curState, nextState: state_type; --state variables
type state_L_type IS (INIT, start_L, L_1, L_2, L_3, L_4);
signal curState_l, nextState_l: state_l_type;

begin
byte <= data;
ctrlOut <= ctrlOut_reg;
seqDone <= seqDone_int;
dataResults <= dataResults_reg;
maxIndex <= maxIndex_reg;

-------------------------state machine register------------------------
combi_state: process(curState, start, counter, counter_n, ctrlIn_reg, ctrlIn_reg_n, seqDone_int)
begin
    case curState is
        when INIT =>
            if start = '1' then
                nextState <= start_data_gen;
            else
                nextState <= INIT;
            end if;
        when start_data_gen =>
            if counter /= counter_n  then
                nextState <= complete_data_gen;
            else
                nextState <= start_data_gen;
            end if;
        when complete_data_gen=>
            if counter_n(0) = "0000" and counter_n(1) = "0000" and counter_n(2) = "0000" then
                nextState <= complete_all_data_gen;
            elsif ctrlIn_reg = ctrlIn_reg_n and start = '1' then
                nextState <= start_data_gen;
            else    
                nextState <= complete_data_gen;
            end if;
        when complete_all_data_gen =>
            if seqDone_int = '1' then
                nextState <= INIT;
            else
                nextState <= complete_all_data_gen;
            end if;
        when others =>
            nextState <= INIT;
            
    end case;
end process;

seq_state: process(clk, reset)
begin
    if rising_edge(clk) then
        if (reset = '1') then
            curState <= INIT;
        else
            curState <= nextState;
        end if;
    end if;
end process;
-------------------------ctrlOut register------------------------
combi_ctrlOut: process(ctrlOut_reg, reset, curState, nextState, counter_n, numWords_bcd, start)
begin
    if reset = '1' then
        ctrlOut_reg_n <= '0';
    elsif ctrlOut_reg = '1' and curState = start_data_gen and nextState = start_data_gen then
        if (counter_n(0) /= numWords_bcd(0) or counter_n(1) /= numWords_bcd(1) or counter_n(2) /= numWords_bcd(2)) then
            ctrlOut_reg_n <= '0';
        else
            ctrlOut_reg_n <= ctrlOut_reg;
        end if;
    elsif ctrlOut_reg = '0' and curState = start_data_gen and nextState = start_data_gen and start = '1' then
        if (counter_n(0) /= numWords_bcd(0) or counter_n(1) /= numWords_bcd(1) or counter_n(2) /= numWords_bcd(2)) then
            ctrlOut_reg_n <= '1';
        else
            ctrlOut_reg_n <= ctrlOut_reg;
        end if;
    else
        ctrlOut_reg_n <= ctrlOut_reg;
    end if;
end process;

seq_ctrlOut: process(clk, reset)
begin
    if rising_edge(clk) then
        if (reset = '1') then
            ctrlOut_reg <= '0';
        else
            ctrlOut_reg <= ctrlOut_reg_n;
        end if;
    end if;
end process;
-------------------------ctrlIn register------------------------
combi_ctrlIn: process(ctrlIn_reg, ctrlIn, reset)
begin
    if reset = '1' then
        ctrlIn_reg_n <= '0';
    else
        ctrlIn_reg_n <= ctrlIn;
    end if;
end process;

seq_ctrlIn: process(clk, reset)
begin
    if rising_edge(clk) then
        if (reset = '1') then
            ctrlIn_reg <= '0';
        else
            ctrlIn_reg <= ctrlIn_reg_n;
        end if;
    end if;
end process;
---------------------counter(0)_bcdcoding_adder------------------------------------
combi_counter0: process(reset, counter, ctrlOut_reg, ctrlIn,numWords_bcd)
begin
    if reset = '1' then
        counter_n(0) <= "0000";
    elsif counter(0)= numWords_bcd(0) and counter(1)= numWords_bcd(1) and counter(2)= numWords_bcd(2) then
        counter_n(0) <= "0000";
    elsif ctrlIn /= ctrlOut_reg then
        if counter(0) = "1001" then
            counter_n(0) <= "0000";
        else
            counter_n(0) <= counter(0) + "0001";
        end if;
    else    
        counter_n(0) <= counter(0);
    end if;
end process;

seq_counter0: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter(0) <= "0000";
        else
            counter(0) <= counter_n(0);
        end if;
    end if;
end process;
---------------------counter(1)_bcdcoding_adder------------------------------------
combi_counter1: process(reset, counter, ctrlOut_reg, ctrlIn,numWords_bcd)
begin
    if reset = '1' then
        counter_n(1) <= "0000";
    elsif counter(0)= numWords_bcd(0) and counter(1)= numWords_bcd(1) and counter(2)= numWords_bcd(2) then
        counter_n(1) <= "0000";
    elsif counter(0) = "1001" and ctrlIn /= ctrlOut_reg then
        if counter(1) = "1001" then
            counter_n(1) <= "0000";
        else
            counter_n(1) <= counter(1) + "0001";
        end if;
    else    
        counter_n(1) <= counter(1);
    end if;
end process;

seq_counter1: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter(1) <= "0000";
        else
            counter(1) <= counter_n(1);
        end if;
    end if;
end process;
---------------------counter(2)_bcdcoding_adder------------------------------------
combi_counter2: process(reset, counter, ctrlOut_reg, ctrlIn,numWords_bcd)
begin
    if reset = '1' then
        counter_n(2) <= "0000";
    elsif counter(0)= numWords_bcd(0) and counter(1)= numWords_bcd(1) and counter(2)= numWords_bcd(2) then
        counter_n(2) <= "0000";
    elsif counter(1) = "1001" and counter(0) = "1001" and ctrlIn /= ctrlOut_reg then
        if counter(2) = "1001" then
            counter_n(2) <= "0000";
        else
            counter_n(2) <= counter(2) + "0001";
        end if;
    else
        counter_n(2) <= counter(2);
    end if;
end process;

seq_counter2: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter(2) <= "0000";
        else
            counter(2) <= counter_n(2);
        end if;
    end if;
end process;
------------------------dataReady combinatorial logic-------------------------
combi_dataReady: process(curState, ctrlIn_reg_edge, ctrlIn_reg_edge_n)
begin
    dataReady <= '0';
    if (curState = complete_data_gen or curState = complete_all_data_gen) and ctrlIn_reg_edge /= ctrlIn_reg_edge_n then
        dataReady <= '1';
    end if;
end process;
------------------------seqDone_int combinatorial logic-------------------------
combi_seqDone_int: process(curState, ctrlIn_reg,counter)
begin
    if curState = complete_all_data_gen and counter(0)= "0000" and counter(1)= "0000" and counter(2)= "0000" then
        seqDone_int_n <= '1';
    else
        seqDone_int_n <= '0';
    end if;
end process;
seq_seqDone_int: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            seqDone_int <= '0';
        else
            seqDone_int <= seqDone_int_n;
        end if;
    end if;
end process;
-------------------------ctrlIn_reg_edge register------------------------
combi_ctrlIn_reg_edge: process(ctrlIn_reg, reset)
begin
    if reset = '1' then
        ctrlIn_reg_edge_n <= '0';
    else
        ctrlIn_reg_edge_n <= ctrlIn_reg;
    end if;
end process;

seq_ctrlIn_reg_edge: process(clk, reset)
begin
    if rising_edge(clk) then
        if (reset = '1') then
            ctrlIn_reg_edge <= '0';
        else
            ctrlIn_reg_edge <= ctrlIn_reg_edge_n;
        end if;
    end if;
end process;
------------------------byte assignment register------------------------------
combi_byte: process(reset, byte_reg, ctrlIn_reg, ctrlIn_reg_n,data)
begin
    if reset = '1' then
        byte_reg_n <= "00000000";
    elsif ctrlIn_reg /= ctrlIn_reg_n then
        byte_reg_n <= data;
    else
        byte_reg_n <= byte_reg;
    
    end if;
end process;

seq_byte: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            byte_reg <= "00000000";
        else
            byte_reg <= byte_reg_n;
        end if;
    end if;
end process;
----------------------dataResults register----------------------------------
--combi_dataResults_reg: process(reset, byte_reg, ctrlIn_reg, ctrlIn_reg_n)
--begin
--    if reset = '1' then
--        dataResults_reg_n <= (others => "00000000");
--    elsif ctrlIn_reg /= ctrlIn_reg_n then
--        if dataResults_reg(3) < data then
--            dataResults_reg_n(3) <= data;
--        else
--            dataResults_reg_n <= dataResults_reg;
--        end if;
--    else
--        dataResults_reg_n <= dataResults_reg;
    
--    end if;
--end process;

--seq_dataResults_reg: process(clk, reset)
--begin
--    if rising_edge(clk) then
--        if reset = '1' then
--            dataResults_reg <= (others => "00000000");
--        else
--            dataResults_reg <= dataResults_reg_n;
--        end if;
--    end if;
--end process;
--------------------fake dataReady used as flags----------------------------------------
combi_f_dataReady: process(curState, ctrlIn_reg_edge, ctrlIn_reg_edge_n)
begin
    ff_dataReady_n <= '0';
    if (curState = complete_data_gen or curState = complete_all_data_gen) and ctrlIn_reg_edge /= ctrlIn_reg_edge_n then
        ff_dataReady_n <= '1';
    end if;
end process;

seq_f_dataReady_reg: process(clk, reset)
begin
    if rising_edge(clk) then
        f_dataReady <= f_dataReady_n;
    end if;
end process;
seq_ff_dataReady_reg: process(clk, reset)
begin
    if rising_edge(clk) then
        f_dataReady_n <= ff_dataReady_n;
    end if;
end process;
--------------------dataResults state-------------------------------------
combi_dataResults_state: process(curState_l, f_dataReady, f_dataReady_n, ff_dataReady_n,byte_reg,ssign_reg)
begin
    case curState_l is
        when INIT =>
            if (byte_reg > "00000000" and byte_reg <= "11111111" and ff_dataReady_n = '0' and f_dataReady_n = '1') then
                nextState_l <= start_L;
            else
                nextState_l <= INIT;
            end if;

        when start_L =>
            if  (ff_dataReady_n = '0' and f_dataReady_n = '1' and ssign_reg = '0') then
                nextState_l <= L_1;
            else
                nextState_l <= curState_l;
            end if;

        when L_1 =>
            if (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '0') then
                nextState_l <= L_2; 
            elsif (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '1') then
                nextState_l <= start_L;
            else
                nextState_l <= curState_l;
            end if;

        when L_2 =>
            if (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '0') then
                nextState_l <= L_3; 
            elsif (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '1') then
                nextState_l <= start_L;                
            else
                nextState_l <= curState_l;
            end if;

        when L_3 =>
            if (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '0') then
                nextState_l <= L_4; 
            elsif (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '1') then
                nextState_l <= start_L;
            else
                nextState_l <= curState_l;
            end if;
            
        when L_4 =>  
            if (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '0') then
                nextState_l <= L_4; 
            elsif (ff_dataReady_n = '0' and f_dataReady_n  = '1' and ssign_reg = '1') then
                nextState_l <= start_L;
            else
                nextState_l <= curState_l;
            end if;
      
        when others =>
            nextState_l <= INIT;
            
    end case;
end process;

seq_dataResults_state: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            curState_l <= INIT;
        else
            curState_l <= nextState_l;
        end if;
    end if;
end process;
-------------------dataResult halfside registor----------------------
combi_halfside_reg: process(f_dataReady_n, f_dataReady,datahalfside_reg,byte_reg)
begin
    if (f_dataReady = '1' and f_dataReady_n = '0') then
        datahalfside_reg_n(0) <=  datahalfside_reg(1);
        datahalfside_reg_n(1) <=  datahalfside_reg(2);
        datahalfside_reg_n(2) <=  byte_reg;    
    else
        datahalfside_reg_n <= datahalfside_reg;  
    end if;
end process;

seq_halfside_reg: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            datahalfside_reg <= (others => "00000000");
        else
            datahalfside_reg <= datahalfside_reg_n;
        end if;
    end if;
end process;
--------------------dataResult Compare sign------------------------
combi_dataResults_sign: process(ctrlIn_reg_edge_n, ctrlIn_reg_edge,ssign_reg,curState_l,byte_reg,dataResults_reg)
begin
    if curState_l = INIT then
        ssign_reg_n <= '0';
    elsif ctrlIn_reg_edge /= ctrlIn_reg_edge_n then
        if byte_reg(7) > dataResults_reg(3)(7) then
            ssign_reg_n <= '0';
        elsif byte_reg(7) < dataResults_reg(3)(7) then
            ssign_reg_n <= '1';
        elsif byte_reg(7) = '1' and dataResults_reg(3)(7) = '1' and byte_reg(6 downto 0) < dataResults_reg(3)(6 downto 0) then
            ssign_reg_n <= '1';
        elsif byte_reg(7) = '1' and dataResults_reg(3)(7) = '1' and byte_reg(6 downto 0) > dataResults_reg(3)(6 downto 0) then
            ssign_reg_n <= '0';
        elsif byte_reg(7) = '0' and dataResults_reg(3)(7) ='0' and byte_reg(6 downto 0) < dataResults_reg(3)(6 downto 0) then
            ssign_reg_n <= '0';
        elsif byte_reg(7) = '0' and dataResults_reg(3)(7) = '0' and byte_reg(6 downto 0) > dataResults_reg(3)(6 downto 0) then
            ssign_reg_n <= '1';
        else
            ssign_reg_n <= '0';
        end if;
    else
        ssign_reg_n <= ssign_reg;
    end if;

end process;

seq_dataResults_sign: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            ssign_reg <= '0';
        else
            ssign_reg <= ssign_reg_n;
        end if;
    end if;
end process;
--------------------dataResult output---------------------
combi_dataResults_reg: process(curState_l, reset, f_dataReady_n, f_dataReady,ssign_reg,dataResults_reg,byte_reg,datahalfside_reg)
begin
    if  reset = '1' then
        dataResults_reg_n <= (others => "00000000");
    else
        case curState_l is
            when start_L =>
                if (ssign_reg = '1' and f_dataReady = '1' and f_dataReady_n = '0')then
                    dataResults_reg_n(0) <= dataResults_reg(0);
                    dataResults_reg_n(1) <= dataResults_reg(1);
                    dataResults_reg_n(2) <= dataResults_reg(2);
                    dataResults_reg_n(3) <= byte_reg;
                    dataResults_reg_n(4) <= datahalfside_reg(2);
                    dataResults_reg_n(5) <= datahalfside_reg(1);
                    dataResults_reg_n(6) <= datahalfside_reg(0);                    
                else
                    dataResults_reg_n <= dataResults_reg;
                end if;
    
            when L_1 =>
                if (f_dataReady = '1' and f_dataReady_n = '0')then
                    dataResults_reg_n(0) <= dataResults_reg(0);
                    dataResults_reg_n(1) <= dataResults_reg(1);
                    dataResults_reg_n(2) <= byte_reg;
                    dataResults_reg_n(3) <= dataResults_reg(3);
                    dataResults_reg_n(4) <= dataResults_reg(4);
                    dataResults_reg_n(5) <= dataResults_reg(5);
                    dataResults_reg_n(6) <= dataResults_reg(6);  
                else
                    dataResults_reg_n <= dataResults_reg;
                end if;
            when L_2 =>
                if (f_dataReady = '1' and f_dataReady_n = '0')then
                    dataResults_reg_n(0) <= dataResults_reg(0);
                    dataResults_reg_n(1) <= byte_reg;
                    dataResults_reg_n(2) <= dataResults_reg(2);
                    dataResults_reg_n(3) <= dataResults_reg(3);
                    dataResults_reg_n(4) <= dataResults_reg(4);
                    dataResults_reg_n(5) <= dataResults_reg(5);
                    dataResults_reg_n(6) <= dataResults_reg(6);  
                else
                    dataResults_reg_n <= dataResults_reg;
                end if;
            when L_3 =>
                if (f_dataReady = '1' and f_dataReady_n = '0')then
                    dataResults_reg_n(0) <= byte_reg;
                    dataResults_reg_n(1) <= dataResults_reg(1);
                    dataResults_reg_n(2) <= dataResults_reg(2);
                    dataResults_reg_n(3) <= dataResults_reg(3);
                    dataResults_reg_n(4) <= dataResults_reg(4);
                    dataResults_reg_n(5) <= dataResults_reg(5);
                    dataResults_reg_n(6) <= dataResults_reg(6); 
                else
                    dataResults_reg_n <= dataResults_reg;
                end if;

            when others =>
                dataResults_reg_n <= dataResults_reg;
        end case;
    end if;
end process;

seq_dataResults_reg: process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            dataResults_reg <= (others => "00000000");
        else
            dataResults_reg <= dataResults_reg_n;
        end if;
    end if;
end process;
------------------maxIndex register-------------------------------
combi_maxIndex_reg: process(f_dataReady, f_dataReady_n, maxIndex_reg,curState_l,counter)
begin
    if (f_dataReady = '1' and f_dataReady_n = '0' and curState_l = start_L) then
        maxIndex_reg_n <= counter;
    else
        maxIndex_reg_n <= maxIndex_reg;
    end if;
end process;

seq_maxIndex_reg:process(clk, reset)
begin
    if rising_edge(clk) then
        if reset = '1' then
            maxIndex_reg(0) <= "0000";
            maxIndex_reg(1) <= "0000";
            maxIndex_reg(2) <= "0000";
        else
            maxIndex_reg <= maxIndex_reg_n;
        end if;
    end if;    
end process;

end Behavioral;
