`default_nettype none

// 2048 game logic. The board has 16 tiles of 4 bits.
// Tile n is at row n[3:2], column n[1:0] and stores the power of two (0 = empty).
module game_2048 (
	input wire clk,
	input wire rst_n,
	input wire [4:0] btn_press,
	output reg [63:0] board
);

// btn_press bits: 0 up, 1 down, 2 left, 3 right, 4 new game
localparam IDLE = 2'd0;
localparam MOVE = 2'd1;
localparam SPAWN = 2'd2;

localparam DIR_UP = 2'd0;
localparam DIR_DOWN = 2'd1;
localparam DIR_LEFT = 2'd2;
localparam DIR_RIGHT = 2'd3;

reg [1:0] state;
reg [1:0] dir;
reg [1:0] line_cnt;
reg moved;
reg [3:0] spawn_pos;
reg spawn_twice;
reg [15:0] lfsr;

// which cell is the k-th tile of a line, k = 0 is the cell next to the wall
function [3:0] cell_index;
	input [1:0] move_dir;
	input [1:0] line_num;
	input [1:0] k;
	begin
		cell_index = 4'd0;
		case(move_dir)
			DIR_UP: cell_index = {k, line_num};
			DIR_DOWN: cell_index = {~k, line_num};
			DIR_LEFT: cell_index = {line_num, k};
			DIR_RIGHT: cell_index = {line_num, ~k};
		endcase
	end
endfunction

wire [3:0] idx0 = cell_index(dir, line_cnt, 2'd0);
wire [3:0] idx1 = cell_index(dir, line_cnt, 2'd1);
wire [3:0] idx2 = cell_index(dir, line_cnt, 2'd2);
wire [3:0] idx3 = cell_index(dir, line_cnt, 2'd3);

wire [15:0] line_cells = {board[idx3*4 +: 4], board[idx2*4 +: 4], board[idx1*4 +: 4], board[idx0*4 +: 4]};
wire [15:0] line_merged;
wire line_changed = (line_merged != line_cells);

line_merge u_line_merge (
	.line_in(line_cells),
	.line_out(line_merged)
);

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
		dir <= DIR_UP;
		line_cnt <= 2'd0;
		moved <= 1'b0;
		spawn_pos <= 4'd0;
		spawn_twice <= 1'b0;
	end
	else begin
		case(state)
			IDLE: begin
				line_cnt <= 2'd0;
				moved <= 1'b0;
				if(btn_press[4]) begin
					// new game: empty the board and drop two tiles
					board <= 64'd0;
					spawn_twice <= 1'b1;
					spawn_pos <= lfsr[3:0];
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
				// one line per clock, written back to the same four cells
				board[idx0*4 +: 4] <= line_merged[3:0];
				board[idx1*4 +: 4] <= line_merged[7:4];
				board[idx2*4 +: 4] <= line_merged[11:8];
				board[idx3*4 +: 4] <= line_merged[15:12];
				if(line_changed) begin
					moved <= 1'b1;
				end
				line_cnt <= line_cnt + 2'd1;
				if(line_cnt == 2'd3) begin
					spawn_pos <= lfsr[3:0];
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
				if(board[spawn_pos*4 +: 4] == 4'd0) begin
					// 1 in 16 chance of a 4, otherwise a 2
					board[spawn_pos*4 +: 4] <= (lfsr[7:4] == 4'd0) ? 4'd2 : 4'd1;
					if(spawn_twice) begin
						spawn_twice <= 1'b0;
						spawn_pos <= lfsr[3:0];
					end
					else begin
						state <= IDLE;
					end
				end
				else begin
					spawn_pos <= spawn_pos + 4'd1;
				end
			end
            
			default: begin
				state <= IDLE;
			end
		endcase
	end
end

endmodule