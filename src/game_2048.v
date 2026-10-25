`default_nettype none

// 2048 game logic. The board has 16 tiles of 4 bits.
// Tile n is at row n[3:2], column n[1:0] and stores the power of two (0 = empty).
// The board works like a conveyor belt: the line at the edge goes through
// line_merge and comes back in at the far side, so no tile is ever picked
// with a variable index (that is what made the old version too big).
module game_2048 (
	input wire clk,
	input wire rst_n,
	input wire [4:0] btn_press,
	output reg [63:0] board,
	output reg game_won,
	output reg game_over
);

// btn_press bits: 0 up, 1 down, 2 left, 3 right, 4 new game
localparam IDLE = 2'd0;
localparam MOVE = 2'd1;
localparam SPAWN = 2'd2;
localparam CHECK = 2'd3;

// dir[1] = 1 moves columns (up, down), dir[0] = 1 slides towards the far side (right, down)
localparam DIR_LEFT = 2'b00;
localparam DIR_RIGHT = 2'b01;
localparam DIR_UP = 2'b10;
localparam DIR_DOWN = 2'b11;

reg [1:0] state;
reg [1:0] dir;
reg [4:0] step_cnt;
reg moved;
reg placed;
reg second_tile;
reg can_move;
reg [3:0] spawn_start;
reg [6:0] lfsr;

// line at the edge: row 0 is tiles 0 1 2 3, column 0 is tiles 0 4 8 12
wire [15:0] edge_line = dir[1] ? {board[51:48], board[35:32], board[19:16], board[3:0]} : board[15:0];

// line_merge slides towards slot 0, so right and down feed the line in backwards
wire [15:0] merge_in = dir[0] ? {edge_line[3:0], edge_line[7:4], edge_line[11:8], edge_line[15:12]} : edge_line;
wire [15:0] merge_out;
wire [15:0] line_done = dir[0] ? {merge_out[3:0], merge_out[7:4], merge_out[11:8], merge_out[15:12]} : merge_out;
wire line_changed = (merge_out != merge_in);

line_merge u_line_merge (
	.line_in(merge_in),
	.line_out(merge_out)
);

// rows: merged row 0 goes in at the bottom (row 3), the other rows move up one
wire [63:0] rows_shifted = {line_done, board[63:16]};

// columns: merged column 0 goes in on the right (column 3), the other columns move left one
wire [63:0] cols_shifted = {line_done[15:12], board[63:52], line_done[11:8], board[47:36],
	line_done[7:4], board[31:20], line_done[3:0], board[15:4]};

// spawning moves the board one tile per clock, so tile 0 is the one being checked
// first lap only looks from spawn_start onwards, second lap looks everywhere
wire spawn_here = (state == SPAWN) && !placed && (board[3:0] == 4'd0) && (step_cnt[4] || (step_cnt[3:0] >= spawn_start));
wire [3:0] new_tile = (lfsr[6:4] == 3'd0) ? 4'd2 : 4'd1;
wire [63:0] tiles_shifted = {(spawn_here ? new_tile : board[3:0]), board[63:4]};

// CHECK turns the board one more lap past tile 0. After step_cnt shifts, tile 0 holds
// original tile step_cnt, tile 1 its right neighbour and tile 4 the one below it.
// The last column has no right neighbour and the bottom row has nothing below.
wire pair_right = (step_cnt[1:0] != 2'd3) && (board[3:0] == board[7:4]);
wire pair_below = (step_cnt[3:2] != 2'd3) && (board[3:0] == board[19:16]);
wire tile_can_move = (board[3:0] == 4'd0) || pair_right || pair_below;

// 7 bit LFSR, x^7 + x^6 + 1, repeats every 127 clocks
always @(posedge clk) begin
	if(!rst_n) begin
		lfsr <= 7'h5A;
	end
	else begin
		lfsr <= {lfsr[5:0], lfsr[6] ^ lfsr[5]};
	end
end

always @(posedge clk) begin
	if(!rst_n) begin
		state <= IDLE;
		board <= 64'd0;
		dir <= DIR_LEFT;
		step_cnt <= 5'd0;
		moved <= 1'b0;
		placed <= 1'b0;
		second_tile <= 1'b0;
		spawn_start <= 4'd0;
		can_move <= 1'b0;
		game_won <= 1'b0;
		game_over <= 1'b0;
	end
	else begin
		case(state)
			IDLE: begin
				step_cnt <= 5'd0;
				moved <= 1'b0;
				placed <= 1'b0;
				can_move <= 1'b0;
				spawn_start <= lfsr[3:0];
				if(btn_press[4]) begin
					// new game: empty the board and drop two tiles
					board <= 64'd0;
					second_tile <= 1'b1;
					game_won <= 1'b0;
					state <= SPAWN;
				end
				else if(btn_press[0]) begin
					dir <= DIR_UP;
					state <= MOVE;
				end
				else if(btn_press[1]) begin
					dir <= DIR_DOWN;
					state <= MOVE;
				end
				else if(btn_press[2]) begin
					dir <= DIR_LEFT;
					state <= MOVE;
				end
				else if(btn_press[3]) begin
					dir <= DIR_RIGHT;
					state <= MOVE;
				end
			end

			MOVE: begin
				// one line per clock, after 4 clocks every line is back in its place
				board <= dir[1] ? cols_shifted : rows_shifted;
				if(line_changed) begin
					moved <= 1'b1;
				end
				step_cnt <= step_cnt + 5'd1;
				if(step_cnt == 5'd3) begin
					step_cnt <= 5'd0;
					// a move that changed nothing must not add a tile
					if(moved || line_changed) begin
						state <= SPAWN;
					end
					else begin
						state <= IDLE;
					end
				end
			end

			SPAWN: begin
				// 32 one tile shifts is two full laps, so every tile ends where it started
				board <= tiles_shifted;
				if(spawn_here) begin
					placed <= 1'b1;
				end
				step_cnt <= step_cnt + 5'd1;
				if(step_cnt == 5'd31) begin
					placed <= 1'b0;
					second_tile <= 1'b0;
					spawn_start <= lfsr[3:0];
					if(!second_tile) begin
						state <= CHECK;
					end
				end
			end

			CHECK: begin
				// outside SPAWN no tile is placed, so this just turns the board one tile
				board <= tiles_shifted;
				if(tile_can_move) begin
					can_move <= 1'b1;
				end
				// 11 is the 2048 tile, higher values only appear if you keep playing
				if(board[3:0] >= 4'd11) begin
					game_won <= 1'b1;
				end
				step_cnt <= step_cnt + 5'd1;
				if(step_cnt == 5'd15) begin
					// a full lap later the board is back in place
					step_cnt <= 5'd0;
					game_over <= !(can_move || tile_can_move);
					state <= IDLE;
				end
			end
		endcase
	end
end

endmodule