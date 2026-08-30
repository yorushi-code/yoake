# Рисует src/assets/logo.svg -- кошку, завязанную узлом.
#
# Знак не нарисован, а посчитан, и лежит здесь потому, что иначе его нельзя
# перенастроить: поменять узел, толщину ленты или размер головы -- это правка
# одного числа тут и повторный запуск, а не работа в редакторе по кривым.
#
#     python3 src/assets/logo.py
#
import math, pathlib
OUT = pathlib.Path(__file__).parent

def torus_knot(p, q, R=1.0, r=0.5, n=2200):
    out=[]
    for i in range(n):
        t=2*math.pi*i/n
        rad=R+r*math.cos(q*t)
        out.append((rad*math.cos(p*t), rad*math.sin(p*t), r*math.sin(q*t)))
    return out

def seg_x(a,b,c,d):
    r=(b[0]-a[0], b[1]-a[1]); s=(d[0]-c[0], d[1]-c[1])
    den=r[0]*s[1]-r[1]*s[0]
    if abs(den)<1e-12: return None
    qp=(c[0]-a[0], c[1]-a[1])
    t=(qp[0]*s[1]-qp[1]*s[0])/den
    u=(qp[0]*r[1]-qp[1]*r[0])/den
    if 0<=t<=1 and 0<=u<=1: return (t,u,r,s)
    return None

def head_path(origin,u,v,R, pts_out=None):
    """Кошачья голова: уши высокие и треугольные, морда сужается к подбородку.
    Круглая голова с мелкими ушами читалась совой -- это была вторая ошибка."""
    def P(a,b):
        q=(origin[0]+u[0]*a*R+v[0]*b*R, origin[1]+u[1]*a*R+v[1]*b*R)
        if pts_out is not None: pts_out.append(q)
        return q
    def f(q): return f"{q[0]:.1f},{q[1]:.1f}"
    d=[]
    d.append(f"M {f(P(-1.02, 0.46))}")
    # внешний край уха продолжает линию головы -- так ухо читается частью
    # силуэта, а не приставленным треугольником
    d.append(f"C {f(P(-1.02, 0.80))} {f(P(-1.02, 0.94))} {f(P(-1.03, 1.06))}")
    d.append(f"L {f(P(-1.04, 1.96))}")                                   # кончик левого уха
    d.append(f"C {f(P(-0.80, 1.62))} {f(P(-0.54, 1.40))} {f(P(-0.26, 1.28))}")
    d.append(f"C {f(P(-0.09, 1.21))} {f(P( 0.09, 1.21))} {f(P( 0.26, 1.28))}")
    d.append(f"C {f(P( 0.54, 1.40))} {f(P( 0.80, 1.62))} {f(P( 1.04, 1.96))}")
    d.append(f"L {f(P( 1.03, 1.06))}")
    d.append(f"C {f(P( 1.02, 0.94))} {f(P( 1.02, 0.80))} {f(P( 1.02, 0.46))}")
    # подбородок уводим глубже назад: иначе торец ленты вылезает из-под
    # головы отдельным нубиком и читается браком
    d.append(f"C {f(P( 1.02,-0.24))} {f(P( 0.86,-0.82))} {f(P( 0.48,-1.02))}")
    d.append(f"C {f(P( 0.26,-1.14))} {f(P(-0.26,-1.14))} {f(P(-0.48,-1.02))}")
    d.append(f"C {f(P(-0.86,-0.82))} {f(P(-1.02,-0.24))} {f(P(-1.02, 0.46))} Z")
    for sg in (-1,1):
        cx,cy=0.43*sg,0.62
        d.append(f"M {f(P(cx-0.23*sg, cy-0.04))}")
        d.append(f"C {f(P(cx-0.10*sg, cy+0.25))} {f(P(cx+0.13*sg, cy+0.25))} {f(P(cx+0.25*sg, cy+0.10))}")
        d.append(f"C {f(P(cx+0.15*sg, cy-0.17))} {f(P(cx-0.08*sg, cy-0.25))} {f(P(cx-0.23*sg, cy-0.04))} Z")
    return " ".join(d)

def build(pts, stroke=56, head_mul=5.7, seam_mul=2.6, size=1024, ink=830,
          clearance=0.22, min_sin=0.34, min_run=1.5):
    n=len(pts)
    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
    k=ink/max(max(xs)-min(xs), max(ys)-min(ys))
    cx,cy=(max(xs)+min(xs))/2,(max(ys)+min(ys))/2
    P=[((p[0]-cx)*k+size/2,(p[1]-cy)*k+size/2,p[2]) for p in pts]
    L=[0.0]
    for i in range(1,n+1):
        a,b=P[i-1],P[i%n]; L.append(L[-1]+math.hypot(b[0]-a[0],b[1]-a[1]))
    total=L[-1]

    cuts=[]
    for i in range(n):
        a,b=P[i],P[(i+1)%n]
        for j in range(i+2,n):
            if i==0 and j==n-1: continue
            c,d=P[j],P[(j+1)%n]
            hit=seg_x(a,b,c,d)
            if not hit: continue
            t,u_,r1,r2=hit
            # зазор по углу пересечения: на косом перехлёсте нужен шире
            n1=math.hypot(*r1) or 1; n2=math.hypot(*r2) or 1
            sin=abs(r1[0]*r2[1]-r1[1]*r2[0])/(n1*n2)
            half=(stroke/max(sin,min_sin))/2 + stroke*clearance
            zi=a[2]+(b[2]-a[2])*t; zj=c[2]+(d[2]-c[2])*u_
            si=L[i]+(L[i+1]-L[i])*t; sj=L[j]+(L[j+1]-L[j])*u_
            cuts.append((si if zi<zj else sj, half))

    top=min(range(n), key=lambda i:P[i][1])
    cuts.append((L[top], stroke*seam_mul/2))
    holes=[(((s-h)%total),((s+h)%total)) for s,h in cuts]
    def inside(s):
        for a,b in holes:
            if a<b:
                if a<=s<=b: return True
            elif s>=a or s<=b: return True
        return False

    runs,cur=[],[]
    for i in range(n+1):
        if inside(L[i]):
            if len(cur)>1: runs.append(cur)
            cur=[]
        else: cur.append((P[i%n][0],P[i%n][1]))
    if len(cur)>1: runs.append(cur)
    if len(runs)>1 and not inside(0.0):
        runs[0]=runs[-1]+runs[0]; runs.pop()

    # обрубки короче порога выкидываем целиком: прядь, которая едва
    # показалась между двумя нырками, читается мусором, а не плетением
    def rlen(r): return sum(math.hypot(r[i+1][0]-r[i][0], r[i+1][1]-r[i][1]) for i in range(len(r)-1))
    kept=[r for r in runs if rlen(r) >= stroke*min_run]
    dropped=len(runs)-len(kept)

    top_pt=min(((x,y) for r in kept for (x,y) in r), key=lambda q:q[1])
    best=1e18
    for r in kept:
        for end in (r[-1], r[0]):
            d2=(end[0]-top_pt[0])**2+(end[1]-top_pt[1])**2
            if d2<best: best, head_end = d2, end
    ccx=sum(x for r in kept for x,_ in r)/sum(len(r) for r in kept)
    ccy=sum(y for r in kept for _,y in r)/sum(len(r) for r in kept)
    rx,ry=head_end[0]-ccx, head_end[1]-ccy
    rn=math.hypot(rx,ry) or 1
    v=(rx/rn, ry/rn); u=(-v[1], v[0])
    hpts=[]
    hp=head_path(head_end,u,v,stroke*head_mul/2, hpts)

    # Габарит считаем по точкам, а не по отрисовке: прошлый раз голова уходила
    # за холст, обрезалась, и подгонка мерила уже обрезанное.
    allx=[x for r in kept for x,_ in r]+[q[0] for q in hpts]
    ally=[y for r in kept for _,y in r]+[q[1] for q in hpts]
    pad=stroke/2
    bx0,bx1=min(allx)-pad,max(allx)+pad
    by0,by1=min(ally)-pad,max(ally)+pad
    sc=ink/max(bx1-bx0, by1-by0)
    tx,ty=(bx0+bx1)/2,(by0+by1)/2

    paths=[f'    <path d="M ' + " L ".join(f"{x:.1f},{y:.1f}" for x,y in r) + f'" stroke-width="{stroke}"/>' for r in kept]
    svg=('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
         '  <!-- yoake: the cat, knotted -->\n'
         f'  <g transform="translate({size/2},{size/2}) scale({sc:.4f}) translate({-tx:.1f},{-ty:.1f})">\n'
         '    <g fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round">\n'
         + "\n".join(paths) + '\n    </g>\n'
         f'    <path d="{hp}" fill="#000" fill-rule="evenodd" stroke="none"/>\n'
         '  </g>\n</svg>\n')
    return svg, len(kept), dropped

svg,k,dr = build(torus_knot(3,4,1.0,0.50,2200))
(OUT/"logo.svg").write_text(svg)
print(f"прядей осталось {k}, обрубков выкинуто {dr}")
