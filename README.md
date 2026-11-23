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
- R Mergulho da Ave: agacha, sobe e sai da tela, volta como fênix de fogo até o cursor (até 12 m) e explode num raio de 6 m, 80 de dano.
- Passivas: Renascer (1x por fase volta com 50% e explode 40 em volta) e Regeneração (3/s depois de 4 s fora de combate).

**Feixe** (resgatado na sala 3)
Tudo em raio laser vermelho: um raio fino com núcleo claro, e um clarão estrelado que sai do rosto a cada disparo.
- Clique, Raio Laser: instantâneo, 8 de dano, alcance de 15 m, para no primeiro inimigo ou parede. Aciona o interruptor do hangar.
- Q, Raio Forte: segurar, 12/s por até 3 s, anda devagar e o tranco o empurra para trás (~1 m em 3 s), com a mão na têmpora. Faíscas giram em volta do raio, anéis de pressão correm por ele e sai um respingo de luz onde bate. É grosso, atravessa todos os inimigos da linha e interrompe quem acerta. Corta a porta blindada do cofre.
- E, Cone de Raios: leque liso de energia de 90° com 6 m de alcance que se abre dos óculos, com a borda acesa e ondas correndo para fora. 15 de dano. Empurra 2,5 m e acerta drones.
- R, Suprema em Círculo: com a mão na têmpora, um raio de 14 m dá uma volta inteira no sentido horário em ~1,2 s e o corpo vira junto. Cada inimigo no alcance leva 120 de dano e cai quando o raio passa por ele; o chão por onde o raio passou fica vermelho e vai apagando.

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
- O Cone de Raios empurra mais (2,5 m, `pulse_push_meters` em `data/feixe.tres`), porque essa é a função dele.
- O drone não cai: é jogado para trás e balança.
- O escudo frontal só recua o soldado, sem interromper.
- Quem apanha pisca em vermelho. No ponto do acerto aparece uma chama dourada (comum) ou azul (forte) do Fênix, e uma faísca vermelha do Feixe. O Raio Forte interrompe sem pausar o jogo a cada pulso.
- O herói: golpe comum só dá um tranquinho. Ataque forte interrompe por ~0,3 s, e o dash cancela a interrupção. Não há invulnerabilidade depois de apanhar.
- A Suprema em Círculo deixa o Feixe parado e invulnerável durante a volta (~1,2 s).
- O tremor de câmera pode ser desligado em `data/regras.tres` (`screen_shake`). Os números de cada força ficam em `scripts/combat/impact.gd`.

## Roteiro da fase (10 a 15 min)

1. **Entrada:** 4 soldados. Baú numa saliência atrás de um vão de 2 m (ensina o planar).
2. **Triagem:** 6 soldados e 2 drones, 3 baús. Sala secreta ao norte atrás de um vão de 4 m. Pelo vidro ao sul dá para ver o cofre.
3. **Celas:** use o console (F). Aguente 60 s de onda (6 soldados, 3 drones). O Feixe entra no grupo. Se ele já foi resgatado antes, começa a fase ao lado do Fênix e a cela fica aberta e vazia.
4. **Hangar:** 4 drones e 1 soldado com escudo. Troque para o Feixe e acerte o interruptor da passarela alta: abre a porta de serviço ao sul.
5. **Volta:** corredor com 2 soldados, porta blindada do cofre (laser do Feixe), baú raro, e a **Saída** com o baú final e a tela de resultado (tempo e baús 8/8).

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
- Nenhum inimigo da fase piloto tem ataque forte ainda, então a interrupção do herói (0,3 s, cancelável com dash) só vai aparecer quando um inimigo ganhar esse golpe.
