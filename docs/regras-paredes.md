# Regras de paredes e tetos (hub)

Vieram do diagnóstico dos bugs da câmera nova (paredes invisíveis, texturas piscando, parede que aparecia na porta). O kit `scripts/hub/obra.gd` já segue todas.

1. **Uma parede = uma peça.** O desenho e a colisão têm o mesmo tamanho. Nada de "colisão de 3 m e desenho de 8 m".
2. **Corrigir uma parede = trocar a peça.** Nunca empilhar outra por cima. Portas e janelas são vãos recortados na própria peça (`Obra.parede`).
3. **Tudo o que é visível e alto colide** (camada do mundo), porque a câmera só desvia do que colide. A exceção são os degraus, que só desenham: quem colide é a rampa embaixo deles.
4. **Nada some nem aparece conforme a posição do herói.** Os tetos existem em todas as salas, e a câmera chega mais perto quando bate neles.
5. **Toda porta e saída tem modelo** (folha aberta, tábuas pregadas ou a porta blindada), não só o ponto do "F".
6. **Checagem automática antes do build:**

   ```
   godot --headless -s res://tools/checa_hub.gd
   ```

   Ela acusa faces no mesmo plano viradas para o mesmo lado (z-fighting) e caixas altas sem colisão, e sai com erro se achar alguma.

Detalhes que evitam faces no mesmo plano:
- As paredes no eixo z são aparadas onde encontram as do eixo x (`_levantar_paredes`).
- Os pisos das duas salas se encontram no eixo da parede, por baixo do vão da porta (o vão começa no fundo do piso).
- Os pisos de fora ficam em alturas diferentes: grama 0, asfalto 1,5 cm, caminhos 2,5 cm, quadra 3 cm, pátio 3,5 cm.
