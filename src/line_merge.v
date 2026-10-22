`default_nettype none

// Slides one line of 4 tiles towards cell 0 and merges equal pairs.
// Tiles hold the power of two: 0 is empty, 1 is "2", 2 is "4" and so on.
module line_merge (
	input wire [15:0] line_in,
	output reg [15:0] line_out
);

integer i;
reg [3:0] cell_num;
reg [3:0] pending;
reg [1:0] write_pos;

always @(*) begin
	line_out = 16'd0;
	cell_num = 4'd0;
	pending = 4'd0;
	write_pos = 2'd0;

	for(i = 0; i < 4; i = i + 1) begin
		cell_num = line_in[i*4 +: 4];
		if(cell_num != 4'd0) begin
			if(pending == 4'd0) begin
				pending = cell_num;
			end
			else if(pending == cell_num) begin
				// merged tile is placed right away so it can't merge again
				line_out[write_pos*4 +: 4] = cell_num + 4'd1;
				write_pos = write_pos + 2'd1;
				pending = 4'd0;
			end
			else begin
				line_out[write_pos*4 +: 4] = pending;
				write_pos = write_pos + 2'd1;
				pending = cell_num;
			end
		end
	end

	// last tile still waiting goes in the next free slot
	if(pending != 4'd0) begin
		line_out[write_pos*4 +: 4] = pending;
	end
end

endmodule