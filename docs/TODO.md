- [x] MVP! // ARRUMAR ORTHOGRAPHIC
- [x] Carregar Modelos
- [x] Refatorar
- [x] Textura
- [x] Aprender Slang
- [x] "ECS"
- [x] GLTF
- [x] UVs
- [x] Resize Handling
- [ ] Gpu Skinning
- [ ] IK
- [x] Vertex Color
- [x] Memory Allocation 
- [ ] [Shader Hot Reloading](https://github.com/DragosPopse/odin-slang)
- [ ] Timeline Semaphore
- [ ] PBR? o_o
- [ ] GPU Driven Rendering
- [x] Mesh List
- [x] Input
- [ ] mipmap
- [ ] mais controle sobre textura
- [ ] Gpu texture ordering
- [ ] Implementar Box3D
- [ ] Dynamic Box3D Collision Geometry
- [ ] Pathfinding "ANYA"
- [ ] imgui/nuklear
- [ ] Sistema de save por mundo
- [ ] Async Compute
- [x] Vulkan Local Scope

## Projeto
- [x] Estrutura de projeto
- [ ] Ferramentas
- [ ] Reemplementar Virtual Files (Dagor)
- [ ] ~~DasLang~~
- [x] Arquivo de Config
- [ ] Compressão de Mesh

## "ECS"
- [ ] Separação por mundos
- [x] Funções de Entitidade
- [x] Funções de Terrenos
- [ ] Memoria Contigua (Remover Handle Map)
### COISAS PARA ARRUMAR
- [x] Dar um jeito nas funções em global scope
- [x] Arrumar UV
- [ ] Fazer Cleanup de objetos Vulkan
- [x] Fazer arquivo de config
- [ ] Fazer o sistema de troca de mundos
- [ ] Fazer sistema de seleção de texturas
- [x] Command Line Flag "run"
- [ ] Não Copiar Assets não usados


### Conceito
#### Terreno
Parte do mundo, funciona como "Chunks", ele não descarrega as entidades, apenas pausa ou diminui a frequencia de atualização das entitades, e os assets são descarregados de um jeito lazy, colocando em caches aqueles que não são frequentemente usados
##### Flags Entidades
- `TEMPORARY` 
	a entidade é deletada, util para efeitos visuais
##### Flags Assets
- `TEMPORARY` 
	o asset é descarregado


#### Mundo
Guarda uma coleção de terrenos com entidades e assets, é possivel ter varios mundos, porem apenas um mundo é carregado e usado, uso parecido com as cenas em softwares tradicionais

##### Flags Entidades
- `PERSISTENT` 
	a entidade se mantem, bom para players e afins
##### Flags Assets

*Obs: haverá um array onde é possivel selecionar multiplos mundos onde a entidade/asset existirá, poderem eles são unicos de cada mundo, isso só abre o acesso do asset pros mundos*
#### Mundo
Guarda uma coleção de mundos e todo o codigo, é possivel ter varias, mas apenas uma galaxia é carregada e usada, mudar de galaxia é praticamente mudar de software


Infos para dar uma olhada depois
- LD para cross-compiling