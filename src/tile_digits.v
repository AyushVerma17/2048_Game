`default_nettype none

// Draws the number of a tile (2 to 2048) with a 3 x 5 font.
// Every font pixel is drawn as a square block: 4 x 4 screen pixels for numbers
// up to 3 digits, and 2 x 2 for 1024 and 2048 so the 4 digits fit with a margin.
module tile_digits (
	// Inputs coming from board_draw.v, position inside the tile in 2 pixel steps (0 to 31)
	input wire [3:0] tile_value,
	input wire [4:0] pos_x,
	input wire [4:0] pos_y,

	// Output, high when the current pixel is part of a digit
	output wire digit_pixel
);

reg [2:0] num_digits;
reg [15:0] text;
reg [14:0] glyph;
reg [2:0] glyph_row;
reg font_bit;

// how many digits the number has
always @(*) begin
	num_digits = 3'd0;
	case(tile_value)
		4'd0, 4'd12, 4'd13, 4'd14, 4'd15: num_digits = 3'd0; // empty or above 2048, no number
		4'd1, 4'd2, 4'd3: num_digits = 3'd1; // 2, 4, 8
		4'd4, 4'd5, 4'd6: num_digits = 3'd2; // 16, 32, 64
		4'd7, 4'd8, 4'd9: num_digits = 3'd3; // 128, 256, 512
		4'd10, 4'd11: num_digits = 3'd4; // 1024, 2048
	endcase
end

// the digits themselves, one per hex nibble, written from the left
always @(*) begin
	text = 16'h0000;
	case(tile_value)
		4'd0, 4'd12, 4'd13, 4'd14, 4'd15: text = 16'h0000;
		4'd1: text = 16'h2000;
		4'd2: text = 16'h4000;
		4'd3: text = 16'h8000;
		4'd4: text = 16'h1600;
		4'd5: text = 16'h3200;
		4'd6: text = 16'h6400;
		4'd7: text = 16'h1280;
		4'd8: text = 16'h2560;
		4'd9: text = 16'h5120;
		4'd10: text = 16'h1024;
		4'd11: text = 16'h2048;
	endcase
end

// small font: a block is one 2 pixel step, so the tile is 32 blocks across.
// big font: a block is two steps, so the tile is 16 blocks across.
wire small_font = (num_digits == 3'd4);
wire [4:0] block_x = small_font ? pos_x : {1'b0, pos_x[4:1]};
wire [4:0] block_y = small_font ? pos_y : {1'b0, pos_y[4:1]};

// a digit is 3 blocks wide plus 1 block of gap, so n digits need 4n - 1 blocks.
// These start points put the text in the middle of the tile.
wire [4:0] text_left = small_font ? 5'd8 : (5'd8 - {1'b0, num_digits, 1'b0});
wire [4:0] text_top = small_font ? 5'd13 : 5'd5;

// left of or above the text these subtractions wrap round to big numbers,
// so the range checks below also reject those pixels
wire [4:0] text_col = block_x - text_left;
wire [4:0] font_row = block_y - text_top;
wire [1:0] slot = text_col[3:2];
wire [1:0] font_col = text_col[1:0];
wire in_text = (text_col[4] == 1'b0) && ({1'b0, slot} < num_digits) && (font_row < 5'd5);

// slot 0 is the leftmost digit, it sits in the top nibble of text
wire [3:0] digit = text[{~slot, 2'b00} +: 4];

// 3 x 5 font, top row first, a 1 is a lit pixel
always @(*) begin
	glyph = 15'd0;
	case(digit)
		4'd0: glyph = {3'b111, 3'b101, 3'b101, 3'b101, 3'b111};
		4'd1: glyph = {3'b010, 3'b110, 3'b010, 3'b010, 3'b111};
		4'd2: glyph = {3'b111, 3'b001, 3'b111, 3'b100, 3'b111};
		4'd3: glyph = {3'b111, 3'b001, 3'b111, 3'b001, 3'b111};
		4'd4: glyph = {3'b101, 3'b101, 3'b111, 3'b001, 3'b001};
		4'd5: glyph = {3'b111, 3'b100, 3'b111, 3'b001, 3'b111};
		4'd6: glyph = {3'b111, 3'b100, 3'b111, 3'b101, 3'b111};
		4'd8: glyph = {3'b111, 3'b101, 3'b111, 3'b101, 3'b111};
		default: glyph = 15'd0; // 7 and 9 never appear in a tile number
	endcase
end

// pick the row of the glyph for this pixel
always @(*) begin
	glyph_row = 3'b000;
	case(font_row[2:0])
		3'd0: glyph_row = glyph[14:12];
		3'd1: glyph_row = glyph[11:9];
		3'd2: glyph_row = glyph[8:6];
		3'd3: glyph_row = glyph[5:3];
		3'd4: glyph_row = glyph[2:0];
		3'd5, 3'd6, 3'd7: glyph_row = 3'b000; // outside the text rows
	endcase
end

// pick the column, the left column is bit 2, column 3 is the gap between digits
always @(*) begin
	font_bit = 1'b0;
	case(font_col)
		2'd0: font_bit = glyph_row[2];
		2'd1: font_bit = glyph_row[1];
		2'd2: font_bit = glyph_row[0];
		2'd3: font_bit = 1'b0;
	endcase
end
// code accha hai 
assign digit_pixel = in_text && font_bit;

endmodule