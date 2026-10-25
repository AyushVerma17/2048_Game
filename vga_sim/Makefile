############################################################
# Local VGA simulator for the Tiny Tapeout 2048 design
############################################################

TOP = tt_um_ayush_2048
SRC_DIR = ../src
SOURCES = $(wildcard $(SRC_DIR)/*.v)

############################################################
# Build with Verilator, link with SDL2 for the window
############################################################

obj_dir/vga_sim: $(SOURCES) sim_main.cpp
	verilator --cc --exe --build -O3 --x-assign fast --x-initial fast -j 0 \
		--top-module $(TOP) -Wno-fatal -Wno-DECLFILENAME \
		-o vga_sim \
		-CFLAGS "$$(sdl2-config --cflags) -O3 -march=native" \
		-LDFLAGS "$$(sdl2-config --libs)" \
		$(SOURCES) sim_main.cpp

############################################################
# Targets
############################################################

run: obj_dir/vga_sim
	./obj_dir/vga_sim

# scripted run without a window: new game, then left, saves two frames
check: obj_dir/vga_sim
	./obj_dir/vga_sim --headless 30 --hold n:3:5 --hold left:12:14 --shot 10 --shot 30

clean:
	rm -rf obj_dir *.ppm

.PHONY: run check clean
