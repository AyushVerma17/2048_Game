`default_nettype none

// Slides one line of 4 tiles towards position 0 and merges equal pairs.
// Tiles hold the power of two: 0 is empty, 1 is "2", 2 is "4" and so on.
module line_merge (
	// Connections with game_2048.v
	input wire [15:0] line_in,
	output reg [15:0] line_out
);

integer i;
reg [3:0] cur_tile;
reg [3:0] pending;
reg [1:0] write_pos;

always @(*) begin
	line_out = 16'd0;
	cur_tile = 4'd0;
	pending = 4'd0;
	write_pos = 2'd0;
	
	for(i = 0; i <= 3; i = i + 1) begin
		cur_tile = line_in[i*4 +: 4];
		if(cur_tile != 4'd0) begin
			if(pending == 4'd0) begin
				pending = cur_tile;
			end
			else if(pending == cur_tile) begin
				// merged tile is placed right away so it can't merge again
				line_out[write_pos*4 +: 4] = cur_tile + 4'd1;
				write_pos = write_pos + 2'd1;
				pending = 4'd0;
			end
			else begin
				line_out[write_pos*4 +: 4] = pending;
				write_pos = write_pos + 2'd1;
				pending = cur_tile;
			end
		end
	end
	
	// last tile still waiting goes in the next free slot
	if(pending != 4'd0) begin
		line_out[write_pos*4 +: 4] = pending;
	end
end

endmodule