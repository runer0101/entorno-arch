#!/usr/bin/env python3
"""Curva voltaje -> minutos hasta vacio, medida en las descargas de ESTA maquina.

Mejora sobre el intento anterior: en vez de normalizar por la duracion de cada
descarga (que falsea las que no llegaron al fondo), se ancla a un cero absoluto
-- VACIO V/celda -- y se mide el tiempo real que falto para llegar ahi. Asi las
descargas parciales tambien valen: se les suma el tiempo que, segun las
completas, aun quedaba en su voltaje final.
"""
import glob, os, datetime

S = os.path.dirname(os.path.abspath(__file__))
CELDAS = 4
VACIO = 2.85          # V/celda que consideramos agotado
PASO = 0.02

def load(path):
    for line in open(path):
        p = line.strip().split('\t')
        if len(p) != 3:
            continue
        try:
            t, v, st = int(p[0]), float(p[1].replace(',', '.')), p[2]
        except ValueError:
            continue
        if v > 0:
            yield t, v, st

samples, seen = [], set()
for f in glob.glob(os.path.join(S, 'upower', 'history-voltage-*.dat')):
    for t, v, st in load(f):
        if t not in seen:
            seen.add(t)
            samples.append((t, v, st))
samples.sort()

runs, cur = [], []
for t, v, st in samples:
    if st == 'discharging':
        if cur and t - cur[-1][0] > 600:
            runs.append(cur); cur = []
        cur.append((t, v / CELDAS))
    else:
        if cur:
            runs.append(cur); cur = []
if cur:
    runs.append(cur)
runs = [r for r in runs if len(r) >= 20]

# Suaviza cada descarga: el voltaje instantaneo oscila con la carga de CPU/GPU.
# Mediana movil de 9 muestras (~4 min) para quedarnos con la tendencia.
def suaviza(r):
    vs = [v for _, v in r]
    out = []
    for i in range(len(r)):
        w = sorted(vs[max(0, i - 4):i + 5])
        out.append((r[i][0], w[len(w) // 2]))
    return out
runs = [suaviza(r) for r in runs]

completas = [r for r in runs if r[-1][1] <= VACIO + 0.05 and r[0][1] >= 3.9]
print(f'descargas que llegan al fondo: {len(completas)}')
for r in completas:
    d = datetime.datetime.fromtimestamp(r[0][0]).strftime('%d %b %H:%M')
    print(f'  {d}  {(r[-1][0]-r[0][0])/60:5.0f} min  '
          f'{r[0][1]:.3f} -> {r[-1][1]:.3f} V/celda')

# Paso 1: minutos-hasta-vacio observados en las descargas completas
obs = {}
for r in completas:
    tfin = r[-1][0]
    for t, v in r:
        obs.setdefault(round(v / PASO) * PASO, []).append((tfin - t) / 60)

def tabla(obs):
    ks = sorted(obs)
    out = []
    for k in ks:
        xs = sorted(obs[k])
        out.append((k, xs[len(xs) // 2], len(xs)))
    # monotona creciente en voltaje
    mx, mono = 0.0, []
    for v, m, n in out:
        mx = max(mx, m)
        mono.append((v, mx, n))
    return mono

base = tabla(obs)
def mins_en(v):
    """Interpola minutos-hasta-vacio para un voltaje dado."""
    if not base:
        return None
    if v <= base[0][0]:
        return base[0][1]
    if v >= base[-1][0]:
        return base[-1][1]
    for i in range(len(base) - 1):
        v0, m0, _ = base[i]
        v1, m1, _ = base[i + 1]
        if v0 <= v <= v1:
            return m0 + (m1 - m0) * (v - v0) / (v1 - v0) if v1 > v0 else m0
    return base[-1][1]

# Paso 2: incorpora las parciales, desplazadas por lo que les quedaba al final
for r in runs:
    if r in completas or r[0][1] < 3.3:
        continue
    resto = mins_en(r[-1][1])
    if resto is None:
        continue
    tfin = r[-1][0]
    for t, v in r:
        obs.setdefault(round(v / PASO) * PASO, []).append((tfin - t) / 60 + resto)

final = tabla(obs)
plena = final[-1][1]
print(f'\nautonomia desde 100% (extrapolada de la curva): {plena:.0f} min')
print(f'\n{"V/cel":>6} {"min":>6} {"SoC":>5} {"n":>5}')
for v, m, n in final:
    print(f'{v:6.2f} {m:6.0f} {m/plena*100:4.0f}% {n:5d}')

print('\n=== TABLA FINAL (paso 0,05 V/celda) ===')
vs = [round(2.80 + i * 0.05, 2) for i in range(int((4.20 - 2.80) / 0.05) + 1)]
socs = []
for tv in vs:
    m = mins_en(tv) if tv <= base[-1][0] else None
    # usa la tabla enriquecida
    prev = None
    val = None
    for v, mm, n in final:
        if v >= tv - 1e-9:
            val = mm if prev is None else prev[1] + (mm - prev[1]) * (tv - prev[0]) / (v - prev[0])
            break
        prev = (v, mm)
    if val is None:
        val = final[-1][1]
    socs.append(max(0, min(100, val / plena * 100)))
print('V   = ' + ' '.join(f'{v:.2f}' for v in vs))
print('SoC = ' + ' '.join(f'{s:.0f}' for s in socs))
print('min = ' + ' '.join(f'{s*plena/100:.0f}' for s in socs))
