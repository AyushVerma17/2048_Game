`default_nettype none

// Turns raw buttons into one clock "pressed" pulses.
// Sampling once per frame (every 16.7 ms) also removes switch bounce.
module button_input (
	input wire clk,
	input wire rst_n,
	input wire frame_tick,
	input wire [4:0] btn_raw,
	output reg [4:0] btn_press
);

reg [4:0] btn_meta;
reg [4:0] btn_sync;
reg [4:0] btn_sample;

// buttons have nothing to do with our clock, so double flop them first
always @(posedge clk) begin
	if(!rst_n) begin
		btn_meta <= 5'd0;
		btn_sync <= 5'd0;
	end
	else begin
		btn_meta <= btn_raw;
		btn_sync <= btn_meta;
	end
end

// pulse only when a button is high now but was low at the previous frame
always @(posedge clk) begin
	if(!rst_n) begin
		btn_sample <= 5'd0;
		btn_press <= 5'd0;
	end
	else if(frame_tick) begin
		btn_press <= btn_sync & ~btn_sample;
		btn_sample <= btn_sync;
	end
	else begin
		btn_press <= 5'd0;
	end
end

endmodule