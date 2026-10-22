`default_nettype none

// 640x480 @ 60 Hz timing generator, run it from a 25.175 MHz clock
module vga_sync #(
	parameter H_VISIBLE = 640,
	parameter H_FRONT = 16,
	parameter H_SYNC = 96,
	parameter H_BACK = 48,
	parameter V_VISIBLE = 480,
	parameter V_FRONT = 10,
	parameter V_SYNC = 2,
	parameter V_BACK = 33
)(
	input wire clk,
	input wire rst_n,
	output reg [9:0] hpos,
	output reg [9:0] vpos,
	output wire hsync,
	output wire vsync,
	output wire display_on
);

localparam H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
localparam V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

// hpos walks across a line, vpos steps down once per line
always @(posedge clk) begin
	if(!rst_n) begin
		hpos <= 10'd0;
		vpos <= 10'd0;
	end
	else if(hpos == H_TOTAL - 1) begin
		hpos <= 10'd0;
		if(vpos == V_TOTAL - 1) begin
			vpos <= 10'd0;
		end
		else begin
			vpos <= vpos + 10'd1;
		end
	end
	else begin
		hpos <= hpos + 10'd1;
	end
end

// sync pulses are active low in this mode
assign hsync = ~((hpos >= H_VISIBLE + H_FRONT) && (hpos < H_VISIBLE + H_FRONT + H_SYNC));
assign vsync = ~((vpos >= V_VISIBLE + V_FRONT) && (vpos < V_VISIBLE + V_FRONT + V_SYNC));
assign display_on = (hpos < H_VISIBLE) && (vpos < V_VISIBLE);

endmodule