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



-- Note block size, coordinates, and image ROM
--	Bounding box size of block
constant BLOCK_WIDTH : INTEGER := 32;
constant BLOCK_HEIGHT : INTEGER := 4;
--	Coordinates of bounding box sides
signal block_left, block_right, block_top, block_bottom : UNSIGNED (9 downto 0);
--	Registers for block top and block left
signal block_left_reg, block_top_reg : UNSIGNED (9 downto 0);
signal block_left_next, block_top_next : UNSIGNED (9 downto 0);
--	Registers for block speed
signal block_speed : INTEGER := 4;
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
--	Block colour
signal block_rgb : STD_LOGIC_VECTOR (2 downto 0);
--	Block display pixel
signal block_pixel : STD_LOGIC;



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
signal SCORE_ROM : score_type := zero;

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

-- Score address mapping
--	Vertical
signal score_address, score_column : UNSIGNED (3 downto 0);
--	Horizontal
signal score_data : STD_LOGIC_VECTOR (10 downto 0);
--	If score is displayed on pixel or not
signal score_bit : STD_LOGIC;
--	If in score's bounding box
signal in_score : STD_LOGIC;
--	Score colour
signal score_rgb : STD_LOGIC_VECTOR (2 downto 0);
--	Score display pixel
signal score_pixel : STD_LOGIC;




begin


process (clk, reset)
	begin
	if (reset = '1') then
		block_top_reg <= ("0001110000");
		block_left_reg <= ("0001110000");
		score_reg <= 0;
	elsif (clk'event and clk = '1') then
		score_reg <= score_next;
		block_top_reg <= block_top_next;
		block_left_reg <= block_left_next;
	end if;
end process;



pix_x <= unsigned(pixel_x);
pix_y <= unsigned(pixel_y);



-- Refr_tick: 1-clock tick asserted at start of v_sync, e.g., when the screen is refreshed -- speed is 60 Hz
refr_tick <= '1' when (pix_y = 1) and (pix_x = 1) else '0';



-- Set block bounding box sides
block_left <= block_left_reg;
block_top <= block_top_reg;
block_right <= block_left + BLOCK_WIDTH - 1;
block_bottom <= block_top + BLOCK_HEIGHT - 1;

	

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
block_bit <= block_data(TO_INTEGER(block_column));
block_pixel <= '1' when (in_block = '1') and (block_bit = '1')
				  else '0';

-- Change in future for different colours
block_rgb <= "111";


--			If broken, add a '-1' to the end of the right and bottom
-- Set score bounding box sides
score_left <= TO_UNSIGNED(SCORE_X_OFFSET, 10);
score_right <= TO_UNSIGNED(SCORE_X_OFFSET + SCORE_WIDTH, 10);
score_top <= TO_UNSIGNED(SCORE_Y_OFFSET, 10);
score_bottom <= TO_UNSIGNED(SCORE_Y_OFFSET + SCORE_HEIGHT, 10);



-- If current pixel is inside the bounding box, make in_score true
in_score <= '1' when (score_left <= pix_x) and (pix_x <= score_right) and
				 (score_top <= pix_y) and (pix_y <= score_bottom)
				 else '0';

-- Set displayed score ROM to correct score number
SCORE_ROM <= SCORE_ROM_ARRAY(score_reg);

-- Pixel to ROM address and column
--	Vertical
score_address <= pix_y (3 downto 0) - score_top (3 downto 0);
score_data <= SCORE_ROM(TO_INTEGER(score_address));
--	Horizontal
score_column <= pix_x (3 downto 0) - score_left (3 downto 0);
score_bit <= score_data(TO_INTEGER(score_column));
score_pixel <= '1' when (in_score = '1') and (score_bit = '1')
				  else '0';

-- Set colour to white
score_rgb <= "111";



-- Block downwards movement
process(block_top, block_speed, refr_tick, block_top_reg, block_left_reg)
	begin
	-- Update the block position for movement
	block_top_next <= block_top_reg + block_speed when refr_tick = '1' else block_top_reg;
	block_left_next <= block_left_reg when refr_tick = '1' else block_left_reg;



	-- If block reaches bottom of screen, hold block somewhere offscreen till next call
	if(block_top > (MAX_Y - 1)) then
		block_top_next <= TO_UNSIGNED(MAX_Y + 20, 10);
	end if;
end process;



-- Pixel display
process(video_on, block_rgb, score_rgb, block_pixel, score_pixel)
	begin
	if (video_on = '0') then
		graph_rgb <= "000";
	else
		if (block_pixel = '1') then
			graph_rgb <= score_rgb;
		elsif (block_pixel = '1') then
			graph_rgb <= block_rgb;
		else
			graph_rgb <= "000";
		end if;
	end if;
end process;

end rtl;