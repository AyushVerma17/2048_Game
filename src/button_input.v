`default_nettype none

// Turns raw buttons into one clock "pressed" pulses.
// Sampling once per frame (every 16.7 ms) also removes switch bounce.
module button_input (
	input wire clk,
	input wire rst_n,
	input wire frame_tick,
	input wire [4:0] btn_raw,
	output wire [4:0] btn_press
);

reg [4:0] btn_meta;
reg [4:0] btn_sync;
reg [4:0] btn_sample;

// synchronizer flops just follow the pins, so they need no reset
always @(posedge clk) begin
	btn_meta <= btn_raw;
	btn_sync <= btn_meta;
end

always @(posedge clk) begin
	if(!rst_n) begin
		btn_sample <= 5'd0;
	end
	else if(frame_tick) begin
		btn_sample <= btn_sync;
	end
end

// high for the frame_tick clock only, when a button went from released to pressed
assign btn_press = frame_tick ? (btn_sync & ~btn_sample) : 5'd0;

endmodule