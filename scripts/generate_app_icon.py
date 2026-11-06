import re

# Authentic macOS App Icon:
# Squircle: (824x824 at 100, 96, radius 185)
# Center of squircle: cx = 512, cy = 508.
#
# Generous scale: 3.02
# Center offset: (125.44, 121.44)

# Significantly softer and more rounded geometry:
# - Outer shield drawn with generous continuous bezier arcs at all corners (top crest, shoulder vertices, bottom keel)
# - Outer stroke-width="18" with stroke-linejoin="round"
# - Inner plate drawn with matching rounded curvature and stroke-width="12"
# - Synapses with pill caps
# - Smooth droplet-rounded apex spark

super_soft_foreground = """
  <!-- 1. Outer Fortress Shield: Continuous Fluid Curves (#0f172a) -->
  <path fill="#0f172a" stroke="#0f172a" stroke-width="18" stroke-linejoin="round" stroke-linecap="round" d="
    M 128,30
    C 134,30 148,36 206,62
    C 214,66 216,74 214,88
    C 210,146 182,198 132,224
    C 130,225 126,225 124,224
    C 74,198 46,146 42,88
    C 40,74 42,66 50,62
    C 108,36 122,30 128,30
    Z
  "/>
  
  <!-- 2. Dark Indigo Secondary Armor Plate (#1e1b4b) with Fluid Fillets -->
  <path fill="#1e1b4b" stroke="#1e1b4b" stroke-width="12" stroke-linejoin="round" stroke-linecap="round" d="
    M 128,48
    C 133,48 144,53 188,74
    C 194,77 195,83 194,94
    C 190,142 168,185 131,208
    C 129,209 127,209 125,208
    C 88,185 66,142 62,94
    C 61,83 62,77 68,74
    C 112,53 123,48 128,48
    Z
  "/>

  <!-- 3. The Neural Synapse Connections (Skills to Agents Network) -->
  <path stroke="#818cf8" stroke-opacity="0.42" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" d="
    M 128,70 L 86,112
    M 128,70 L 170,112
    M 86,112 L 86,156
    M 170,112 L 170,156
    M 86,156 L 128,186
    M 170,156 L 128,186
  "/>
  <path stroke="#818cf8" stroke-opacity="0.8" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" d="
    M 128,70 L 128,134
    M 86,112 L 128,134
    M 170,112 L 128,134
    M 86,156 L 128,134
    M 170,156 L 128,134
    M 128,186 L 128,134
  "/>

  <!-- 4. Soft Rounded Organic Apex Spark (#818cf8) -->
  <path fill="#818cf8" stroke="#818cf8" stroke-width="6" stroke-linejoin="round" stroke-linecap="round" d="
    M 128,54
    C 128,62 134,68 142,68
    C 134,68 128,74 128,82
    C 128,74 122,68 114,68
    C 122,68 128,62 128,54
    Z
  "/>

  <!-- 5. Peripheral Skill Nodes -->
  <circle cx="86" cy="112" r="8.5" fill="#6366f1" />
  <circle cx="170" cy="112" r="8.5" fill="#6366f1" />
  <circle cx="86" cy="156" r="8.5" fill="#6366f1" />
  <circle cx="170" cy="156" r="8.5" fill="#6366f1" />
  <circle cx="128" cy="186" r="9.5" fill="#818cf8" />

  <!-- 6. Central Intelligence Nucleus -->
  <circle cx="128" cy="134" r="14" fill="#818cf8" />
  <circle cx="128" cy="134" r="7" fill="#ffffff" />
"""

mac_icon_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background Gradient: #424242 (top) to #212121 (bottom) -->
    <linearGradient id="macBgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#424242" />
      <stop offset="100%" stop-color="#212121" />
    </linearGradient>

    <!-- Subtle Inner Highlight Rim -->
    <linearGradient id="rimGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#666666" stop-opacity="0.8" />
      <stop offset="100%" stop-color="#2b2b2b" stop-opacity="0.4" />
    </linearGradient>

    <!-- macOS Icon Drop Shadow -->
    <filter id="macShadow" x="-10%" y="-10%" width="120%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000000" flood-opacity="0.55"/>
    </filter>
  </defs>

  <!-- Authentic macOS Squircle Tile -->
  <rect x="100" y="96" width="824" height="824" rx="185" fill="url(#macBgGrad)" filter="url(#macShadow)"/>
  <rect x="100" y="96" width="824" height="824" rx="185" fill="none" stroke="url(#rimGrad)" stroke-width="3"/>

  <!-- Centered Scaled Neural Citadel Mark (Super Soft & Curvaceous) -->
  <g transform="translate(125.44, 121.44) scale(3.02)">
    {super_soft_foreground}
  </g>
</svg>"""

with open("branding/production/citadel-app-icon-colored.svg", "w") as f:
    f.write(mac_icon_svg)

print("Saved super-soft rounded icon branding/production/citadel-app-icon-colored.svg")
