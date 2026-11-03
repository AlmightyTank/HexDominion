"""Deterministic original SVG family. Run from any directory; no dependencies."""
from pathlib import Path
import json
import re
from infantry_badges import badge

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/units/roster'
INK = '#202a28'
FACTIONS = {'a': ('#738d9d', '#bed3dc', '#405b70', '#55aff0'),
            'b': ('#626369', '#929298', '#383e46', '#f08075'),
            'c': ('#74805a', '#b8b38a', '#505f43', '#e5ba59')}
ROSTER = {
 'rifle': ('infantry', 'Rifleman', 'hex badge, helmeted rifleman and chevron'),
 'rocket': ('infantry', 'Rocket Soldier', 'hex badge, shoulder launcher and rocket insignia'),
 'gunner': ('infantry', 'Machine Gunner', 'hex badge, heavy gun, bipod and three rounds'),
 'tank': ('vehicles', 'Main Battle Tank', 'wide tracks and long turret cannon'),
 'scout': ('vehicles', 'Scout Vehicle', 'narrow body and four exposed wheels'),
 'apc': ('vehicles', 'APC', 'box troop compartment and eight wheels'),
 'anti_air': ('vehicles', 'Mobile Anti-Air', 'paired missile banks'),
 'artillery': ('vehicles', 'Self-Propelled Artillery', 'long chassis and extreme barrel'),
 'helicopter': ('aircraft', 'Attack Helicopter', 'cross rotor and thin tail boom'),
 'fighter': ('aircraft', 'Fighter Jet', 'swept wings and pointed nose'),
 'patrol_boat': ('naval', 'Patrol Boat', 'small narrow pointed hull'),
 'destroyer': ('naval', 'Destroyer', 'long hull with fore and aft guns'),
 'landing_transport': ('naval', 'Landing Transport', 'broad squared hull and open deck')}

def path(d, fill='BODY', width=3):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{width}" stroke-linejoin="round"/>'

def rect(x, y, w, h, fill='BODY'):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="{fill}" stroke="{INK}" stroke-width="3"/>'

def geometry(kind):
    legacy = {'tank': 'main_battle_tank', 'scout': 'scout_vehicle',
              'apc': 'armored_personnel_carrier', 'anti_air': 'mobile_anti_air'}
    if kind in legacy:
        text = (ROOT / f'assets/units/{legacy[kind]}.svg').read_text()
        text = re.sub(r'^.*?<svg[^>]*>', '', text, flags=re.S).rsplit('</svg>', 1)[0]
        for old, new in [('#74805a', 'BODY'), ('#929c72', 'LIGHT'), ('#505f43', 'DARK'), ('#41b6a6', 'ACCENT')]:
            text = text.replace(old, new)
        # Normalize secondary olive shades from the approved hand-authored sources.
        def normalize(match):
            value = match.group(0)
            if value in (INK, '#303936'):
                return value
            rgb = [int(value[i:i+2], 16) for i in (1, 3, 5)]
            return 'LIGHT' if sum(rgb) > 430 else ('BODY' if sum(rgb) > 310 else 'DARK')
        text = re.sub(r'#[0-9a-fA-F]{6}', normalize, text)
        if kind == 'anti_air':
            text += rect(26, 17, 25, 35, 'DARK') + rect(77, 17, 25, 35, 'DARK')
            text += path('M30 43 L30 20 L35 10 L40 20 L40 43 Z', 'LIGHT')
            text += path('M82 43 L82 20 L87 10 L92 20 L92 43 Z', 'LIGHT')
        return text
    if kind == 'artillery':
        return rect(25, 50, 18, 70, 'DARK') + rect(85, 50, 18, 70, 'DARK') + path('M43 44 L85 44 L91 117 L37 117 Z') + rect(42, 70, 44, 34, 'LIGHT') + rect(59, 7, 10, 75, 'DARK') + rect(55, 5, 18, 12, 'LIGHT') + rect(44, 106, 40, 9, 'ACCENT')
    if kind == 'helicopter':
        return path('M59 68 L69 68 L69 112 L84 119 L44 119 L59 112 Z', 'DARK') + path('M56 18 Q64 8 72 18 L78 66 L69 84 L59 84 L50 66 Z') + rect(29, 49, 22, 20, 'DARK') + rect(77, 49, 22, 20, 'DARK') + path('M57 25 L71 25 L73 42 L55 42 Z', 'ACCENT') + path('M12 42 L15 33 L116 61 L113 70 Z', 'LIGHT') + path('M41 10 L50 7 L87 108 L78 111 Z', 'LIGHT') + '<circle cx="64" cy="55" r="7" fill="DARK"/>'
    if kind == 'fighter':
        return path('M64 7 L74 43 L117 84 L113 92 L77 79 L76 102 L91 117 L69 111 L64 120 L59 111 L37 117 L52 102 L51 79 L15 92 L11 84 L54 43 Z') + path('M64 28 L70 57 L64 72 L58 57 Z', 'ACCENT') + path('M54 85 L61 104 L55 108 M74 85 L67 104 L73 108', 'none')
    if kind == 'patrol_boat':
        return path('M64 12 L85 47 L81 112 L47 112 L43 47 Z', 'DARK') + path('M64 24 L77 49 L75 103 L53 103 L51 49 Z') + rect(54, 61, 20, 25, 'LIGHT') + rect(57, 58, 14, 6, 'ACCENT') + rect(59, 40, 10, 14, 'DARK') + rect(62, 28, 4, 18, 'LIGHT')
    if kind == 'destroyer':
        return path('M64 5 L88 35 L88 109 L77 122 L51 122 L40 109 L40 35 Z', 'DARK') + rect(29, 65, 15, 17, 'DARK') + rect(84, 65, 15, 17, 'DARK') + path('M64 17 L80 39 L80 111 L48 111 L48 39 Z') + rect(52, 52, 24, 39, 'LIGHT') + rect(53, 54, 22, 8, 'ACCENT') + rect(55, 31, 18, 14, 'DARK') + rect(61, 16, 6, 20, 'LIGHT') + rect(55, 97, 18, 13, 'DARK') + rect(61, 104, 6, 16, 'LIGHT') + path('M45 75 L83 75 M64 65 L64 86', 'none', 4)
    return path('M31 18 L97 18 L105 42 L105 113 L23 113 L23 42 Z', 'DARK') + rect(31, 38, 66, 67) + rect(40, 42, 48, 50, 'DARK') + rect(35, 13, 58, 24, 'LIGHT') + path('M42 18 L42 32 M53 18 L53 32 M64 18 L64 32 M75 18 L75 32 M86 18 L86 32', 'none') + rect(37, 96, 54, 11, 'ACCENT')

def icon(kind):
    silhouettes = {
      'tank': 'M34 44 H94 V113 H34 Z M53 51 H75 V85 H53 Z M60 13 H68 V60 H60 Z',
      'scout': 'M49 24 H79 V110 H49 Z M35 30 H46 V53 H35 Z M82 30 H93 V53 H82 Z M35 82 H46 V105 H35 Z M82 82 H93 V105 H82 Z',
      'apc': 'M39 20 H89 V113 H39 Z M25 27 H34 V110 H25 Z M94 27 H103 V110 H94 Z',
      'anti_air': 'M42 50 H86 V115 H42 Z M23 15 H55 V85 H23 Z M73 15 H105 V85 H73 Z',
      'artillery': 'M30 56 H98 V117 H30 Z M57 6 H71 V91 H57 Z',
      'helicopter': 'M57 18 H71 V109 H57 Z M38 112 H90 V120 H38 Z M10 43 H118 V54 H10 Z M59 7 H69 V96 H59 Z',
      'fighter': 'M64 8 L76 47 L117 89 L76 78 L76 103 L91 118 L64 110 L37 118 L52 103 L52 78 L11 89 L52 47 Z',
      'patrol_boat': 'M64 13 L84 46 L79 112 H49 L44 46 Z',
      'destroyer': 'M64 5 L87 32 V112 L78 123 H50 L41 112 V32 Z M29 65 H99 V82 H29 Z M60 9 H68 V40 H60 Z',
      'landing_transport': 'M29 17 H99 L105 39 V115 H23 V39 Z'}
    return path(silhouettes[kind], 'LIGHT')

def build():
    manifest = {'source': 'Original deterministic vector artwork; no external assets', 'units': {}}
    for kind, (category, name, silhouette) in ROSTER.items():
        manifest['units'][kind] = {'category': category, 'name': name, 'silhouette': silhouette, 'files': []}
        for faction, palette in FACTIONS.items():
            # Geometric recognition survives grayscale: chevron, riveted slab, twin rails.
            panels = {'a': path('M52 92 L64 98 L76 92 L64 104 Z', 'ACCENT'),
                      'b': rect(49, 92, 30, 13, 'ACCENT') + '<circle cx="54" cy="98" r="2" fill="LIGHT"/><circle cx="74" cy="98" r="2" fill="LIGHT"/>',
                      'c': rect(49, 93, 11, 12, 'ACCENT') + rect(68, 93, 11, 12, 'ACCENT')}[faction]
            for state in ('base', 'damaged', 'destroyed', 'icon'):
                body = badge(kind, faction, state) if category == 'infantry' else (icon(kind) if state == 'icon' else geometry(kind)) + panels
                if state == 'damaged' and category != 'infantry':
                    body += path('M45 70 L59 63 L72 72 L63 88 L46 83 Z', '#292825') + path('M47 40 L60 52 L55 62 L70 70', 'none', 4)
                if state == 'destroyed' and category != 'infantry':
                    body = body.replace('BODY', '#45443f').replace('LIGHT', '#68665b').replace('DARK', '#252827').replace('ACCENT', '#777262')
                    body += path('M32 35 L55 54 L46 68 L73 81 L63 97 L92 112', 'none', 7) + path('M36 97 L51 91 L48 111 L29 115 Z', '#302e29')
                for token, color in zip(('BODY', 'LIGHT', 'DARK', 'ACCENT'), palette):
                    body = body.replace(token, color)
                dest = OUT / category / kind / f'{kind}_faction_{faction}_{state}.svg'
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><title>{name}: faction {faction}, {state}</title>{body}</svg>\n')
                manifest['units'][kind]['files'].append(str(dest.relative_to(ROOT)).replace('\\', '/'))
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Wrote {len(ROSTER) * len(FACTIONS) * 4} SVGs and manifest')

if __name__ == '__main__':
    build()
