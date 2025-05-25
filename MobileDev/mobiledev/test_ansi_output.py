#!/usr/bin/env python3

# Test script to demonstrate ANSI escape code parsing

print("\033[31mRed text\033[0m")
print("\033[32mGreen text\033[0m")  
print("\033[1;33mBold yellow text\033[0m")
print("\033[44mBlue background\033[0m")
print("\033[4mUnderlined text\033[0m")
print("\n\033[2J\033[H")  # Clear screen and move cursor to home
print("Normal text after clear")
print("\033[5CIndented text (5 spaces)")
print("\033[1A\033[KLine cleared and moved up")
print("\n\033[38;2;255;128;0mRGB Orange text\033[0m")
print("\033[48;2;128;0;255mRGB Purple background\033[0m")
print("\nProgress: \033[32m█████████████\033[0m 100%")