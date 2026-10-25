`default_nettype none

module tt_um_ayush_2048 (
	input wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input wire [7:0] uio_in,
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,
	input wire ena,
	input wire clk,
	input wire rst_n
);

wire [9:0] hpos;
wire [9:0] vpos;
wire hsync;
wire vsync;
wire display_on;
wire [5:0] rgb;
wire [63:0] board;
wire [4:0] btn_press;
wire game_won;
wire game_over;
reg [7:0] vga_out;

// one clock pulse as the beam enters vertical blanking
wire frame_tick = (hpos == 10'd0) && (vpos == 10'd480);

vga_sync u_vga_sync (
	.clk(clk),
	.rst_n(rst_n),
	.hpos(hpos),
	.vpos(vpos),
	.hsync(hsync),
	.vsync(vsync),
	.display_on(display_on)
);

button_input u_button_input (
	.clk(clk),
	.rst_n(rst_n),
	.frame_tick(frame_tick),
	.btn_raw(ui_in[4:0]),
	.btn_press(btn_press)
);

game_2048 u_game_2048 (
	.clk(clk),
	.rst_n(rst_n),
	.btn_press(btn_press),
	.board(board),
	.game_won(game_won),
	.game_over(game_over)
);

board_draw u_board_draw (
	.hpos(hpos),
	.vpos(vpos),
	.display_on(display_on),
	.board(board),
	.game_won(game_won),
	.game_over(game_over),
	.rgb(rgb)
);

// register colour and sync together so they leave the chip on the same edge
always @(posedge clk) begin
	if(!rst_n) begin
		vga_out <= 8'b1000_1000;
	end
	else begin
		vga_out <= {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};
	end
end

assign uo_out = vga_out;
assign uio_out = 8'd0;
assign uio_oe = 8'd0;

wire _unused = &{ena, ui_in[7:5], uio_in, 1'b0};

endmodule