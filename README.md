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
| Dash | Shift (recarga 2 s). Fênix: segurar Shift na beirada de um vão = planar |
| Trocar de personagem | 1 a 4 ou Tab (recarga 0,2 s) |
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
- Clique: combo de garras 10/10/18, o 3º golpe é forte (empurra, interrompe e dá pausa de impacto). Garras não alcançam drones.
- Q Asas de Fogo: asas de fogo abrem das costas e soltam um cone de 8 m e 90°, com chamas na horizontal. 25 de dano, acerta drones (recarga 6 s).
- E Chama Azul: cura 30 no aliado mais perto do cursor, ou em si mesmo (recarga 12 s).
- R Mergulho da Ave: agacha, sobe e sai da tela, volta como fênix de fogo até o cursor (até 12 m) e explode num raio de 6 m, 80 de dano. Ao pousar, vira a **Forma Fênix** por 15 s (a barra do especial mostra o tempo que falta):
  - Ave de fogo azul e dourada que paira (passa por cima de vãos) e anda a 7,5 m/s.
  - Clique, Dança das Brasas: Corte Incandescente (asa em arco de 160°, 14, deixa fogo no chão), Giro Flamejante (360°, 14) e Mergulho da Fênix (avança 4,5 m atravessando inimigos, 22, e explode 12 em 2 m).
  - Cada golpe do combo dá 1 Brasa no inimigo (até 3, somem em 5 s): brasas douradas girando e um anel de 3 partes no chão.
  - Q, Tempestade de Penas: 9 penas em leque de 70° até 8 m, 6 por pena, +10 com 3 penas no mesmo inimigo, poças de fogo no chão. Estoura as Brasas: 12 por Brasa em 1,5 m (recarga 5 s).
  - E, Investida Solar: dispara 9 m atravessando inimigos (15), rastro de fogo e explosão de 4 m no fim (35, derruba), +10 por Brasa dos inimigos atravessados (recarga 7 s).
- Passivas: Renascer (1x por fase volta com 50% e explode 40 em volta) e Regeneração (3/s depois de 4 s fora de combate).

**Feixe** (resgatado na sala 3)
Tudo em laser vermelho em camadas (núcleo #FFF4E8, vermelho #FF3038, sangue #B30D24, vinho #4A0714), sempre saindo dos óculos. 80 de vida, 5,5 m/s.
- Passiva, Foco Óptico: 3 acertos seguidos no mesmo inimigo completam o Foco (três losangos sobre a cabeça e estrela nos óculos). O próximo disparo nesse inimigo dá 8 + 20 = 28, é forte e cancela a carga do tiro inimigo. Errar, trocar de alvo ou matar zera; bloqueio do escudo não conta nem zera. Sem tempo limite.
- Clique, Disparo Óptico: instantâneo, 8 de dano a cada 0,25 s, alcance de 15 m, para no primeiro inimigo ou parede. Aciona o interruptor do hangar.
- Q, Feixe de Contenção: segurar até 3 s, 15 m por 1,2 m. O dano em cada inimigo cresce com o tempo que o feixe fica nele: 16/s no começo, 24/s com 1 s e 28/s com 2 s; sair do alvo zera a conta. O feixe fica mais largo e brilhante conforme o dano sobe. Anda a 35% e recua 0,3 m/s. Recarga de 8 s ao soltar. Corta a porta blindada do cofre.
- E, Ruptura Óptica: um raio sai dos óculos e abre em leque horizontal de 110° na altura do rosto, 7 m. 20 de dano, empurra 3,5 m. Recarga de 10 s.
- R, Aniquilação Circular: dedos na têmpora e o alcance marcado no chão (cortado pelas paredes), depois um raio de 14 m dá uma volta no sentido horário em 1,2 s. 120 de dano e derruba; paredes bloqueiam. Deixa um rastro contínuo no chão que apaga atrás do raio. Invulnerável durante a habilidade.

**Mistral** (no grupo desde o começo, por enquanto, para teste: tecla 3 na fase, 2 na escola)
Controle de área com eletricidade e vento; gelo só na suprema. 80 de vida, 5,5 m/s. Olhos dourados que ficam azul-elétricos nos poderes e faixas turquesa flutuando na cintura.
- Passiva, Carga Atmosférica: Q, E e R dão 1 carga (partículas girando na cintura). Com 3, o próximo clique, Q ou E sai fortalecido e as cargas zeram: clique com mais um salto, Q com 3,5 m de raio e puxão 1,6x, E com empurrão de 4,5 m e 24 de dano.
- Clique, Descarga Relampejante: raio da mão no inimigo mirado (ou o mais perto da linha de mira), 10 de dano, 12 m, a cada 0,4 s. Salta para o inimigo mais perto (até 4 m) com metade do dano.
- Q, Olho do Furacão: furacão no ponto mirado (até 10 m, para antes das paredes), 8/s no raio de 2,5 m por 3 s. Puxa para o centro até 4 m; soldado com escudo sofre 40% da atração, drones balançam. Recarga 9 s.
- E, Investida de Vendaval: rajada em cone de 100° e 7 m, 18 de dano, interrompe e empurra 3 m. Recarga 10 s.
- R, Geada Absoluta: braços erguidos, o gelo corre pelo chão até 12 m (paredes bloqueiam) e cristais brotam sob os inimigos: 100 de dano e congelados 3 s (2 s com escudo). Execução de 1,5 s, parada e invulnerável.

**Grupo**
- Troca 1 a 4 assume o aliado onde ele está, a câmera desliza em ~0,25 s, sem ataque de entrada.
- O aliado na IA segue (2 a 4 m), luta com inimigos a menos de 8 m, volta se passar de 12 m e reanima quem caiu quando não há inimigo a 4 m.
- Com 0 de vida o herói cai. Reanimar: ficar a 1,5 m por 3 s (o jogador segura F); volta com 40%.
- Se o herói controlado cai, o controle passa ao aliado vivo mais próximo. Todos caídos = derrota e a fase reinicia.

**Inimigos**
- Soldado (40 de vida): anda até o herói mais perto e atira a média distância. A variante com escudo só toma dano por trás ou de habilidades.
- Drone (25 de vida): voa a 2 m de altura, fica a 8–10 m e atira.
- Mira pela tela: com o cursor em cima de um inimigo, o herói mira nele (drone incluído), com ~1 m de folga. Antes, a mira caía no chão atrás do drone.
- Os tiros inimigos têm um pequeno aviso (o inimigo "incha") e podem ser desviados com o dash, que deixa invulnerável.

## Impacto dos golpes

Cada golpe tem uma força (seção 3.6 da especificação de mecânicas). A força define a pausa no acerto, o empurrão e o tremor de câmera:

| Força | Golpes | Pausa | Inimigo | Câmera |
|---|---|---|---|---|
| Fraco | garras 1 e 2, tiro óptico, laser | nenhuma | ~20 cm (laser não empurra) | parada |
| Forte | 3º golpe das garras, Asas de Fogo, Raio Forte, Cone de Raios | ~3 quadros | ~0,5 m e interrompido ~0,4 s (perde o tiro que estava preparando) | tremor leve |
| Especial | Mergulho, Renascer, Suprema em Círculo | ~6 quadros | derrubado ~1 s | tremor forte |
| Golpe que mata | qualquer um | pelo menos ~4 quadros | explosão curta | conforme a força |

- Só os golpes do herói que você controla pausam o jogo e tremem a câmera. Os da IA não.
- A Ruptura Óptica empurra mais (3,5 m, `pulse_push_meters` em `data/feixe.tres`), porque essa é a função dele.
- O drone não cai: é jogado para trás e balança.
- O escudo frontal só recua o soldado, sem interromper.
- Quem apanha pisca em vermelho. No ponto do acerto aparece uma chama dourada (comum) ou azul (forte) do Fênix, e uma faísca vermelha do Feixe. O Feixe de Contenção interrompe sem pausar o jogo a cada pulso.
- O herói: golpe comum só dá um tranquinho. Ataque forte interrompe por ~0,3 s, e o dash cancela a interrupção. Não há invulnerabilidade depois de apanhar.
- A Aniquilação Circular deixa o Feixe parado e invulnerável durante a volta (~1,2 s).
- O tremor de câmera pode ser desligado em `data/regras.tres` (`screen_shake`). Os números de cada força ficam em `scripts/combat/impact.gd`.

## Roteiro da fase (10 a 15 min)

A fase é um anel: a ida corre pela linha de baixo (da esquerda para a direita na tela) e a volta pela linha de cima. Como a câmera olha para o norte, a volta nunca fica entre a câmera e o herói, e a Saída fica logo acima da Entrada.

1. **Entrada:** 4 soldados. Baú numa saliência atrás de um vão de 2 m (ensina o planar).
2. **Triagem:** 6 soldados e 2 drones, 3 baús. No fundo, o vidro blindado mostra o cofre. A porta no mezanino leva ao vão de 4 m e à sala secreta (só o Fênix passa).
3. **Celas:** use o console (F). Aguente 60 s de onda (6 soldados, 3 drones). Os inimigos entram pelas portas laterais e pelos cantos do fundo, e o ponto de entrada pisca em vermelho 1 s antes. O Feixe entra no grupo. Se ele já foi resgatado antes, começa a fase ao lado do Fênix e a cela fica aberta e vazia.
4. **Hangar:** 4 drones e 1 soldado com escudo. Troque para o Feixe e acerte o interruptor da passarela alta: abre a porta de serviço no fundo do hangar.
5. **Depósito (volta):** 2 soldados e 1 soldado com escudo, caixas para se cobrir e 1 baú na plataforma.
6. **Cofre:** porta blindada (laser do Feixe) e baú raro.
7. **Saída:** sobe pelo norte do cofre e volta para cima da Entrada. Baú final e tela de resultado (tempo e baús 9/9).

Os baús e grupos de inimigos são sorteados entre pontos candidatos (`Marker3D` no nó `Candidatos`) a cada entrada. A semente aparece no console da Godot.

## Câmera e cenário em corte

A câmera padrão olha de frente para a parede do fundo, com 22° de inclinação e perspectiva (opção B da prancha aprovada). A fase é vista como uma maquete em corte:
- Em volta das salas tudo é estrutura maciça, então não aparece vazio.
- A estrutura do fundo sobe até 6 m (parede de 3 m mais estrutura acima) e forma o cenário.
- A estrutura do lado da câmera fica cortada a 0,5 m.
- O vidro aparece como uma mureta de 1 m, mas continua bloqueando a passagem.

**Câmera dinâmica (seção 3.7):**
- O herói fica a ~30% da altura da tela, contados de baixo, para mostrar mais do fundo da sala (`camera_hero_screen_fraction`).
- "Câmera segue a mira": o foco anda até 1,5 m na direção do cursor, com suavidade. O valor vai de 0 a 3 m (`camera_aim_follow`, que o menu de configurações pode mudar).
- Cada sala tem uma zona de câmera (`CameraZone`, nó `ZonasDeCamera`) com um de 3 níveis: aberto 100%, médio 80% e fechado 65% da distância. O zoom aproxima a câmera e mantém os 22°, sem mexer no FOV. Mudar `camera_zoom_medium` ou `camera_zoom_closed` muda todas as salas daquele nível.
- A troca de zoom leva 0,8 s, com aceleração e freio. Ela só acontece depois que o herói entra 1 m na outra sala, e os corredores sem zona mantêm o nível anterior.
- Na troca de herói, o deslize de 0,25 s já leva o zoom da sala do novo herói. Combate e especiais não mexem no zoom.
- Nada fica transparente na frente do herói. O efeito antigo está desligado (`wall_fade`), e o corte baixo das paredes da frente continua.
- Na fase, toda parede de borda passa pelo corte, mesmo as que encostam 0,5 m no chão da sala vizinha. A estrutura até 2 m ao lado do chão andável também fica baixa, para a quina não tampar o herói quando a câmera segue a mira para o lado. A escola não usa essas duas regras.

Em `data/regras.tres` (grupos "Câmera" e "Cenário em corte") dá para ajustar o giro, a inclinação, a perspectiva, a abertura (`camera_fov`), o enquadramento e as alturas do corte. Para voltar à isométrica antiga, use giro 45, inclinação 30 e `camera_perspective` desligado. A mira pelo mouse funciona em todos os modos.

## Onde ajustar os números

Todos os valores ficam em `.tres` na pasta `data/`. Abra na Godot (clique duplo no Inspector) e mude sem mexer em código:

| Arquivo | O que tem |
|---|---|
| `data/fenix.tres` | vida, velocidade, dash e todo o kit do Fênix |
| `data/feixe.tres` | vida, velocidade, dash e todo o kit do Feixe |
| `data/mistral.tres` | vida, velocidade, dash e todo o kit da Mistral |
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
- Nenhum inimigo da fase piloto tem ataque forte ainda, então a interrupção do herói (0,3 s, cancelável com dash) só vai aparecer quando um inimigo ganhar esse golpe.
