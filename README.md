# Projeto Mutantes · protótipo jogável

Greybox da fase-piloto **Posto Vigia-01**, feito em **Godot 4 com GDScript**.
Formas simples, câmera isométrica ortográfica fixa e mira pelo mouse.
Arte final e cel shading ficam para depois.

## Como rodar

1. Instale a **Godot 4.3** (ou mais nova, versão padrão, não a .NET): https://godotengine.org/download
2. Abra a Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Na primeira abertura a Godot indexa os scripts (alguns segundos).
4. Aperte **F5** (ou o botão ▶) para jogar.

Não há assets externos: a fase, os heróis e os inimigos são montados por código.

## Controles

| Ação | Tecla |
|---|---|
| Mover | WASD (relativo à tela) |
| Mirar | Mouse |
| Ataque básico | Botão esquerdo (segurar repete) |
| Habilidade 1 / 2 | Q / E |
| Especial | R (só com a barra cheia) |
| Dash | Shift (recarga 1,5 s). Fênix: segurar Shift na beirada de um vão = planar |
| Trocar de personagem | 1 a 4 ou Tab (recarga 3 s) |
| Interagir / reanimar | F (segurar F perto de um aliado caído) |
| Pausa | Esc |
| Teste | F2 liga/desliga números de dano · F3 solta o Feixe na hora · F5 reinicia |

## O que dá para testar

**Fênix** (começa sozinho)
- Clique: combo de garras 10/10/18, o 3º golpe empurra e dá pausa de impacto. Garras não alcançam drones.
- Q Asas de Fogo: cone de 25 de dano, acerta drones (recarga 6 s).
- E Chama Azul: cura 30 no aliado mais perto do cursor, ou em si mesmo (recarga 12 s).
- R Mergulho da Ave: voa até o cursor (até 10 m) e explode em área, 80 de dano.
- Passivas: Renascer (1x por fase volta com 50% e explode 40 em volta) e Regeneração (3/s depois de 4 s fora de combate).

**Feixe** (resgatado na sala 3)
- Clique: tiro óptico de 8, alcance 15 m. Aciona o interruptor do hangar.
- Q Laser Contínuo: segurar, 12/s por até 3 s, anda devagar. Corta a porta blindada do cofre.
- E Pulso de Repulsão: cone curto que empurra, 15 de dano.
- R Rajada Máxima: linha reta que atravessa tudo, 120 de dano.

**Grupo**
- Troca 1 a 4 assume o aliado onde ele está, a câmera desliza em ~0,25 s, sem ataque de entrada.
- O aliado na IA segue (2 a 4 m), luta com inimigos a menos de 8 m, volta se passar de 12 m e reanima quem caiu quando não há inimigo a 4 m.
- Com 0 de vida o herói cai. Reanimar: ficar a 1,5 m por 3 s (o jogador segura F); volta com 40%.
- Se o herói controlado cai, o controle passa ao aliado vivo mais próximo. Todos caídos = derrota e a fase reinicia.

**Inimigos**
- Soldado (40 de vida): anda até o herói mais perto e atira a média distância. A variante com escudo só toma dano por trás ou de habilidades.
- Drone (25 de vida): voa, fica a 8–10 m e atira.
- Os tiros inimigos têm um pequeno aviso (o inimigo "incha") e podem ser desviados com o dash, que deixa invulnerável.

## Roteiro da fase (10 a 15 min)

1. **Entrada:** 4 soldados. Baú numa saliência atrás de um vão de 2 m (ensina o planar).
2. **Triagem:** 6 soldados e 2 drones, 3 baús. Sala secreta ao norte atrás de um vão de 4 m. Pelo vidro ao sul dá para ver o cofre.
3. **Celas:** use o console (F). Aguente 60 s de onda (6 soldados, 3 drones). O Feixe entra no grupo.
4. **Hangar:** 4 drones e 1 soldado com escudo. Troque para o Feixe e acerte o interruptor da passarela alta: abre a porta de serviço ao sul.
5. **Volta:** corredor com 2 soldados, porta blindada do cofre (laser do Feixe), baú raro, e a **Saída** com o baú final e a tela de resultado (tempo e baús 8/8).

Os baús e grupos de inimigos são sorteados entre pontos candidatos (`Marker3D` no nó `Candidatos`) a cada entrada. A semente aparece no console da Godot.

## Câmera e cenário em corte

A fase é vista como uma maquete em corte: tudo em volta das salas é estrutura maciça (não há vazio nem topo de parede solta). As paredes do fundo sobem até 3 m e formam o cenário. A estrutura do lado da câmera fica cortada a 0,5 m, então nada fica entre a câmera e o grupo.

Em `data/regras.tres` (grupo "Câmera") dá para testar:
- `camera_yaw_degrees`: 45 é a isométrica clássica, e 0 olha de frente para a parede do fundo, como nas referências.
- `camera_pitch_degrees`: inclinação (padrão 30°).
- `camera_perspective`: liga a perspectiva, que dá mais profundidade. `camera_fov` controla a abertura.
- `camera_view_height`: quanto da fase cabe na tela.
- `cutaway_height` e `cutaway_margin`: altura e alcance do corte.

O corte é recalculado a partir desses ângulos quando a fase carrega, e a mira pelo mouse funciona em todos os modos.

## Onde ajustar os números

Todos os valores ficam em `.tres` na pasta `data/`. Abra na Godot (clique duplo no Inspector) e mude sem mexer em código:

| Arquivo | O que tem |
|---|---|
| `data/fenix.tres` | vida, velocidade, dash e todo o kit do Fênix |
| `data/feixe.tres` | vida, velocidade, dash e todo o kit do Feixe |
| `data/soldado.tres`, `data/soldado_escudo.tres`, `data/drone.tres` | inimigos |
| `data/regras.tres` | câmera e corte, troca, reanimação, IA, números de dano, tempo da cela, dano de queda |

## Estrutura

```
scenes/main.tscn            cena inicial (monta tudo por código)
scripts/core/               Game (autoload), main, grupo, câmera
scripts/actors/             base de vida/dano e projéteis
scripts/heroes/             herói base + IA, Fênix, Feixe
scripts/enemies/            soldado e drone
scripts/level/              greybox do Posto Vigia-01, baús, portas, interruptor, console
scripts/ui/                 HUD
data/                       valores ajustáveis (.tres)
```

## Limitações conhecidas

- A IA não usa NavigationAgent3D ainda: anda em linha reta quando vê o alvo e, se não vê, segue a trilha de pegadas do herói controlado. Se ficar mais de 20 m para trás por 2,5 s, ela se reagrupa atrás do líder.
- Inimigos andam em linha reta até o alvo (as salas são abertas o bastante para o teste).
- Sem loot, XP, roda de seleção, ataque de entrada e revisita da fase.
