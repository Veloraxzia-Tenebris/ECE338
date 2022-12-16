library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity pong_graph_st is
	port(clk, reset: in std_logic;
		btn: in std_logic_vector(1 downto 0);
		video_on: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
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
signal block_left1, block_right1, block_top1, block_bottom1 : UNSIGNED (9 downto 0);
--	Second block
signal block_left2, block_right2, block_top2, block_bottom2 : UNSIGNED (9 downto 0);
--	Third block
signal block_left3, block_right3, block_top3, block_bottom3 : UNSIGNED (9 downto 0);
--	Registers for block top and block left
signal block_left_reg1, block_top_reg1 : UNSIGNED (9 downto 0);
signal block_left_next1, block_top_next1 : UNSIGNED (9 downto 0);
--	Second block
signal block_left_reg2, block_top_reg2 : UNSIGNED (9 downto 0);
signal block_left_next2, block_top_next2 : UNSIGNED (9 downto 0);
--	Third block
signal block_left_reg3, block_top_reg3 : UNSIGNED (9 downto 0);
signal block_left_next3, block_top_next3 : UNSIGNED (9 downto 0);
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
signal block_address1, block_column1 : UNSIGNED (1 downto 0);
--	Horizontal
signal block_data1 : STD_LOGIC_VECTOR (31 downto 0);
--	Second block
signal block_address2, block_column2 : UNSIGNED (1 downto 0);
signal block_data2 : STD_LOGIC_VECTOR (31 downto 0);
--	Third block
signal block_address3, block_column3 : UNSIGNED (1 downto 0);
signal block_data3 : STD_LOGIC_VECTOR (31 downto 0);
--	If block is displayed on pixel or not
signal block_bit1 : STD_LOGIC;
--	Second block
signal block_bit2 : STD_LOGIC;
--	Third block
signal block_bit3 : STD_LOGIC;
--	If in block's bounding box
signal in_block1 : STD_LOGIC;
--	Second block
signal in_block2 : STD_LOGIC;
--	Third block
signal in_block3 : STD_LOGIC;
--	Block colour
signal block_rgb : STD_LOGIC_VECTOR (2 downto 0);
--	Block display pixel
signal block_pixel1 : STD_LOGIC;
--	Second block
signal block_pixel2 : STD_LOGIC;
--	Third block
signal block_pixel3 : STD_LOGIC;

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
type score_type is array (0 to 13) of std_logic_vector (0 to 9);
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

-- Score counter
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
signal score_data : STD_LOGIC_VECTOR (9 downto 0);
--	If score is displayed on pixel or not
signal score_bit : STD_LOGIC;
--	If in score's bounding box
signal in_score : STD_LOGIC;
--	Score colour
signal score_rgb : STD_LOGIC_VECTOR (2 downto 0);
--	Score display pixel
signal score_pixel : STD_LOGIC;
--	Score block detection
constant DETECT_HEIGHT : INTEGER := 440;
constant DETECT_THICKNESS : INTEGER := 40;

-- Time counter
--	Counts every 1/60th of a second
signal timer60th_reg, timer60th_next : INTEGER := 0;
--	Counts every 1/10th of a second
signal timer10th_reg, timer10th_next : INTEGER := 0;
constant TIMESIX : INTEGER := 6;
constant TIMETEN : INTEGER := 63;

-- Lane lines
constant LANE_LEFT : INTEGER := 100;
constant LANE_LINE_THICKNESS : INTEGER := 4;
constant LANE_WIDTH : INTEGER := 48;
signal lane_pixel : STD_LOGIC;
signal lane_rgb : STD_LOGIC_VECTOR (2 downto 0);

-- Lane rhythms
type rhythm_type is array(0 to 63) of STD_LOGIC;
signal lane_rhythm1 : rhythm_type := ('1', '0', '0', '0', '0', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '1', '0', '0',
								'0', '0', '0', '0', '1', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '1', '0', '0',
								'0', '0', '1', '0', '0', '0', '0', '0');
signal lane_rhythm2 : rhythm_type := ('0', '0', '1', '0', '0', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '1', '0', '0',
								'0', '0', '1', '0', '0', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '1', '0', '0', '0', '0', '0',
								'0', '0', '0', '0', '1', '0', '0', '0');
signal lane_rhythm3 : rhythm_type := ('0', '0', '0', '0', '0', '1', '0', '0',
								'0', '0', '0', '0', '0', '1', '0', '0',
								'0', '0', '0', '0', '0', '0', '1', '0',
								'0', '0', '1', '0', '0', '0', '0', '0',
								'0', '0', '0', '1', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '0', '1', '0',
								'0', '0', '1', '0', '0', '0', '0', '0',
								'0', '0', '0', '0', '0', '0', '1', '0');



begin
process(clk, reset)
	begin
	if (reset = '1') then
		block_top_reg1 <= ("0000000000");	-- 0
		block_left_reg1 <= ("0001110000");	-- 112
		block_top_reg2 <= ("0000000000");	-- 0
		block_left_reg2 <= ("0010100100");	-- 164
		block_top_reg3 <= ("0000000000");	-- 0
		block_left_reg3 <= ("0011011000");	-- 216
		score_reg <= 0;
		timer10th_reg <= 0;
		timer60th_reg <= 0;
	elsif (clk'event and clk = '1') then
		score_reg <= score_next;
		block_top_reg1 <= block_top_next1;
		block_left_reg1 <= block_left_next1;
		block_top_reg2 <= block_top_next2;
		block_left_reg2 <= block_left_next2;
		block_top_reg3 <= block_top_next3;
		block_left_reg3 <= block_left_next3;
		timer10th_reg <= timer10th_next;
		timer60th_reg <= timer60th_next;
	end if;
end process;

pix_x <= unsigned(pixel_x);
pix_y <= unsigned(pixel_y);

-- Refr_tick: 1-clock tick asserted at start of v_sync, e.g., when the screen is refreshed -- speed is 60 Hz
refr_tick <= '1' when (pix_y = 1) and (pix_x = 1) else '0';

-- Set block bounding box sides
block_left1 <= block_left_reg1;
block_top1 <= block_top_reg1;
block_right1 <= block_left1 + BLOCK_WIDTH - 1;
block_bottom1 <= block_top1 + BLOCK_HEIGHT - 1;
-- Second block
block_left2 <= block_left_reg2;
block_top2 <= block_top_reg2;
block_right2 <= block_left2 + BLOCK_WIDTH - 1;
block_bottom2 <= block_top2 + BLOCK_HEIGHT - 1;
-- Third block
block_left3 <= block_left_reg3;
block_top3 <= block_top_reg3;
block_right3 <= block_left3 + BLOCK_WIDTH - 1;
block_bottom3 <= block_top3 + BLOCK_HEIGHT - 1;

-- If current pixel is inside the bounding box, make in_block1 true
in_block1 <= '1' when (block_left1 <= pix_x) and (pix_x <= block_right1) and
				 (block_top1 <= pix_y) and (pix_y <= block_bottom1)
				 else '0';
-- Second block
in_block2 <= '1' when (block_left2 <= pix_x) and (pix_x <= block_right2) and
				 (block_top2 <= pix_y) and (pix_y <= block_bottom2)
				 else '0';
-- Third block
in_block3 <= '1' when (block_left3 <= pix_x) and (pix_x <= block_right3) and
				 (block_top3 <= pix_y) and (pix_y <= block_bottom3)
				 else '0';

-- Pixel to ROM address and column
--	Vertical
block_address1 <= pix_y (1 downto 0) - block_top1 (1 downto 0);
block_data1 <= BLOCK_ROM(TO_INTEGER(block_address1));
--	Horizontal
block_column1 <= pix_x (1 downto 0) - block_left1 (1 downto 0);
block_bit1 <= block_data1(TO_INTEGER(block_column1));
block_pixel1 <= '1' when (in_block1 = '1') and (block_bit1 = '1')
				  else '0';
--	Second block
block_address2 <= pix_y (1 downto 0) - block_top2 (1 downto 0);
block_data2 <= BLOCK_ROM(TO_INTEGER(block_address2));
block_column2 <= pix_x (1 downto 0) - block_left2 (1 downto 0);
block_bit2 <= block_data2(TO_INTEGER(block_column2));
block_pixel2 <= '1' when (in_block2 = '1') and (block_bit2 = '1')
				  else '0';
--	Third block
block_address3 <= pix_y (1 downto 0) - block_top3 (1 downto 0);
block_data3 <= BLOCK_ROM(TO_INTEGER(block_address3));
block_column3 <= pix_x (1 downto 0) - block_left3 (1 downto 0);
block_bit3 <= block_data3(TO_INTEGER(block_column3));
block_pixel3 <= '1' when (in_block3 = '1') and (block_bit3 = '1')
				  else '0';

-- Change in future for different colours
block_rgb <= "111";

-- Timer incrementation
timer60th_next <= timer60th_reg + 1 when refr_tick = '1'
			   else 0 when timer60th_reg = 6
			   else timer60th_reg;
timer10th_next <= timer10th_reg + 1 when timer60th_reg = 5
			   else 0 when timer10th_reg = 63
			   else timer10th_reg;

-- Tick counter block (60 bps)
process(block_top1, block_top2, block_top3, block_speed, refr_tick, block_top_reg1, block_left_reg1,
	   block_top_reg2, block_left_reg2, block_top_reg3, block_left_reg3, timer60th_reg, timer10th_reg, lane_rhythm1, lane_rhythm2, lane_rhythm3, btn)
	begin
	-- Block downwards movement
	-- Update the block position for movement
	-- If block reaches bottom of screen, hold block somewhere offscreen till next call
	if(block_top1 > (MAX_Y - 1)) then
		block_top_next1 <= TO_UNSIGNED(MAX_Y + 20, 10);
	elsif(lane_rhythm1(timer10th_reg) = '1') then
		block_top_next1 <= TO_UNSIGNED(0, 10);
	else
		if(refr_tick = '1') then
			block_top_next1 <= block_top_reg1 + block_speed;
		else
			block_top_next1 <= block_top_reg1;
		end if;
	end if;
	-- Second block
	if(block_top2 > (MAX_Y - 1)) then
		block_top_next2 <= TO_UNSIGNED(MAX_Y + 20, 10);
	elsif(lane_rhythm2(timer10th_reg) = '1') then
		block_top_next2 <= TO_UNSIGNED(0, 10);
	else
		if(refr_tick = '1') then
			block_top_next2 <= block_top_reg2 + block_speed;
		else
			block_top_next2 <= block_top_reg2;
		end if;
	end if;
	-- Third block
	if(block_top3 > (MAX_Y - 1)) then
		block_top_next3 <= TO_UNSIGNED(MAX_Y + 20, 10);
	elsif(lane_rhythm3(timer10th_reg) = '1') then
		block_top_next3 <= TO_UNSIGNED(0, 10);
	else
		if(refr_tick = '1') then
			block_top_next3 <= block_top_reg3 + block_speed;
		else
			block_top_next3 <= block_top_reg3;
		end if;
	end if;

	-- Score detection
	if((block_top1 > (DETECT_HEIGHT + DETECT_THICKNESS)) and (block_top1 < DETECT_HEIGHT) and btn(0) = '1') then
		score_next <= score_reg + 1;
	-- Second block
	elsif((block_top2 > (DETECT_HEIGHT + DETECT_THICKNESS)) and (block_top2 < DETECT_HEIGHT) and btn(1) = '1') then
		score_next <= score_reg + 1;
	-- Third block
	elsif((block_top3 > (DETECT_HEIGHT + DETECT_THICKNESS)) and (block_top3 < DETECT_HEIGHT) and btn(2) = '1') then
		score_next <= score_reg + 1;
	end if;
end process;

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

-- Display lane
lane_pixel <= '1' when ((LANE_LEFT <= pix_x) and (pix_x <= (LANE_LEFT + LANE_LINE_THICKNESS))) or
				   (((LANE_LEFT + LANE_WIDTH) <= pix_x) and (pix_x <= (LANE_LEFT + LANE_WIDTH + LANE_LINE_THICKNESS))) or
				   (((LANE_LEFT + LANE_WIDTH + LANE_WIDTH) <= pix_x) and (pix_x <= (LANE_LEFT + LANE_WIDTH + LANE_WIDTH + LANE_LINE_THICKNESS))) or
				   (((LANE_LEFT + LANE_WIDTH + LANE_WIDTH + LANE_WIDTH) <= pix_x) and (pix_x <= (LANE_LEFT + LANE_WIDTH + LANE_WIDTH + LANE_WIDTH + LANE_LINE_THICKNESS)))
				   else '0';
lane_rgb <= "011";

-- Pixel display
process(video_on, block_rgb, score_rgb, block_pixel1, block_pixel2, block_pixel3, score_pixel)
	begin
	if(video_on = '0') then
		graph_rgb <= "000";
	else
		if(score_pixel = '1') then
			graph_rgb <= score_rgb;
		elsif(block_pixel1 = '1') then
			graph_rgb <= block_rgb;
		elsif(block_pixel2 = '1') then
			graph_rgb <= block_rgb;
		elsif(block_pixel3 = '1') then
			graph_rgb <= block_rgb;
		elsif(lane_pixel = '1') then
			graph_rgb <= lane_rgb;
		else
			graph_rgb <= "000";
		end if;
	end if;
end process;

end rtl;