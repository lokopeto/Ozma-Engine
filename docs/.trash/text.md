Vamos decompor a matemática da projeção ortográfica. A ideia dela é **transformar um volume 3D (um paralelepípedo)** no cubo de coordenadas normalizadas (NDC), onde:

* **X** fica entre **-1 e 1**
* **Y** fica entre **-1 e 1**
* **Z** fica entre **0 e 1** (no caso do WebGPU/Direct3D/Metal)

---

## O volume da câmera

Imagine que a câmera enxerga este volume:

```
             top
              ^
              |
 left <--------+-------> right
              |
           bottom

        near -------- far
```

Os parâmetros são:

* `left`
* `right`
* `bottom`
* `top`
* `near`
* `far`

Queremos converter qualquer ponto desse volume para o intervalo da NDC.

---

# Passo 1 — Escalar X

Queremos transformar

```
[left, right]
```

em

```
[-1, 1]
```

Uma transformação linear tem a forma:

$$[
x' = ax + b
]$$

Precisamos que:

$$[
x=left \rightarrow -1
]$$

e

$$[
x=right \rightarrow 1
]$$

Montando o sistema:

$$[
a(left)+b=-1
]$$

$$[
a(right)+b=1
]$$

Subtraindo:

$$[
a(right-left)=2
]$$

Logo

$$[
a=\frac{2}{right-left}
]$$

Agora calculamos (b):

$$[
b=-1-\frac{2left}{right-left}
]$$

que simplifica para

$$[
b=-\frac{left+right}{right-left}
]$$

É exatamente o que aparece no código.

---

# Passo 2 — Escalar Y

O mesmo raciocínio:

$$[
y'=\frac{2}{top-bottom}y
-\frac{top+bottom}{top-bottom}
]$$

No código:

```rust
rcp_height = 1.0 / (top - bottom)
```

e

```rust
2 * rcp_height
```

é simplesmente

$$[
\frac{2}{top-bottom}
]$$

---

# Passo 3 — Escalar Z

Para WebGPU queremos

```
near -> 0
far  -> 1
```

Então queremos:

$$[
z'=az+b
]$$

Com

$$[
near\rightarrow0
]$$

$$
far\rightarrow1
]$$

Resolvendo:

$$[
a=\frac1{far-near}
]$$

Como o `glam` usa uma convenção diferente para câmera **right-handed**, aparece

```rust
r = 1.0 / (near - far)
```

que é apenas

$$[
-\frac1{far-near}
]$$

A tradução também muda de sinal.

---

# Passo 4 — Juntar tudo

Agora montamos uma única matriz.

Uma matriz 4×4 faz

$$[
M
\begin{bmatrix}
x\
y\
z\
1
\end{bmatrix}
=============

\begin{bmatrix}
x'\
y'\
z'\
1
\end{bmatrix}
]$$

Fica

$$[
\begin{bmatrix}
\frac2{r-l} &0&0&-\frac{r+l}{r-l}\
0&\frac2{t-b}&0&-\frac{t+b}{t-b}\
0&0&\frac1{n-f}&\frac n{n-f}\
0&0&0&1
\end{bmatrix}
]$$

---

# Correspondência com o código

Primeira coluna:

```rust
Vec4::new(
    2.0/(right-left),
    0,
    0,
    0,
)
```

↓

$$[
\begin{bmatrix}
2/(r-l)\
0\
0\
0
\end{bmatrix}
]$$

---

Segunda coluna:

```rust
Vec4::new(
    0,
    2.0/(top-bottom),
    0,
    0,
)
```

↓

Escala o eixo Y.

---

Terceira coluna:

```rust
Vec4::new(
    0,
    0,
    1/(near-far),
    0,
)
```

↓

Escala o eixo Z.

---

Quarta coluna:

```rust
Vec4::new(
    -(left+right)/(right-left),
    -(top+bottom)/(top-bottom),
    near/(near-far),
    1,
)
```

↓

Essa é a **translação**, que move o centro do volume para a origem da NDC.

---

## Intuição

A matriz ortográfica faz apenas **duas operações em cada eixo**:

1. **Translada** o volume para que ele fique centrado na origem.
2. **Escala** o volume para que suas dimensões passem a ocupar exatamente o intervalo esperado pela NDC.

Não há divisão por `w`, então **objetos não ficam menores quando se afastam da câmera**. Isso é a principal diferença em relação à projeção em perspectiva, onde a matriz é construída para que, após a multiplicação, ocorra a **divisão por `w`** (`x/w`, `y/w`, `z/w`), produzindo o efeito visual de profundidade.

