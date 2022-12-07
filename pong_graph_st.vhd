library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity pong_graph_st is
	port(clk, reset: in std_logic;
		btn: in std_logic_vector(1 downto 0);
		video_on: in std_logic;
		pixel_x, pixel_y, pixel_2_x, pixel_2_y: in std_logic_vector(9 downto 0);
		led: out std_logic_vector(1 downto 0);
		graph_rgb: out std_logic_vector(2 downto 0));
end pong_graph_st;



architecture rtl of pong_graph_st is

-- Signal used to control speed of ball and how often pushbuttons are checked for paddle movement.
signal refr_tick: std_logic;

-- x, y coordinates (0,0 to (639, 479)
signal pix_x, pix_y: unsigned(9 downto 0);

-- Screen dimensions
constant MAX_X: integer := 640;
constant MAX_Y: integer := 480;

-- Wall left and right boundary of wall (full height)
constant WALL_X_L: integer := 0;
constant WALL_X_R: integer := 1;

-- Paddle left, right, top, bottom and height -- left & right are constant. Top & bottom are signals to allow movement. bar_y_t driven by register below.
constant BAR_X_L: integer := 200;
constant BAR_X_R: integer := 325;
signal bar_y_t, bar_y_b: integer := 80;
constant BAR_Y_SIZE: integer := 25;

-- Reg to track top boundary (x position is fixed)
signal bar_y_reg, bar_y_next: integer := 400;

-- Bar moving velocity when a button is pressed -- the amount the bar is moved.
constant BAR_V: integer:= 4;

-- Square ball -- ball left, right, top and bottom all vary. Left and top driven by registers below.
constant BALL_SIZE: integer := 8;
signal bar_left_1, bar_right_1: unsigned(9 downto 0);
signal bar_left_2, bar_right_2: unsigned(9 downto 0);
signal bar_top_1, bar_bottom_1: unsigned(9 downto 0);
signal bar_top_2, bar_bottom_2: unsigned(9 downto 0);

-- Reg to track left and top boundary
signal bar_x_1_reg, bar_x_1_next: unsigned (9 downto 0);
signal bar_x_2_reg, bar_x_2_next: unsigned (9 downto 0);
signal bar_y_1_reg, bar_y_1_next: unsigned (9 downto 0);
signal bar_y_2_reg, bar_y_2_next: unsigned (9 downto 0);

-- reg to track ball speed
signal x_delta_reg, x_delta_next: integer := 0; --Speed of ball going left to right (Carlos)
signal x_delta_2_reg, x_delta_2_next: integer := 0;
signal y_delta_reg, y_delta_next: integer := 2; --Speed of ball going top to bottom (Carlos)
signal y_delta_2_reg, y_delta_2_next: integer := 2;

-- ball movement can be pos or neg
constant BALL_V_P: unsigned(9 downto 0):= to_unsigned(-1, 10);
constant BALL_V_N: unsigned(9 downto 0):= unsigned(to_signed(-2,10));



-- Note block size, coordinates, and image ROM
--	Bounding box size of block
constant BLOCK_WIDTH : INTEGER := 32;
constant BLOCK_HEIGHT : INTEGER := 4;
--	Coordinates of bounding box sides
signal block_left, block_right, block_top, block_bottom : UNSIGNED (9 downto 0);
--	Block ROM
type block_type is array (0 to 3) of STD_LOGIC_VECTOR (0 to 31);
-- Should look like:
--	    XXXXXXXXXXXXXXXXXXXXXXXX    
--	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
--	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
--	    XXXXXXXXXXXXXXXXXXXXXXXX    
constant BLOCK_ROM : block_type := (	"00001111111111111111111111110000",
								"11111111111111111111111111111111",
								"11111111111111111111111111111111", 
								"00001111111111111111111111110000");

-- Block address mapping
--	Vertical
signal block_address, block_column : UNSIGNED (1 downto 0);
--	Horizontal
signal block_data : STD_LOGIC_VECTOR (31 downto 0);
--	If block is displayed on pixel or not
signal block_bit : STD_LOGIC;
--	If in block's bounding box
signal in_block : STD_LOGIC;

-- If current pixel is inside the bounding box, make in_block true
in_block <= '1' when (block_left <= pix_x) and (pix_x <= block_right) and
				 (block_top <= pix_y) and (pix_y <= block_bottom)
				 else '0';

-- Pixel to ROM address and column
--	Vertical
block_address <= pix_y (1 downto 0) - block_top (1 downto 0);
block_data <= BLOCK_ROM(TO_INTEGER(block_address));
--	Horizontal
block_column <= pix_x (1 downto 0) - block_left (1 downto 0);
block_bit <= block_data(TO_INTEGER(block_column))
block_pixel <= '1' when (in_block = '1') and (block_bit = '1')
				  else '0';

-- Change in future for different colours
block_rgb <= "111";


	
-- For displaying numerical scores (Sonny)
-- Using a grid that looks like this:
--   XXXXX
--   XXXXX
--   XXXXX
--   XXXXX
--   XXXXX
--   XXXXX
--   XXXXX
-- Zero:
--   XXXXX
--   X   X
--   X   X
--   X   X
--   X   X
--   X   X
--   XXXXX
type score_type is array(0 to 13) of std_logic_vector(0 to 9);
constant zero : score_type := (	"1111111111",
							"1111111111",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111");
-- One:
--       X
--       X
--       X
--       X
--       X
--       X
--       X
constant one : score_type := (	"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011");
-- Two:
--   XXXXX
--       X
--       X
--   XXXXX
--   X    
--   X    
--   XXXXX
constant two : score_type := (	"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"1111111111",
							"1111111111",
							"1100000000",
							"1100000000",
							"1100000000",
							"1100000000",
							"1111111111",
							"1111111111");
-- Three:
--   XXXXX
--       X
--       X
--   XXXXX
--       X
--       X
--   XXXXX
constant three : score_type := (	"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"1111111111",
							"1111111111");
-- Four:
--   X   X
--   X   X
--   X   X
--   XXXXX
--       X
--       X
--        
constant four : score_type := (	"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011");
-- Five:
--   XXXXX
--   X    
--   X    
--   XXXXX
--       X
--       X
--   XXXXX
constant five : score_type := (	"1111111111",
							"1111111111",
							"1100000000",
							"1100000000",
							"1100000000",
							"1100000000",
							"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"1111111111",
							"1111111111");
-- Six:
--   XXXXX
--   X    
--   X    
--   XXXXX
--   X   X
--   X   X
--   XXXXX
constant six : score_type := (	"1111111111",
							"1111111111",
							"1100000000",
							"1100000000",
							"1100000000",
							"1100000000",
							"1111111111",
							"1111111111",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111");
-- Seven:
--   XXXXX
--       X
--       X
--       X
--       X
--       X
--       X
constant seven : score_type := (	"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011");
-- Eight:
--   XXXXX
--   X   X
--   X   X
--   XXXXX
--   X   X
--   X   X
--   XXXXX
constant eight : score_type := (	"1111111111",
							"1111111111",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111");
-- Nine:
--   XXXXX
--   X   X
--   X   X
--   XXXXX
--       X
--       X
--   XXXXX
constant nine : score_type := (	"1111111111",
							"1111111111",
							"1100000011",
							"1100000011",
							"1100000011",
							"1100000011",
							"1111111111",
							"1111111111",
							"0000000011",
							"0000000011",
							"0000000011",
							"0000000011",
							"1111111111",
							"1111111111");

type score_array is array (0 to 9) of score_type;
constant SCORE_ROM_ARRAY : score_array := (zero, one, two, three, four, five, six, seven, eight, nine);

-- Score counter (Sonny)
signal score_reg, score_next : INTEGER := 0;

-- Score size, coordinates, and image ROM
constant SCORE_X_OFFSET : INTEGER := 320;
constant SCORE_Y_OFFSET : INTEGER := 240;
--	Bounding box size of score
constant SCORE_WIDTH : INTEGER := 32;
constant SCORE_HEIGHT : INTEGER := 4;
--	Coordinates of bounding box sides
signal score_left, score_right, score_top, score_bottom : UNSIGNED (9 downto 0);

-- Set score bounding box sides
score_left <= TO_UNSIGNED(SCORE_X_OFFSET);
score_right <= TO_UNSIGNED(SCORE_X_OFFSET + SCORE_WIDTH);
score_top <= TO_UNSIGNED(SCORE_Y_OFFSET);
score_bottom <= TO_UNSIGNED(SCORE_Y_OFFSET + SCORE_HEIGHT);

-- Score address mapping
--	Vertical
signal score_address, score_column : UNSIGNED (3 downto 0);
--	Horizontal
signal score_data : STD_LOGIC_VECTOR (10 downto 0);
--	If score is displayed on pixel or not
signal score_bit : STD_LOGIC;
--	If in score's bounding box
signal in_score : STD_LOGIC;

-- If current pixel is inside the bounding box, make in_score true
in_score <= '1' when (score_left <= pix_x) and (pix_x <= score_right) and
				 (score_top <= pix_y) and (pix_y <= score_bottom)
				 else '0';

-- Set displayed score ROM to correct score number
signal SCORE_ROM : score_type;
SCORE_ROM <= SCORE_ROM_ARRAY(TO_INTEGER(score_reg))

-- Pixel to ROM address and column
--	Vertical
score_address <= pix_y (3 downto 0) - score_top (3 downto 0);
score_data <= SCORE_ROM(TO_INTEGER(score_address));
--	Horizontal
score_column <= pix_x (3 downto 0) - score_left (3 downto 0);
score_bit <= score_data(TO_INTEGER(score_column))
score_pixel <= '1' when (in_score = '1') and (score_bit = '1')
				  else '0';

-- Set colour to white
score_rgb <= "111";



signal rom_addr, rom_col: unsigned(2 downto 0);
signal rom_data: std_logic_vector(7 downto 0);
signal rom_bit: std_logic;

-- object output signals -- new signal to indicate if scan coord is within ball
signal wall_on, bar_on, sq_ball_on, rd_ball_on, sq_ball_on_2, rd_ball_on_2: std_logic;
signal wall_rgb, bar_rgb, ball_rgb: std_logic_vector(2 downto 0);

signal bar_y: integer := 400;
signal ball_y: unsigned(9 downto 0);

-- ======================================================================================================
begin


process (clk, reset)
	begin
	if (reset = '1') then
		bar_y_reg <= 400;
		bar_x_1_reg <= ("0001110000");
		bar_x_2_reg <= ("0011110000");
		bar_y_1_reg <= ("0000100000");
		bar_y_2_reg <= ("0000100000");
		x_delta_reg <= x_delta_next;
		x_delta_2_reg <= x_delta_next;
		y_delta_reg <= y_delta_next;
		y_delta_2_reg <= y_delta_2_next;
		-- Added score state (Sonny)
		score_reg <= 0;
	elsif (clk'event and clk = '1') then
		bar_y_reg <= bar_y_next;
		bar_x_1_reg <= bar_x_1_next;
		bar_x_2_reg <= bar_x_2_next;
		bar_y_1_reg <= bar_y_1_next;
		bar_y_2_reg <= bar_y_2_next;
		x_delta_reg <= x_delta_next;
		x_delta_2_reg <= x_delta_2_next;
		y_delta_reg <= y_delta_next;
		y_delta_2_reg <= y_delta_2_next;
		-- Added score state (Sonny)
		score_reg <= score_next;
	end if;
end process;

-- ======================================================================================================
pix_x <= unsigned(pixel_x);
pix_y <= unsigned(pixel_y);

-- Refr_tick: 1-clock tick asserted at start of v_sync, e.g., when the screen is refreshed -- speed is 60 Hz
refr_tick <= '1' when (pix_y = 1) and (pix_x = 1) else '0';

-- ======================================================================================================
-- wall left vertical stripe
wall_on <= '1' when (WALL_X_L <= pix_x) and (pix_x <= WALL_X_R) else '0';
wall_rgb <= "011"; -- blue

-- ======================================================================================================
-- pixel within paddle
bar_y_t <= bar_y_reg;
bar_y_b <= bar_y_t + BAR_Y_SIZE - 1;
bar_on <= '1' when (BAR_X_L <= pix_x) and (pix_x <= BAR_X_R) and (bar_y_t <= pix_y) and (pix_y <= bar_y_b) else '0';
bar_rgb <= "100"; -- green

-- ======================================================================================================
-- Process bar movement requests
process( bar_y_reg, bar_y_b, bar_y_t, refr_tick, btn)
	begin
	bar_y_next <= bar_y_reg; -- no move
	if ( refr_tick = '1' ) then

-- if btn 1 pressed and paddle not at bottom yet
	if ( btn(1) = '1') then
	led(0) <= '1';
	end if;
	end if;
end process;


-- ======================================================================================================
-- set coordinates of square ball.
bar_left_1 <= bar_x_1_reg;
bar_left_2 <= bar_x_2_reg;
bar_top_1 <= bar_y_1_reg;
bar_top_2 <= bar_y_2_reg;
bar_right_1 <= bar_left_1 + BALL_SIZE - 1;
bar_right_2 <= bar_left_2 + BALL_SIZE - 1;
bar_bottom_1 <= bar_top_1 + BALL_SIZE - 1;
bar_bottom_2 <= bar_top_2 + BALL_SIZE - 1;

-- pixel within square ball
sq_ball_on <= '1' when (bar_left_1 <= pix_x) and (pix_x <= bar_right_1) and (bar_top_1 <= pix_y) and (pix_y <= bar_bottom_1) else '0';
sq_ball_on_2 <= '1' when (bar_left_2 <= pix_x_2) and (pix_x_2 <= bar_right_2) and (bar_top_2 <= pix_y_2) and (pix_y_2 <= bar_bottom_2) else '0';

-- Map scan coord to ROM addr/col -- use low order three bits of pixel and ball positions. ROM row
rom_addr <= pix_y(2 downto 0) - bar_top_1(2 downto 0);

-- ROM column
rom_col <= pix_x(2 downto 0) - bar_left_1(2 downto 0);

-- Get row data
rom_data <= BALL_ROM(to_integer(rom_addr));

-- Get column bit
rom_bit <= rom_data(to_integer(rom_col));
ball_y <= bar_y_1_reg;
bar_y <= bar_y_reg;

	
-- Turn ball on only if within square and the ROM bit is 1.
rd_ball_on <= '1' when (sq_ball_on = '1') and (rom_bit = '1') else '0';
rd_ball_on_2 <= '1' when (sq_ball_on_2 = '1') and (rom_bit = '1') else '0';
ball_rgb <= "001"; -- red

-- Update the ball position 60 times per second.
bar_y_1_next <= bar_y_1_reg + y_delta_reg when refr_tick = '1' else bar_y_1_reg;
bar_y_2_next <= bar_y_2_reg + y_delta_2_reg when refr_tick = '1' else bar_y_2_reg;
bar_x_1_next <= bar_x_1_reg + x_delta_reg when refr_tick = '1' else bar_x_1_reg;
bar_x_2_next <= bar_x_2_reg + x_delta_2_reg when refr_tick = '1' else bar_x_2_reg;

-- Set the value of the next ball position according to the boundaries.
process(x_delta_reg, y_delta_reg, bar_top_1, bar_left_1, bar_right_1, bar_top_1, bar_bottom_1, bar_y_t, bar_y_b,
x_delta_2_reg, y_delta_2_reg, bar_top_2, bar_left_2, bar_right_1, bar_top_2, bar_bottom_2)
	begin
	x_delta_next <= x_delta_reg;
	x_delta_2_next <= x_delta_2_reg;
	y_delta_next <= y_delta_reg;
	y_delta_next <= y_delta_2_reg;

-- Ball reached top, make offset positive
	if ( bar_top_1 < 1 ) then 
	y_delta_next <= y_delta_reg;

-- Reached bottom, make negative
	elsif (bar_bottom_1 > (MAX_Y - 1)) then 
	y_delta_next <= y_delta_reg;

-- Reach wall, bounce back
	elsif (bar_left_1 <= WALL_X_R ) then 
	x_delta_next <= x_delta_reg; 

-- Right corner of ball inside bar
	elsif ((BAR_X_L <= bar_right_1) and (bar_right_1 <= BAR_X_R)) then

-- Some portion of ball hitting paddle, reverse direction
	if ((bar_y_t <= bar_bottom_1) and (bar_top_1 <= bar_y_b)) then
		x_delta_next <= x_delta_reg; 
	end if;
	end if;
end process;


-- ======================================================================================================
-- turn on the appropriate color depending on the current pixel position.
process (video_on, wall_on, bar_on, rd_ball_on, wall_rgb, bar_rgb, ball_rgb)
	begin
	if (video_on = '0') then
	graph_rgb <= "000"; -- blank
	else 
	if (score_pixel = '1') then
		graph_rgb <= score_rgb;
	elsif (wall_on = '1') then
		graph_rgb <= wall_rgb;
	elsif (bar_on = '1') then
		graph_rgb <= bar_rgb;
	elsif (rd_ball_on = '1') then
		graph_rgb <= ball_rgb;
	elsif (block_pixel = '1') then
		graph_rgb <= block_rgb;
	else
		graph_rgb <= "000";
	end if;
	end if;
end process;

end rtl;

