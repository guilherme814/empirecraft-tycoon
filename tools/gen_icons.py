#!/usr/bin/env python3
"""Gera os ícones SVG (traço branco, 64x64, tingidos por código) e os ícones do app.
Uso: python3 tools/gen_icons.py   (rode da raiz do projeto)
Todos os desenhos são originais deste projeto."""
import math, os
from PIL import Image, ImageDraw

OUT = "assets/icons"
os.makedirs(OUT, exist_ok=True)

def svg(name, body, fill_none=True):
    inner = f'<g fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{body}</g>'
    with open(f"{OUT}/{name}.svg", "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{inner}</svg>\n')

def solid(name, body):
    with open(f"{OUT}/{name}.svg", "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="#ffffff">{body}</g></svg>\n')

def poly(points, close=True):
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    return f'<polygon points="{d}"/>' if close else f'<polyline points="{d}"/>'

# ── categorias de produto ──
svg("phone", '<rect x="18" y="5" width="28" height="54" rx="7"/><path d="M28 12h8"/><path d="M28 51h8"/>')
svg("laptop", '<rect x="10" y="13" width="44" height="30" rx="4"/><path d="M4 52h56"/><path d="M24 48h16"/>')
svg("watch", '<rect x="19" y="18" width="26" height="28" rx="9"/><path d="M25 18l2-12h10l2 12"/><path d="M25 46l2 12h10l2-12"/><path d="M46 29h4"/>')
svg("console", '<rect x="6" y="20" width="52" height="24" rx="7"/><path d="M16 31h18"/><path d="M16 36h12"/><circle cx="47" cy="32" r="3"/>')

# ── profissões ──
pts = []
for i in range(16):
    a = i * math.pi / 8
    r = 24 if i % 2 == 0 else 17
    pts.append((32 + r * math.cos(a), 32 + r * math.sin(a)))
svg("engineer", poly(pts) + '<circle cx="32" cy="32" r="7"/>')
svg("programmer", '<polyline points="22,18 8,32 22,46"/><polyline points="42,18 56,32 42,46"/><path d="M37 14l-10 36"/>')
svg("designer", '<path d="M32 5l15 22-15 20-15-20z"/><path d="M32 27v10"/><circle cx="32" cy="24" r="2"/><path d="M18 58h28"/>')
svg("researcher", '<path d="M25 6h14"/><path d="M28 6v18L11 52q-3 7 4 7h34q7 0 4-7L36 24V6"/><path d="M19 42h26"/>')

# ── interface ──
svg("coin", '<circle cx="32" cy="32" r="25"/><path d="M40 24q0-5-8-5t-8 5.5q0 5 8 7.5t8 7.5q0 5.5-8 5.5t-8-5"/><path d="M32 13v6M32 45v6"/>')
svg("calendar", '<rect x="9" y="12" width="46" height="43" rx="6"/><path d="M9 26h46"/><path d="M22 6v12M42 6v12"/>')
star = []
for i in range(10):
    a = -math.pi / 2 + i * math.pi / 5
    r = 26 if i % 2 == 0 else 11
    star.append((32 + r * math.cos(a), 33 + r * math.sin(a)))
svg("star", poly(star))
svg("flask", '<path d="M25 6h14"/><path d="M28 6v18L11 52q-3 7 4 7h34q7 0 4-7L36 24V6"/><path d="M19 42h26"/>')
svg("menu", '<path d="M10 17h44M10 32h44M10 47h44"/>')
svg("lock", '<rect x="14" y="28" width="36" height="28" rx="6"/><path d="M22 28v-8a10 10 0 0 1 20 0v8"/>')
svg("plus", '<path d="M32 12v40M12 32h40"/>')
svg("minus", '<path d="M12 32h40"/>')
svg("check", '<path d="M10 34l15 15 29-32"/>')
svg("trend_up", '<polyline points="6,48 22,30 34,40 58,14"/><polyline points="44,14 58,14 58,28"/>')

# ── navegação ──
svg("nav_dash", '<rect x="8" y="8" width="20" height="20" rx="4"/><rect x="36" y="8" width="20" height="20" rx="4"/><rect x="8" y="36" width="20" height="20" rx="4"/><rect x="36" y="36" width="20" height="20" rx="4"/>')
svg("nav_team", '<circle cx="24" cy="22" r="10"/><path d="M6 56q0-18 18-18t18 18"/><circle cx="46" cy="26" r="7"/><path d="M44 40q14 0 14 16"/>')
svg("nav_products", '<path d="M32 6l24 12v28L32 58 8 46V18z"/><path d="M8 18l24 12 24-12"/><path d="M32 30v28"/>')
svg("nav_research", '<path d="M25 6h14"/><path d="M28 6v18L11 52q-3 7 4 7h34q7 0 4-7L36 24V6"/><path d="M19 42h26"/>')
svg("nav_market", '<path d="M8 8v48h48"/><rect x="16" y="32" width="8" height="18" rx="2"/><rect x="30" y="22" width="8" height="28" rx="2"/><rect x="44" y="12" width="8" height="38" rx="2"/>')

# ── v0.3: operações, finanças, bolsa ──
svg("nav_ops", '<path d="M6 54V28l14 8V28l14 8V20h8V8h10v46z"/><path d="M6 54h52"/><path d="M42 36v8M50 36v8"/>')
svg("nav_finance", '<rect x="10" y="8" width="44" height="48" rx="6"/><path d="M20 22h24M20 32h24M20 42h14"/>')
svg("nav_stocks", '<path d="M8 8v48h48"/><path d="M16 20v22M32 12v26M48 24v22"/><rect x="12" y="26" width="8" height="10" rx="1"/><rect x="28" y="18" width="8" height="14" rx="1"/><rect x="44" y="30" width="8" height="10" rx="1"/>')
svg("nav_marketing", '<path d="M10 24v16h8l22 12V12L18 24z"/><path d="M18 40l4 14h8l-4-14"/><path d="M48 22q5 10 0 20"/>')
svg("nav_test", '<path d="M32 6l22 8v16q0 16-22 28Q10 46 10 30V14z"/><path d="M21 32l8 8 15-17"/>')
svg("nav_feedback", '<path d="M8 12h48v32H30l-14 12V44H8z"/><path d="M20 24h24M20 33h14"/>')
svg("nav_chip", '<rect x="16" y="16" width="32" height="32" rx="4"/><rect x="25" y="25" width="14" height="14" rx="2"/><path d="M24 6v10M32 6v10M40 6v10M24 48v10M32 48v10M40 48v10M6 24h10M6 32h10M6 40h10M48 24h10M48 32h10M48 40h10"/>')
svg("nav_package", '<path d="M32 6l22 11v30L32 58 10 47V17z"/><path d="M10 17l22 11 22-11M32 28v30"/>')

# ── velocidade ──
solid("pause", '<rect x="16" y="12" width="12" height="40" rx="3"/><rect x="36" y="12" width="12" height="40" rx="3"/>')
def chevrons(n):
    w = 40 / n if n > 1 else 0
    body = ""
    if n == 1:
        return '<polygon points="20,12 52,32 20,52"/>'
    step = 44 / n
    for i in range(n):
        x = 8 + i * step
        body += f'<polygon points="{x:.1f},14 {x + step * 0.95:.1f},32 {x:.1f},50"/>'
    return body
for n, name in [(1, "speed1"), (2, "speed2"), (3, "speed3"), (4, "speed4")]:
    solid(name, chevrons(n))

# ── ícones do app (Android adaptativo) ──
def hexagon(draw, cx, cy, r, color, width):
    pts = [(cx + r * math.cos(math.radians(60 * i - 90)), cy + r * math.sin(math.radians(60 * i - 90))) for i in range(6)]
    draw.line(pts + [pts[0]], fill=color, width=width, joint="curve")

def make_icon(size, bg, fg_only=False, scale_inner=1.0):
    S = 4
    img = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        d.rectangle([0, 0, size * S, size * S], fill=(18, 20, 26, 255))
        step = size * S // 12
        for i in range(0, size * S, step):
            d.line([(i, 0), (i, size * S)], fill=(34, 38, 50, 255), width=max(1, S))
            d.line([(0, i), (size * S, i)], fill=(34, 38, 50, 255), width=max(1, S))
    if not (bg and fg_only is None):
        pass
    return img, d, S

def draw_logo(d, size, S, k=1.0):
    c = size * S / 2
    r = size * S * 0.30 * k
    hexagon(d, c, c, r, (255, 154, 46, 255), int(size * S * 0.045 * k) + 1)
    w = int(size * S * 0.04 * k) + 1
    for dy, half in [(-0.09, 0.14), (0.0, 0.10), (0.09, 0.14)]:
        d.line([(c - size * S * half * k, c + size * S * dy * k), (c + size * S * half * k, c + size * S * dy * k)],
               fill=(233, 236, 242, 255), width=w)

os.makedirs(f"{OUT}/app", exist_ok=True)
# fundo adaptativo
img, d, S = make_icon(432, True)
img.resize((432, 432), Image.LANCZOS).save(f"{OUT}/app/adaptive_bg_432.png")
# primeiro plano adaptativo (conteúdo dentro dos 66% centrais)
img, d, S = make_icon(432, False)
draw_logo(d, 432, S, 1.0)
img.resize((432, 432), Image.LANCZOS).save(f"{OUT}/app/adaptive_fg_432.png")
# ícone clássico 192
img, d, S = make_icon(192, True)
draw_logo(d, 192, S, 1.15)
img.resize((192, 192), Image.LANCZOS).save(f"{OUT}/app/main_192.png")
print("ícones gerados em", OUT, "->", len(os.listdir(OUT)) - 1, "svgs")
