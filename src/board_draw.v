`default_nettype none

// Looks at the current pixel and picks its colour from the 4x4 board
module board_draw #(
	parameter BOARD_X = 10'd192,
	parameter BOARD_Y = 10'd112
)(
	input wire [9:0] hpos,
	input wire [9:0] vpos,
	input wire display_on,
	input wire [63:0] board,
	output reg [5:0] rgb
);

// pixel position measured from the board's top left corner
wire [9:0] board_x = hpos - BOARD_X;
wire [9:0] board_y = vpos - BOARD_Y;

wire inside_board = (hpos >= BOARD_X) && (hpos < BOARD_X + 10'd256) &&
	(vpos >= BOARD_Y) && (vpos < BOARD_Y + 10'd256);

// bits [7:6] pick the tile, bits [5:0] are the position inside it
wire [3:0] tile_index = {board_y[7:6], board_x[7:6]};
wire [3:0] tile_value = board[tile_index*4 +: 4];

// 2 pixel border around every tile gives the grid lines
wire on_grid_line = (board_x[5:0] < 6'd2) || (board_x[5:0] > 6'd61) ||
	(board_y[5:0] < 6'd2) || (board_y[5:0] > 6'd61);

// rgb is {R1, R0, G1, G0, B1, B0}, black unless a case below says otherwise
always @(*) begin
	rgb = 6'b000000;
	if(display_on && inside_board) begin
		if(on_grid_line) begin
			rgb = 6'b010101;
		end
		else begin
			case(tile_value)
				4'd0: rgb = 6'b000001; // empty tile
				4'd1: rgb = 6'b111110; // 2
				4'd2: rgb = 6'b111001; // 4
				4'd3: rgb = 6'b110100; // 8
				4'd4: rgb = 6'b110001; // 16
				4'd5: rgb = 6'b100010; // 32
				4'd6: rgb = 6'b010111; // 64
				4'd7: rgb = 6'b001011; // 128
				4'd8: rgb = 6'b001110; // 256
				4'd9: rgb = 6'b011100; // 512
				4'd10: rgb = 6'b101100; // 1024
				4'd11: rgb = 6'b111100; // 2048
			endcase
		end
	end
end

endmodule