`default_nettype none

// Looks at the current pixel and picks its colour from the 4x4 board
module board_draw #(
	// Board Top Left coordinates on the screen
	parameter BOARD_START_X = 10'd192,
	parameter BOARD_START_Y = 10'd112
)(
	// Input signals coming from vga_sync.v
	input wire [9:0] hpos,
	input wire [9:0] vpos,
	input wire display_on,
	
	// Input signals coming from game_2048.v
	input wire [63:0] board,
	input wire game_won,
	input wire game_over,
	
	// Output
	output reg [5:0] rgb
);

// Current pixel position measured continuously wrt board's top left corner
// as we will be utilizing bits 6 and 7 to know which cell we are currently in
wire [9:0] board_x = hpos - BOARD_START_X;
wire [9:0] board_y = vpos - BOARD_START_Y;

// Left of or above the board the subtraction wraps round to a big number,
// so the top two bits are both 0 only inside the 256 x 256 board
wire inside_board = (board_x[9:8] == 2'b00) && (board_y[9:8] == 2'b00);

// bits [7:6] pick the tile, bits [5:0] are the position inside it
wire [3:0] tile_index = {board_y[7:6], board_x[7:6]};

// Each tile holds 4-bits of data for 2 power value
wire [3:0] tile_value = board[tile_index*4 +: 4];

// center white square to better visualize the empty tiles
wire center = (board_x[5:0] > 6'd30) && (board_x[5:0] < 6'd33) && (board_y[5:0] > 6'd30) && (board_y[5:0] < 6'd33);

// Whatever is the current tile value we will glow the RGB according to that
always @(*) begin
	rgb = 6'b00_00_00;
	if(inside_board) begin
		case(tile_value)
			4'd0: rgb = center ? 6'b11_11_11 : 6'b01_01_01; // empty tile (Grey)
			4'd1: rgb = 6'b11_11_10; // 2
			4'd2: rgb = 6'b11_10_01; // 4
			4'd3: rgb = 6'b11_01_00; // 8
			4'd4: rgb = 6'b11_00_01; // 16
			4'd5: rgb = 6'b10_00_10; // 32
			4'd6: rgb = 6'b01_01_11; // 64
			4'd7: rgb = 6'b00_10_11; // 128
			4'd8: rgb = 6'b00_11_10; // 256
			4'd9: rgb = 6'b01_11_00; // 512
			4'd10: rgb = 6'b10_11_00; // 1024
			4'd11: rgb = 6'b11_11_00; // 2048
			4'd12, 4'd13, 4'd14, 4'd15: rgb = 6'b11_11_11; // 4096 and above
		endcase
	end
	// Outside the board the screen is black, red when stuck, green after a win
	else if(display_on && game_over) begin
		rgb = 6'b10_00_00;
	end
	else if(display_on && game_won) begin
		rgb = 6'b00_10_00;
	end
end

endmodule