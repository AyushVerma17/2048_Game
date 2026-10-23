`default_nettype none

// 2048 game logic. The board has 16 tiles of 4 bits.
// Tile n is at row n[3:2], column n[1:0] and stores the power of two (0 = empty).
// Every move is done as a "left" move: the board is turned so the wanted
// direction points left, the rows are merged, then it is turned the rest of
// the way round (4 quarter turns in total) so it faces the right way again.
module game_2048 (
	input wire clk,
	input wire rst_n,
	input wire [4:0] btn_press,
	output reg [63:0] board
);

// btn_press bits: 0 up, 1 down, 2 left, 3 right, 4 new game
localparam IDLE = 2'd0;
localparam ROTATE = 2'd1;
localparam MOVE = 2'd2;
localparam SPAWN = 2'd3;

// clockwise quarter turns that make each direction point left
localparam TURNS_LEFT = 2'd0;
localparam TURNS_DOWN = 2'd1;
localparam TURNS_RIGHT = 2'd2;
localparam TURNS_UP = 2'd3;

reg [1:0] state;
reg [1:0] turns_needed;
reg [1:0] turn_cnt;
reg [4:0] step_cnt;
reg move_done;
reg moved;
reg placed;
reg spawn_twice;
reg [3:0] spawn_start;
reg [15:0] lfsr;

// board turned a quarter clockwise: new (row, col) takes old (3 - col, row)
wire [63:0] board_turned;

genvar row, col;
generate
	for(row = 0; row < 4; row = row + 1) begin : g_row
		for(col = 0; col < 4; col = col + 1) begin : g_col
			assign board_turned[(row*4 + col)*4 +: 4] = board[((3 - col)*4 + row)*4 +: 4];
		end
	end
endgenerate

// only row 0 is ever merged, the other rows are shifted down into its place
wire [15:0] row_merged;
wire row_changed = (row_merged != board[15:0]);

line_merge u_line_merge (
	.line_in(board[15:0]),
	.line_out(row_merged)
);

// spawning shifts the board one tile per clock, so tile 0 is always the one checked
// first lap only accepts tiles from spawn_start onwards, second lap accepts any
wire spawn_here = !placed && (board[3:0] == 4'd0) && (step_cnt[4] || (step_cnt[3:0] >= spawn_start));
wire [3:0] spawn_tile = (lfsr[7:4] == 4'd0) ? 4'd2 : 4'd1;

// free running LFSR, x^16 + x^14 + x^13 + x^11 + 1
always @(posedge clk) begin
	if(!rst_n) begin
		lfsr <= 16'hACE1;
	end
	else begin
		lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
	end
end

always @(posedge clk) begin
	if(!rst_n) begin
		state <= IDLE;
		board <= 64'd0;
		turns_needed <= TURNS_LEFT;
		turn_cnt <= 2'd0;
		step_cnt <= 5'd0;
		move_done <= 1'b0;
		moved <= 1'b0;
		placed <= 1'b0;
		spawn_twice <= 1'b0;
		spawn_start <= 4'd0;
	end
	else begin
		case(state)
			IDLE: begin
				turn_cnt <= 2'd0;
				step_cnt <= 5'd0;
				move_done <= 1'b0;
				moved <= 1'b0;
				placed <= 1'b0;
				if(btn_press[4]) begin
					// new game: empty the board and drop two tiles
					board <= 64'd0;
					spawn_twice <= 1'b1;
					spawn_start <= lfsr[3:0];
					state <= SPAWN;
				end
				else if(btn_press[0]) begin
					turns_needed <= TURNS_UP;
					state <= ROTATE;
				end
				else if(btn_press[1]) begin
					turns_needed <= TURNS_DOWN;
					state <= ROTATE;
				end
				else if(btn_press[2]) begin
					turns_needed <= TURNS_LEFT;
					state <= ROTATE;
				end
				else if(btn_press[3]) begin
					turns_needed <= TURNS_RIGHT;
					state <= ROTATE;
				end
			end

			ROTATE: begin
				if(!move_done && (turn_cnt == turns_needed)) begin
					// move now points left, merge the rows before turning further
					state <= MOVE;
				end
				else begin
					board <= board_turned;
					turn_cnt <= turn_cnt + 2'd1;
					if(turn_cnt == 2'd3) begin
						// fourth turn puts the board back the right way round
						spawn_start <= lfsr[3:0];
						if(moved) begin
							state <= SPAWN;
						end
						else begin
							state <= IDLE;
						end
					end
				end
			end

			MOVE: begin
				// merged row 0 goes in at the top, after 4 clocks every row is back in place
				board <= {row_merged, board[63:16]};
				if(row_changed) begin
					moved <= 1'b1;
				end
				step_cnt <= step_cnt + 5'd1;
				if(step_cnt[1:0] == 2'd3) begin
					step_cnt <= 5'd0;
					move_done <= 1'b1;
					state <= ROTATE;
				end
			end

			SPAWN: begin
				// 32 one tile shifts is two full laps, so the board ends where it started
				board <= {(spawn_here ? spawn_tile : board[3:0]), board[63:4]};
				if(spawn_here) begin
					placed <= 1'b1;
				end
				step_cnt <= step_cnt + 5'd1;
				if(step_cnt == 5'd31) begin
					placed <= 1'b0;
					if(spawn_twice) begin
						spawn_twice <= 1'b0;
						spawn_start <= lfsr[3:0];
					end
					else begin
						state <= IDLE;
					end
				end
			end
		endcase
	end
end

endmodule