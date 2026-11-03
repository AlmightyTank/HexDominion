"""Original military insignia SVG layers; shared by the roster build pipeline."""

PALETTES = {
    'a': ('#55aff0', '#142637', '#273f52'),
    'b': ('#f08075', '#24272e', '#41454d'),
    'c': ('#e5ba59', '#252d22', '#454b35'),
}


def badge(kind, faction, state):
    accent, interior, raised = PALETTES[faction]
    silver = '#dbe3e6'
    if state == 'damaged':
        interior, raised, silver = '#11181e', '#242c30', '#a4afb4'
    elif state == 'destroyed':
        accent, interior, raised, silver = '#555a5d', '#111619', '#22292b', '#646f73'
    outer = '64,5 115,34 115,94 64,123 13,94 13,34'
    inner = '64,18 104,41 104,87 64,110 24,87 24,41'
    body = f'''<defs>
      <linearGradient id="metal" x1="0" y1="0" x2="1" y2="1">
        <stop stop-color="#e2e8ec"/><stop offset=".45" stop-color="#647580"/>
        <stop offset=".55" stop-color="#344650"/><stop offset="1" stop-color="#b5c0c6"/>
      </linearGradient>
      <linearGradient id="field" x1="0" y1="0" x2="0" y2="1">
        <stop stop-color="{raised}"/><stop offset="1" stop-color="{interior}"/>
      </linearGradient></defs>
      <polygon points="{outer}" fill="url(#metal)" stroke="#0c141b" stroke-width="4"/>
      <polygon points="64,11 110,37 110,91 64,117 18,91 18,37" fill="{accent}"/>
      <polygon points="{inner}" fill="url(#field)" stroke="#0c141b" stroke-width="2"/>
      <path d="M24 43 L64 20 L103 43" fill="none" stroke="#c8d5dd" stroke-opacity=".35" stroke-width="2"/>
      <path d="M24 86 L64 109 L104 86" fill="none" stroke="#02090e" stroke-width="3"/>'''
    helmet = '<path d="M34 42 Q34 28 46 28 Q58 28 59 42 L62 45 L35 45 Z M38 47 L55 47 L53 56 L42 58 L38 53 Z"/>'
    torso = '<path d="M39 59 L53 57 L63 69 L58 84 L66 92 L49 92 L44 82 L35 91 L28 88 L37 74 Z"/>'
    weapons = {
        'rifle': '<path d="M53 59 L65 53 L74 55 L78 61 L65 65 L55 70 Z M59 54 L70 50 L89 50 L89 53 L103 53 L103 58 L84 58 L80 67 L74 67 L75 58 L66 58 L61 62 Z"/>',
        'rocket': '<path d="M50 61 L67 53 L77 58 L69 66 L54 73 Z M31 46 L35 41 L96 41 L107 49 L96 57 L35 57 L31 53 Z M68 57 L65 67 L74 67 L79 57 Z"/>',
        'gunner': '<path d="M52 63 L65 60 L75 66 L65 73 L54 74 Z M59 57 L84 57 L84 60 L106 60 L106 66 L83 66 L83 72 L59 72 Z M63 73 L76 73 L76 82 L63 82 Z M86 66 L80 86 L85 86 L90 70 L99 86 L104 86 L92 66 Z"/>',
    }
    roles = {
        'rifle': '<path d="M53 98 L64 104 L75 98 L75 103 L64 110 L53 103 Z"/>',
        'rocket': '<path d="M64 95 L69 101 L69 108 L64 111 L59 108 L59 101 Z M58 104 L54 110 L59 108 M70 104 L74 110 L69 108"/>',
        'gunner': '<path d="M53 102 L56 97 L59 102 L59 109 L53 109 Z M61 102 L64 97 L67 102 L67 109 L61 109 Z M69 102 L72 97 L75 102 L75 109 L69 109 Z"/>',
    }
    # Compact icons omit the torso, retaining an enlarged class-specific weapon.
    symbol = helmet + torso + weapons[kind] if state != 'icon' else '<g transform="translate(-8,-8) scale(1.12)">' + weapons[kind] + '</g>'
    body += f'<g fill="{silver}" stroke="#121d25" stroke-width="1.2" stroke-linejoin="round">{symbol}</g>'
    body += f'<g fill="{accent}" stroke="none">{roles[kind]}</g>'
    if state in ('damaged', 'destroyed'):
        body += '<path d="M18 38 L29 45 L22 53 L32 61 M109 83 L99 88 L105 97" fill="none" stroke="#080d10" stroke-width="4"/>'
        body += '<path d="M18 68 L18 82" stroke="#d26059" stroke-width="4"/>'
    if state == 'destroyed':
        body += '<path d="M53 13 L61 28 L56 42 L71 62 L62 77 L75 96 L67 115" fill="none" stroke="#090e12" stroke-width="7"/>'
        body = body.replace('#e2e8ec', '#697277').replace('#b5c0c6', '#535e64')
    return body
