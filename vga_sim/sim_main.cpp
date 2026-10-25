// Local VGA monitor for a Tiny Tapeout design.
// Runs the Verilated chip clock by clock, decodes the TinyVGA pins on uo_out
// the way a real monitor would (from hsync and vsync only), and shows the picture.
//
// Keys: arrows = ui_in[3:0], N = ui_in[4] (new game), R = reset, F12 = screenshot, Esc = quit
//
// Headless mode (no window, for scripted checks):
//   ./obj_dir/vga_sim --headless 40 --hold n:5:7 --hold left:15:17 --shot 30 --shot 40

#include <SDL.h>
#include <verilated.h>
#include "Vtt_um_ayush_2048.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static const int VIS_W = 640;
static const int VIS_H = 480;

// pixels between the hsync falling edge and the first visible pixel (sync + back porch)
static const int H_START = 96 + 48;
// lines between the vsync falling edge and the first visible line (sync + back porch)
static const int V_START = 2 + 33;

struct Hold {
	int bit;
	int first;
	int last;
};

static int key_bit(const std::string &name)
{
	if (name == "up") return 0;
	if (name == "down") return 1;
	if (name == "left") return 2;
	if (name == "right") return 3;
	if (name == "n") return 4;
	return -1;
}

static void save_ppm(const std::vector<uint32_t> &fb, const char *path)
{
	FILE *f = fopen(path, "wb");
	if (!f) {
		printf("could not write %s\n", path);
		return;
	}
	fprintf(f, "P6\n%d %d\n255\n", VIS_W, VIS_H);
	for (uint32_t px : fb) {
		unsigned char rgb[3] = {(unsigned char)(px >> 16), (unsigned char)(px >> 8), (unsigned char)px};
		fwrite(rgb, 1, 3, f);
	}
	fclose(f);
	printf("saved %s\n", path);
}

int main(int argc, char **argv)
{
	int headless_frames = 0;
	std::vector<Hold> holds;
	std::vector<int> shots;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--headless") && i + 1 < argc) {
			headless_frames = atoi(argv[++i]);
		}
		else if (!strcmp(argv[i], "--hold") && i + 1 < argc) {
			char name[16];
			Hold h;
			if (sscanf(argv[++i], "%15[^:]:%d:%d", name, &h.first, &h.last) == 3 && (h.bit = key_bit(name)) >= 0) {
				holds.push_back(h);
			}
			else {
				printf("bad --hold, use key:first_frame:last_frame (keys: up down left right n)\n");
				return 1;
			}
		}
		else if (!strcmp(argv[i], "--shot") && i + 1 < argc) {
			shots.push_back(atoi(argv[++i]));
		}
	}
	bool headless = headless_frames > 0;

	Verilated::commandArgs(argc, argv);
	Vtt_um_ayush_2048 *chip = new Vtt_um_ayush_2048;
	chip->ena = 1;
	chip->uio_in = 0;
	chip->ui_in = 0;

	SDL_Window *window = nullptr;
	SDL_Renderer *renderer = nullptr;
	SDL_Texture *texture = nullptr;
	if (!headless) {
		if (SDL_Init(SDL_INIT_VIDEO) != 0) {
			printf("SDL_Init failed: %s\n", SDL_GetError());
			return 1;
		}
		window = SDL_CreateWindow("tt_um_ayush_2048", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
			VIS_W, VIS_H, SDL_WINDOW_RESIZABLE);
		renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
		SDL_RenderSetLogicalSize(renderer, VIS_W, VIS_H);
		texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, VIS_W, VIS_H);
	}

	std::vector<uint32_t> fb(VIS_W * VIS_H, 0);
	int x = 0;
	int line = 0;
	bool prev_hs = true;
	bool prev_vs = true;
	int frame = 0;
	int reset_cycles = 10;
	int shot_count = 0;
	uint32_t fps_time = headless ? 0 : SDL_GetTicks();
	int fps_frames = 0;
	bool running = true;

	while (running) {
		// one full clock cycle
		chip->rst_n = reset_cycles > 0 ? 0 : 1;
		if (reset_cycles > 0) {
			reset_cycles--;
		}
		chip->clk = 0;
		chip->eval();
		chip->clk = 1;
		chip->eval();

		uint8_t out = chip->uo_out;
		bool hs = (out >> 7) & 1;
		bool vs = (out >> 3) & 1;

		// TinyVGA pinout: uo_out = {hsync, B0, G0, R0, vsync, B1, G1, R1}
		int r = (((out >> 0) & 1) << 1) | ((out >> 4) & 1);
		int g = (((out >> 1) & 1) << 1) | ((out >> 5) & 1);
		int b = (((out >> 2) & 1) << 1) | ((out >> 6) & 1);

		int px = x - H_START;
		int py = line - V_START;
		if (px >= 0 && px < VIS_W && py >= 0 && py < VIS_H) {
			fb[py * VIS_W + px] = 0xFF000000u | ((r * 85) << 16) | ((g * 85) << 8) | (b * 85);
		}
		x++;

		// a falling hsync starts a new line, a falling vsync starts a new frame
		if (prev_hs && !hs) {
			x = 0;
			line++;
		}
		if (prev_vs && !vs) {
			line = 0;
			frame++;
			fps_frames++;

			if (headless) {
				int keys = 0;
				for (const Hold &h : holds) {
					if (frame >= h.first && frame <= h.last) {
						keys |= 1 << h.bit;
					}
				}
				chip->ui_in = keys;
				for (int s : shots) {
					if (s == frame) {
						char name[64];
						snprintf(name, sizeof(name), "frame_%03d.ppm", frame);
						save_ppm(fb, name);
					}
				}
				if (frame >= headless_frames) {
					running = false;
				}
			}
			else {
				SDL_UpdateTexture(texture, nullptr, fb.data(), VIS_W * 4);
				SDL_RenderClear(renderer);
				SDL_RenderCopy(renderer, texture, nullptr, nullptr);
				SDL_RenderPresent(renderer);

				SDL_Event e;
				while (SDL_PollEvent(&e)) {
					if (e.type == SDL_QUIT) {
						running = false;
					}
					if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) {
						running = false;
					}
					if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_r) {
						reset_cycles = 10;
					}
					if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_F12) {
						char name[64];
						snprintf(name, sizeof(name), "shot_%03d.ppm", shot_count++);
						save_ppm(fb, name);
					}
				}

				// buttons are read like real pins: high while the key is held
				const Uint8 *k = SDL_GetKeyboardState(nullptr);
				chip->ui_in = (k[SDL_SCANCODE_UP] ? 1 : 0) | (k[SDL_SCANCODE_DOWN] ? 2 : 0) |
					(k[SDL_SCANCODE_LEFT] ? 4 : 0) | (k[SDL_SCANCODE_RIGHT] ? 8 : 0) | (k[SDL_SCANCODE_N] ? 16 : 0);

				uint32_t now = SDL_GetTicks();
				if (now - fps_time >= 1000) {
					char title[96];
					snprintf(title, sizeof(title), "tt_um_ayush_2048  |  %d fps (real chip: 60)", fps_frames);
					SDL_SetWindowTitle(window, title);
					fps_frames = 0;
					fps_time = now;
				}
			}
		}
		prev_hs = hs;
		prev_vs = vs;
	}

	chip->final();
	delete chip;
	if (!headless) {
		SDL_DestroyTexture(texture);
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
		SDL_Quit();
	}
	return 0;
}
