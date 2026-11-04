"""Original overhead geometry, based on the approved style preview."""
import xml.etree.ElementTree as ET
from pathlib import Path


def damage_marks():
    return '<path d="M43 47L57 57 51 68 70 79M75 39L69 50 83 58" fill="none" stroke="#131a17" stroke-width="4"/><path d="M44 71L59 65 73 75 66 89 47 85Z" fill="#30312c" stroke="#131a17" stroke-width="3"/>'


def wreck(body, category):
    for token, color in [('BODY', '#4c5048'), ('LIGHT', '#77796a'), ('DARK', '#252c29'), ('ACCENT', '#777262')]:
        body = body.replace(token, color)
    # Preserve each class silhouette, but break its outline and expose a dark cavity.
    scars = '<path d="M45 43L69 49 82 68 69 88 43 80 39 61Z" fill="#171d1b" stroke="#77796a" stroke-width="3"/><path d="M48 50L64 65 51 77M73 54L63 68 73 80" fill="none" stroke="#4c5048" stroke-width="5"/>'
    if category != 'infantry':
        scars += '<path d="M28 91L39 84 43 101 32 109ZM84 32L96 27 103 40 92 47Z" fill="#4c5048" stroke="#131a17" stroke-width="3"/><path d="M35 42L48 52M80 90L94 103" stroke="#171d1b" stroke-width="6"/>'
    return body + scars


def soldier(kind):
    preview = Path(__file__).resolve().parents[1] / 'docs/art/top-down-style-preview.svg'
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    group = next(n for n in ET.parse(preview).getroot().iter() if n.get('id') == 'soldier')
    body = ET.tostring(group, encoding='unicode')
    for color, token in [('#55aff0', 'BODY'), ('#97d0f5', 'LIGHT'), ('#3575a6', 'DARK')]:
        body = body.replace(color, token)
    weapons = {
        'rifle': '',
        'rocket': '<path d="M71 20L79 9L88 20V62H71Z" fill="#56614e" stroke="#131a17" stroke-width="3"/><path d="M74 23H85V49H74Z" fill="ACCENT"/>',
        'gunner': '<path d="M73 12H85V57H73Z" fill="#303936" stroke="#131a17" stroke-width="3"/><path d="M73 24L63 41M85 24L95 41" stroke="#131a17" stroke-width="4"/><rect x="85" y="47" width="13" height="14" fill="ACCENT" stroke="#131a17" stroke-width="3"/>'}
    return body + weapons[kind]


def buildings(root, factions):
    def p(d, fill='BODY'):
        return f'<path d="{d}" fill="{fill}" stroke="#131a17" stroke-width="3" stroke-linejoin="round"/>'
    def block(x, y, w, h, fill='BODY'):
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="#131a17" stroke-width="3"/>'
    preview = ET.parse(root / 'docs/art/top-down-style-preview.svg').getroot()
    barracks = ET.tostring(next(n for n in preview.iter() if n.get('id') == 'barracks'), encoding='unicode')
    for color, token in [('#55aff0', 'BODY'), ('#97d0f5', 'LIGHT'), ('#3575a6', 'DARK')]:
        barracks = barracks.replace(color, token)
    geometry = {
        'barracks': barracks,
        'headquarters': block(12, 39, 104, 52) + block(40, 16, 48, 94) + block(44, 20, 20, 82, 'LIGHT') + block(48, 52, 32, 19, 'ACCENT') + p('M59 55V30M59 30L77 36 59 41', 'none'),
        'factory': block(15, 26, 98, 80) + block(19, 30, 43, 65, 'LIGHT') + block(23, 68, 32, 34, 'DARK') + block(70, 68, 32, 34, 'DARK') + block(66, 31, 35, 22, 'ACCENT') + p('M23 77H55M23 86H55M70 77H102M70 86H102', 'none'),
        'power_plant': block(15, 21, 98, 86) + block(19, 25, 90, 18, 'LIGHT') + '<g fill="ACCENT" stroke="#131a17" stroke-width="4"><circle cx="43" cy="73" r="23"/><circle cx="87" cy="73" r="19"/></g>' + '<g fill="#303936"><circle cx="43" cy="73" r="12"/><circle cx="87" cy="73" r="9"/></g>',
        'extractor': block(22, 18, 84, 94) + block(26, 22, 35, 83, 'LIGHT') + block(37, 37, 54, 53, 'ACCENT') + p('M48 80L75 28 84 32 58 86Z', 'DARK') + block(60, 86, 28, 16, 'DARK'),
        'bunker': p('M30 27H98L112 41V88L98 102H30L16 88V41Z') + p('M33 33H64V95H33L23 83V46Z', 'LIGHT') + block(43, 46, 42, 35, 'ACCENT') + p('M37 24H91M13 49V80M115 49V80M37 105H91', 'none')}
    manifest = {'source': 'Original top-down vectors; approved soldier/tank/barracks style', 'buildings': {}}
    for kind, body in geometry.items():
        manifest['buildings'][kind] = []
        for faction, palette in factions.items():
            for state in ('base', 'damaged', 'destroyed'):
                colored = body if state == 'base' else (body + damage_marks() if state == 'damaged' else wreck(body, 'building'))
                for token, color in zip(('BODY', 'LIGHT', 'DARK', 'ACCENT'), palette):
                    colored = colored.replace(token, color)
                suffix = '' if state == 'base' else '_' + state
                dest = root / f'assets/buildings/{kind}_{faction}{suffix}.svg'
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><title>{kind}, faction {faction}, {state}</title>{colored}</svg>\n')
                manifest['buildings'][kind].append(str(dest.relative_to(root)).replace('\\', '/'))
    import json
    (root / 'assets/buildings/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
