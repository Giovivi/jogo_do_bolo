# Projeto Mutantes · protótipo jogável

Greybox da **escola (hub)** e da fase-piloto **Posto Vigia-01**, feito em **Godot 4 com GDScript**.
Formas simples, câmera de frente em perspectiva e mira pelo mouse.
Materiais provisórios com cel shading e contorno, feitos por código. Arte final fica para depois.

## Como rodar

1. Instale a **Godot 4.3** (ou mais nova, versão padrão, não a .NET): https://godotengine.org/download
2. Abra a Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Na primeira abertura a Godot indexa os scripts (alguns segundos).
4. Aperte **F5** (ou o botão ▶) para jogar. O jogo começa na frente da escola; a mesa do mapa, na sala dos oficiais, leva à fase.

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
| Teste | F3 solta o Feixe na hora · F5 reinicia |

## A escola (hub)

Escola abandonada numa região isolada, tomada pelo mato. O clima padrão é "Lanterna": noite azulada com poças de luz quente nas lâmpadas. Para comparar, rode com a variável de ambiente `LOOK=entardecer` ou `LOOK=musgo`. A frente e o interior são áreas separadas, ligadas pelas portas (F).

| Área | O que tem |
|---|---|
| Frente da escola | Começo do jogo e volta das missões. Prédio de dois andares com marquise, pátio com mato, árvores e arbustos. Porta azul (F) para entrar |
| Saguão central | Pé-direito duplo com mezanino nas laterais, escada, caixas de 1 m e 2 m e passarela quebrada (vão de 4 m) |
| Sala dos oficiais (fundo do saguão) | Sala fechada com porta reforçada. Mesa com o mapa: F escolhe a missão (por enquanto, parte direto para o Posto Vigia-01) |
| Laboratório (oeste) | Fechado por porta blindada. Com o Feixe, segure Q na porta para abrir. Bancada (F) |
| Treino (leste) | Ginásio com entulho |
| Quartos (mezanino) | Portas nas laterais: Fênix acesa, Feixe acende depois do resgate, as outras estão tapadas com tábuas |

Quanto mais mutantes resgatados, menos mato aparece na frente.

**Ciclo:** frente → sala dos oficiais → mesa do mapa → Posto Vigia-01 → tela de resultado → Enter volta para a frente da escola. Derrota também volta para a escola. O resgate do Feixe e o laboratório aberto ficam guardados enquanto o jogo estiver aberto (ainda não há save em disco).

O hub fica em `scripts/hub/` (`escola.gd`, `hub_spot.gd`, `hub_door.gd`). A `Escola` herda o kit de peças da `PostoVigia` para não duplicar código; depois do merge do protótipo, vale mover esse kit para uma classe base comum.

**Visual provisório:** `scripts/art/look.gd` cria os materiais (tijolo, piso, madeira, folhagem, brilho e contorno de HQ) com os shaders de `shaders/`. `scripts/art/fenix_model.gd` é um modelo provisório do Fênix feito de blocos, que só aparece nas capturas por enquanto. O jogo não mostra números flutuantes de dano nem de cura.

O documento de design atualizado está em `docs/Projeto_Mutantes_GDD_v0.3.pdf`.

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

A câmera padrão olha de frente para a parede do fundo, com 22° de inclinação e perspectiva (opção B da prancha aprovada). A fase é vista como uma maquete em corte:
- Em volta das salas tudo é estrutura maciça, então não aparece vazio.
- A estrutura do fundo sobe até 6 m (parede de 3 m mais estrutura acima) e forma o cenário.
- A estrutura do lado da câmera fica cortada a 0,5 m.
- O vidro aparece como uma mureta de 1 m, mas continua bloqueando a passagem.

Em `data/regras.tres` (grupos "Câmera" e "Cenário em corte") dá para ajustar o giro, a inclinação, a perspectiva, a abertura (`camera_fov`), o enquadramento e as alturas do corte. Para voltar à isométrica antiga, use giro 45, inclinação 30 e `camera_perspective` desligado. A mira pelo mouse funciona em todos os modos.

## Onde ajustar os números

Todos os valores ficam em `.tres` na pasta `data/`. Abra na Godot (clique duplo no Inspector) e mude sem mexer em código:

| Arquivo | O que tem |
|---|---|
| `data/fenix.tres` | vida, velocidade, dash e todo o kit do Fênix |
| `data/feixe.tres` | vida, velocidade, dash e todo o kit do Feixe |
| `data/soldado.tres`, `data/soldado_escudo.tres`, `data/drone.tres` | inimigos |
| `data/regras.tres` | câmera e corte, troca, reanimação, IA, tempo da cela, dano de queda |

## Estrutura

```
scenes/main.tscn            cena inicial (monta tudo por código)
scripts/core/               Game (autoload), main, grupo, câmera
scripts/actors/             base de vida/dano e projéteis
scripts/heroes/             herói base + IA, Fênix, Feixe
scripts/enemies/            soldado e drone
scripts/level/              greybox do Posto Vigia-01, baús, portas, interruptor, console
scripts/hub/                escola (hub), pontos de interação e portas
scripts/art/                materiais (Look) e modelo provisório do Fênix
shaders/                    cel shading, tijolo, piso, contorno e papel do mapa
docs/                       documento de design (PDF)
scripts/ui/                 HUD
data/                       valores ajustáveis (.tres)
```

## Limitações conhecidas

- A IA não usa NavigationAgent3D ainda: anda em linha reta quando vê o alvo e, se não vê, segue a trilha de pegadas do herói controlado. Se ficar mais de 20 m para trás por 2,5 s, ela se reagrupa atrás do líder.
- Inimigos andam em linha reta até o alvo (as salas são abertas o bastante para o teste).
- Sem loot, XP, roda de seleção, ataque de entrada e revisita da fase.
- Sem save em disco: fechar o jogo zera o progresso da escola.
