"""Run with Blender --background --python build_models.py -- [options]."""
import argparse
import os
import sys
from pathlib import Path

import bpy

FAMILIES = {
    'block_animals': ('create_block_animals.py', 'finish_block_animals.py'),
    'revolver': ('create_block_revolver.py', 'finish_block_revolver.py'),
    'three_weapons': ('create_three_weapons.py', 'finish_three_weapons.py'),
    'desert_animals': ('create_desert_animals.py', 'finish_desert_animals.py'),
}

def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description='Build the 12 geometry-only Codex models.')
    parser.add_argument('--family', choices=['all', *FAMILIES], default='all')
    parser.add_argument('--output', type=Path, help='Alternate export root; defaults to ../assets.')
    parser.add_argument('--skip-render', action='store_true', help='Save Blender/FBX files without rendering previews.')
    options = parser.parse_args(argv)
    output = options.output or Path(__file__).resolve().parents[1] / 'assets'
    os.environ['CODEX_ASSET_OUTPUT'] = str(output.resolve())
    os.environ['CODEX_ASSET_SKIP_RENDER'] = '1' if options.skip_render else '0'
    families = FAMILIES if options.family == 'all' else {options.family: FAMILIES[options.family]}
    for family, filenames in families.items():
        if bpy.app.background:
            bpy.ops.wm.read_factory_settings(use_empty=True)
        for filename in filenames:
            path = Path(__file__).resolve().with_name(filename)
            namespace = {'__name__': '__main__', '__file__': str(path)}
            exec(compile(path.read_text(encoding='utf-8'), str(path), 'exec'), namespace)
        print('Built:', family)

if __name__ == '__main__':
    main()
