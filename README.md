# tranfEasy

App leve para macOS na barra superior para receber arquivos e pastas por arrastar e soltar, escolher uma pasta de destino e enviar com merge previsivel.

## Fluxo MVP

1. Clique no icone na barra superior para abrir a janela.
2. Arraste arquivos e pastas para a area de recebimento.
3. Escolha a pasta de destino.
4. Clique em Enviar.
5. Confirme a operacao.

## Regra de copia

- O item da origem vence conflitos de nome.
- Itens extras que ja existem no destino permanecem.
- A fila temporaria so e limpa depois de sucesso completo.

## Compilar

```bash
chmod +x bundle.sh
./bundle.sh
```

## Desenvolvimento

```bash
swift build
.build/debug/tranfEasy
```
