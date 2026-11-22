#!/usr/bin/env python3
"""Deprecated entry — redirects to gen_art_pass_sprites (textured TC/Barracks style)."""
import os
import runpy

HERE = os.path.dirname(os.path.abspath(__file__))
runpy.run_path(os.path.join(HERE, "gen_art_pass_sprites.py"), run_name="__main__")
