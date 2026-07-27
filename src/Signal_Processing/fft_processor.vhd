-- ============================================================================
-- 8-Point FFT Processor (Radix-2, Decimation in Time)
-- ============================================================================
-- The Fast Fourier Transform (FFT) converts a time-domain signal into its
-- frequency-domain components. An 8-point FFT uses 3 stages (log2(8) = 3),
-- each stage containing 4 butterfly operations.
--
-- A butterfly computes:
--   A = a + b * W    (upper output)
--   B = a - b * W    (lower output)
-- where W = cos(theta) - j*sin(theta) is the "twiddle factor".
--
-- Complex multiplication: (br + j*bi)(c + js) = (br*c - bi*s) + j*(br*s + bi*c)
--
-- Fixed-point: data is 16-bit signed (Q2.14), twiddle factors also Q2.14.
-- Multiplications produce 32-bit results, shifted right by 14 to rescale.
--
-- The input is loaded sequentially (8 samples), bit-reversed internally,
-- processed through 3 stages, then output sequentially in natural order.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fft_processor is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;            -- active-high synchronous reset
        data_in_re  : in  signed(15 downto 0);  -- real part of input sample
        data_in_im  : in  signed(15 downto 0);  -- imaginary part of input sample
        data_in_valid : in  std_logic;          -- pulse to load one sample
        data_out_re : out signed(15 downto 0);  -- real part of output
        data_out_im : out signed(15 downto 0);  -- imaginary part of output
        data_out_valid : out std_logic;         -- pulse when output sample ready
        ready       : out std_logic             -- '1' when can accept new input
    );
end entity fft_processor;

architecture rtl of fft_processor is

    -- Complex data array: 8 points, each with real and imaginary parts
    type complex_array_t is array (0 to 7) of signed(15 downto 0);
    signal re_buf : complex_array_t := (others => (others => '0'));
    signal im_buf : complex_array_t := (others => (others => '0'));

    -- Twiddle factor ROM: W8^k = cos(2*pi*k/8) - j*sin(2*pi*k/8)
    -- Values in Q2.14 fixed-point (multiply by 2^14)
    -- W8^0 =  1 + 0j     -> c=16384,  s=0
    -- W8^1 =  0.707 - 0.707j -> c=11585,  s=-11585
    -- W8^2 =  0 - 1j     -> c=0,      s=-16384
    -- W8^3 = -0.707 - 0.707j -> c=-11585, s=-11585
    constant TW_COS : complex_array_t := (
        to_signed(16384, 16), to_signed(11585, 16),
        to_signed(0, 16),     to_signed(-11585, 16)
    );
    constant TW_SIN : complex_array_t := (
        to_signed(0, 16),      to_signed(-11585, 16),
        to_signed(-16384, 16), to_signed(-11585, 16)
    );

    -- State machine
    type state_t is (IDLE, LOAD, STAGE1, STAGE2, STAGE3, UNLOAD);
    signal state : state_t := IDLE;
    signal sample_cnt : natural range 0 to 8 := 0;  -- counter for load/unload

    -- Bit-reversed index lookup for loading input in DIT order
    -- Natural index 0->0, 1->4, 2->2, 3->6, 4->1, 5->5, 6->3, 7->7
    type natural_array_t is array (0 to 7) of natural;
    constant BIT_REV : natural_array_t := (0, 4, 2, 6, 1, 5, 3, 7);

begin

    -- Main FFT process
    process (clk)
        -- Variables for butterfly computation
        variable tr, ti    : signed(31 downto 0);  -- 32-bit product
        variable wr_re, wr_im : signed(15 downto 0); -- twiddle for this butterfly
        variable a_re, a_im : signed(15 downto 0);
        variable b_re, b_im : signed(15 downto 0);
        variable temp_re, temp_im : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state          <= IDLE;
                sample_cnt     <= 0;
                data_out_valid <= '0';
                ready          <= '1';
                data_out_re    <= (others => '0');
                data_out_im    <= (others => '0');
            else
                data_out_valid <= '0';  -- default

                case state is
                    when IDLE =>
                        ready <= '1';
                        if data_in_valid = '1' then
                            -- Load first sample into bit-reversed position
                            re_buf(BIT_REV(0)) <= data_in_re;
                            im_buf(BIT_REV(0)) <= data_in_im;
                            sample_cnt <= 1;
                            state      <= LOAD;
                            ready      <= '0';
                        end if;

                    when LOAD =>
                        -- Load remaining 7 samples
                        if data_in_valid = '1' then
                            re_buf(BIT_REV(sample_cnt)) <= data_in_re;
                            im_buf(BIT_REV(sample_cnt)) <= data_in_im;
                            if sample_cnt = 7 then
                                state <= STAGE1;
                            else
                                sample_cnt <= sample_cnt + 1;
                            end if;
                        end if;

                    -- Stage 1: 4 butterflies, distance=4, all twiddle W8^0
                    when STAGE1 =>
                        for k in 0 to 3 loop
                            a_re := re_buf(k);    a_im := im_buf(k);
                            b_re := re_buf(k+4);  b_im := im_buf(k+4);
                            -- W8^0 = 1 + 0j, so b*W = b
                            re_buf(k)   <= a_re + b_re;
                            im_buf(k)   <= a_im + b_im;
                            re_buf(k+4) <= a_re - b_re;
                            im_buf(k+4) <= a_im - b_im;
                        end loop;
                        state <= STAGE2;

                    -- Stage 2: 4 butterflies, distance=2, twiddle W8^0 or W8^2
                    when STAGE2 =>
                        -- Butterfly (0,2): W8^0
                        re_buf(0) <= re_buf(0) + re_buf(2);
                        im_buf(0) <= im_buf(0) + im_buf(2);
                        re_buf(2) <= re_buf(0) - re_buf(2);
                        im_buf(2) <= im_buf(0) - im_buf(2);
                        -- Butterfly (1,3): W8^2 = -j
                        -- b*(-j) = (br + j*bi)*(-j) = bi - j*br
                        re_buf(1) <= re_buf(1) + im_buf(3);
                        im_buf(1) <= im_buf(1) - re_buf(3);
                        re_buf(3) <= re_buf(1) - im_buf(3);
                        im_buf(3) <= im_buf(1) + re_buf(3);
                        -- Butterfly (4,6): W8^0
                        re_buf(4) <= re_buf(4) + re_buf(6);
                        im_buf(4) <= im_buf(4) + im_buf(6);
                        re_buf(6) <= re_buf(4) - re_buf(6);
                        im_buf(6) <= im_buf(4) - im_buf(6);
                        -- Butterfly (5,7): W8^2 = -j
                        re_buf(5) <= re_buf(5) + im_buf(7);
                        im_buf(5) <= im_buf(5) - re_buf(7);
                        re_buf(7) <= re_buf(5) - im_buf(7);
                        im_buf(7) <= im_buf(5) + re_buf(7);
                        state <= STAGE3;

                    -- Stage 3: 4 butterflies, distance=1, twiddles W8^0..W8^3
                    when STAGE3 =>
                        for k in 0 to 3 loop
                            a_re := re_buf(2*k);   a_im := im_buf(2*k);
                            b_re := re_buf(2*k+1); b_im := im_buf(2*k+1);
                            wr_re := TW_COS(k);
                            wr_im := TW_SIN(k);
                            -- Complex multiply: b * W = (br*c - bi*s) + j*(br*s + bi*c)
                            -- 32-bit product, then shift right 14 to rescale
                            tr := b_re * wr_re - b_im * wr_im;
                            ti := b_re * wr_im + b_im * wr_re;
                            temp_re := resize(shift_right(tr, 14), 16);
                            temp_im := resize(shift_right(ti, 14), 16);
                            -- Butterfly outputs
                            re_buf(2*k)   <= a_re + temp_re;
                            im_buf(2*k)   <= a_im + temp_im;
                            re_buf(2*k+1) <= a_re - temp_re;
                            im_buf(2*k+1) <= a_im - temp_im;
                        end loop;
                        state      <= UNLOAD;
                        sample_cnt <= 0;

                    when UNLOAD =>
                        -- Output 8 samples sequentially in natural order
                        data_out_re    <= re_buf(sample_cnt);
                        data_out_im    <= im_buf(sample_cnt);
                        data_out_valid <= '1';
                        if sample_cnt = 7 then
                            state <= IDLE;
                        else
                            sample_cnt <= sample_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
